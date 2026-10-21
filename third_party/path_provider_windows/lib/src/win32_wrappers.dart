// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Types and functions correspond to Win32 APIs.
// ignore_for_file: public_member_api_docs

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'guid.dart';

typedef BOOL = Int32;
typedef BYTE = Uint8;
typedef DWORD = Uint32;
typedef UINT = Uint32;
typedef HANDLE = IntPtr;
typedef HMODULE = HANDLE;
typedef HRESULT = Int32;
typedef LPCVOID = Pointer<NativeType>;
typedef LPCWSTR = Pointer<Utf16>;
typedef LPDWORD = Pointer<DWORD>;
typedef LPWSTR = Pointer<Utf16>;
typedef LPVOID = Pointer<NativeType>;
typedef PUINT = Pointer<UINT>;
typedef PWSTR = Pointer<Pointer<Utf16>>;
typedef WCHAR = Uint16;

const int NULL = 0;
const int MAX_PATH = 260;
final int E_FAIL = 0x80004005.toSigned(32);
final int E_INVALIDARG = 0x80070057.toSigned(32);
bool FAILED(int hr) => hr < 0;
const int KF_FLAG_DEFAULT = 0;

final DynamicLibrary _dllKernel32 = DynamicLibrary.open('kernel32.dll');
final DynamicLibrary _dllVersion = DynamicLibrary.open('version.dll');
final DynamicLibrary _dllShell32 = DynamicLibrary.open('shell32.dll');

typedef _FFITypeSHGetKnownFolderPath = HRESULT Function(Pointer<GUID>, DWORD, HANDLE, PWSTR);
typedef FFITypeSHGetKnownFolderPathDart = int Function(Pointer<GUID>, int, int, Pointer<Pointer<Utf16>>);
final FFITypeSHGetKnownFolderPathDart SHGetKnownFolderPath =
    _dllShell32.lookupFunction<_FFITypeSHGetKnownFolderPath, FFITypeSHGetKnownFolderPathDart>('SHGetKnownFolderPath');

typedef _FFITypeGetFileVersionInfoW = BOOL Function(LPCWSTR, DWORD, DWORD, LPVOID);
typedef FFITypeGetFileVersionInfoW = int Function(Pointer<Utf16>, int, int, Pointer<NativeType>);
final FFITypeGetFileVersionInfoW GetFileVersionInfo =
    _dllVersion.lookupFunction<_FFITypeGetFileVersionInfoW, FFITypeGetFileVersionInfoW>('GetFileVersionInfoW');

typedef _FFITypeGetFileVersionInfoSizeW = DWORD Function(LPCWSTR, LPDWORD);
typedef FFITypeGetFileVersionInfoSizeW = int Function(Pointer<Utf16>, Pointer<Uint32>);
final FFITypeGetFileVersionInfoSizeW GetFileVersionInfoSize =
    _dllVersion.lookupFunction<_FFITypeGetFileVersionInfoSizeW, FFITypeGetFileVersionInfoSizeW>('GetFileVersionInfoSizeW');

typedef _FFITypeGetLastError = DWORD Function();
typedef FFITypeGetLastError = int Function();
final FFITypeGetLastError GetLastError =
    _dllKernel32.lookupFunction<_FFITypeGetLastError, FFITypeGetLastError>('GetLastError');

typedef _FFITypeGetModuleFileNameW = DWORD Function(HMODULE, LPWSTR, DWORD);
typedef FFITypeGetModuleFileNameW = int Function(int, Pointer<Utf16>, int);
final FFITypeGetModuleFileNameW GetModuleFileName =
    _dllKernel32.lookupFunction<_FFITypeGetModuleFileNameW, FFITypeGetModuleFileNameW>('GetModuleFileNameW');

typedef _FFITypeVerQueryValueW = BOOL Function(LPCVOID, LPCWSTR, LPVOID, PUINT);
typedef FFITypeVerQueryValueW = int Function(Pointer<NativeType>, Pointer<Utf16>, Pointer<NativeType>, Pointer<Uint32>);
final FFITypeVerQueryValueW VerQueryValue =
    _dllVersion.lookupFunction<_FFITypeVerQueryValueW, FFITypeVerQueryValueW>('VerQueryValueW');

typedef _FFITypeGetTempPathW = DWORD Function(DWORD, LPWSTR);
typedef FFITypeGetTempPathW = int Function(int, Pointer<Utf16>);
final FFITypeGetTempPathW GetTempPath =
    _dllKernel32.lookupFunction<_FFITypeGetTempPathW, FFITypeGetTempPathW>('GetTempPathW');
