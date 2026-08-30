#include "network_traffic_meter.h"

#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <iphlpapi.h>

#include <atomic>
#include <cstring>

namespace {

using RecvFn = int(WSAAPI*)(SOCKET, char*, int, int);
using SendFn = int(WSAAPI*)(SOCKET, const char*, int, int);

std::atomic<uint64_t> g_received{0};
std::atomic<uint64_t> g_sent{0};
RecvFn g_real_recv = nullptr;
SendFn g_real_send = nullptr;
bool g_installed = false;

int WSAAPI MeteredRecv(SOCKET socket, char* buffer, int length, int flags) {
  const int result = g_real_recv(socket, buffer, length, flags);
  if (result > 0 && (flags & MSG_PEEK) == 0) {
    g_received.fetch_add(static_cast<uint64_t>(result),
                         std::memory_order_relaxed);
  }
  return result;
}

int WSAAPI MeteredSend(SOCKET socket, const char* buffer, int length,
                       int flags) {
  const int result = g_real_send(socket, buffer, length, flags);
  if (result > 0) {
    g_sent.fetch_add(static_cast<uint64_t>(result),
                     std::memory_order_relaxed);
  }
  return result;
}

bool PatchModule(HMODULE module) {
  if (module == nullptr) return false;
  auto* base = reinterpret_cast<uint8_t*>(module);
  auto* dos = reinterpret_cast<IMAGE_DOS_HEADER*>(base);
  if (dos->e_magic != IMAGE_DOS_SIGNATURE) return false;
  auto* nt = reinterpret_cast<IMAGE_NT_HEADERS*>(base + dos->e_lfanew);
  if (nt->Signature != IMAGE_NT_SIGNATURE) return false;
  const auto& directory =
      nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
  if (directory.VirtualAddress == 0) return false;

  bool patched = false;
  auto* descriptor = reinterpret_cast<IMAGE_IMPORT_DESCRIPTOR*>(
      base + directory.VirtualAddress);
  for (; descriptor->Name != 0; ++descriptor) {
    const char* library = reinterpret_cast<const char*>(base + descriptor->Name);
    if (_stricmp(library, "ws2_32.dll") != 0) continue;
    auto* names = reinterpret_cast<IMAGE_THUNK_DATA*>(
        base + descriptor->OriginalFirstThunk);
    auto* slots = reinterpret_cast<IMAGE_THUNK_DATA*>(
        base + descriptor->FirstThunk);
    // Without the original thunk table the IAT no longer contains import
    // names, so it cannot be patched safely by name.
    if (descriptor->OriginalFirstThunk == 0) continue;
    for (; names->u1.AddressOfData != 0; ++names, ++slots) {
      if (IMAGE_SNAP_BY_ORDINAL(names->u1.Ordinal)) continue;
      auto* imported = reinterpret_cast<IMAGE_IMPORT_BY_NAME*>(
          base + names->u1.AddressOfData);
      void* replacement = nullptr;
      if (std::strcmp(reinterpret_cast<char*>(imported->Name), "recv") == 0) {
        g_real_recv = reinterpret_cast<RecvFn>(slots->u1.Function);
        replacement = reinterpret_cast<void*>(&MeteredRecv);
      } else if (std::strcmp(reinterpret_cast<char*>(imported->Name), "send") ==
                 0) {
        g_real_send = reinterpret_cast<SendFn>(slots->u1.Function);
        replacement = reinterpret_cast<void*>(&MeteredSend);
      }
      if (replacement == nullptr) continue;
      DWORD old_protection = 0;
      if (!VirtualProtect(&slots->u1.Function, sizeof(uintptr_t),
                          PAGE_READWRITE, &old_protection)) {
        continue;
      }
      InterlockedExchangePointer(
          reinterpret_cast<void* volatile*>(&slots->u1.Function), replacement);
      DWORD ignored = 0;
      VirtualProtect(&slots->u1.Function, sizeof(uintptr_t), old_protection,
                     &ignored);
      patched = true;
    }
  }
  return patched;
}

}  // namespace

bool InstallMediaWinsockMeter() {
  if (g_installed) return true;
  const wchar_t* candidates[] = {L"mpv-2.dll", L"libmpv-2.dll", L"mpv.dll"};
  for (const wchar_t* name : candidates) {
    if (PatchModule(GetModuleHandleW(name))) {
      g_installed = true;
      return true;
    }
  }
  return false;
}

NetworkByteCounters GetMediaWinsockCounters() {
  return {g_received.load(std::memory_order_relaxed),
          g_sent.load(std::memory_order_relaxed), g_installed, 0};
}

NetworkByteCounters GetActiveInterfaceCounters() {
  IN_ADDR destination{};
  if (InetPtonW(AF_INET, L"8.8.8.8", &destination) != 1) {
    return {0, 0, false, 0};
  }
  DWORD interface_index = 0;
  if (GetBestInterface(destination.S_un.S_addr, &interface_index) != NO_ERROR) {
    return {0, 0, false, 0};
  }
  MIB_IF_ROW2 row{};
  row.InterfaceIndex = interface_index;
  if (GetIfEntry2(&row) != NO_ERROR) return {0, 0, false, 0};
  return {row.InOctets, row.OutOctets, true, interface_index};
}
