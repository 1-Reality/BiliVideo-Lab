// 设置里「电脑位宽与视频流畅度诊断」用，Dart 经 FFI 从 exe 的导出表调用

#include <windows.h>
#include <dxgi.h>
#include <intrin.h>

// 64 位版的 libmpv 是 x86-64-v3 编译：AVX2、BMI1/2、FMA、F16C、MOVBE、LZCNT，
// 且系统开启了 YMM 寄存器保存
extern "C" __declspec(dllexport) int PcCheckV3() {
  int r[4];
  __cpuid(r, 0);
  if (r[0] < 7) return 0;
  __cpuid(r, 1);
  // FMA 12、MOVBE 22、OSXSAVE 27、AVX 28、F16C 29
  if ((r[2] & 0x38401000) != 0x38401000 || (_xgetbv(0) & 6) != 6) return 0;
  __cpuidex(r, 7, 0);
  if ((r[1] & 0x128) != 0x128) return 0;  // BMI1 3、AVX2 5、BMI2 8
  __cpuid(r, 0x80000001);
  return (r[2] >> 5) & 1;  // LZCNT
}

// 第 0 号适配器，即 ANGLE 与播放实际用的那张（Windows 图形设置里指定显卡会改变它）
extern "C" __declspec(dllexport) const wchar_t* PcCheckGpu() {
  static DXGI_ADAPTER_DESC1 desc{};
  IDXGIFactory1* factory = nullptr;
  if (SUCCEEDED(CreateDXGIFactory1(IID_PPV_ARGS(&factory)))) {
    IDXGIAdapter1* adapter = nullptr;
    if (SUCCEEDED(factory->EnumAdapters1(0, &adapter))) {
      adapter->GetDesc1(&desc);
      adapter->Release();
    }
    factory->Release();
  }
  return desc.Description;
}