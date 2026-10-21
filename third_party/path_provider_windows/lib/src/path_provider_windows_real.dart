// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'folders.dart';
import 'guid.dart';
import 'win32_wrappers.dart';

@visibleForTesting
const String languageEn = '0409';
@visibleForTesting
const String encodingCP1252 = '04e4';
@visibleForTesting
const String encodingUnicode = '04b0';

/// Wraps Win32 VerQueryValue calls.
@visibleForTesting
class VersionInfoQuerier {
  String? getStringValue(
    Pointer<Uint8>? versionInfo,
    String key, {
    required String language,
    required String encoding,
  }) {
    assert(language.isNotEmpty);
    assert(encoding.isNotEmpty);
    if (versionInfo == null) return null;
    final Pointer<Utf16> keyPath =
        '\\StringFileInfo\\$language$encoding\\$key'.toNativeUtf16();
    final Pointer<UINT> length = calloc<UINT>();
    final Pointer<Pointer<Utf16>> valueAddress = calloc<Pointer<Utf16>>();
    try {
      if (VerQueryValue(versionInfo, keyPath, valueAddress, length) == 0) {
        return null;
      }
      return valueAddress.value.toDartString();
    } finally {
      calloc.free(keyPath);
      calloc.free(length);
      calloc.free(valueAddress);
    }
  }
}

/// The Windows implementation of [PathProviderPlatform].
class PathProviderWindows extends PathProviderPlatform {
  static void registerWith() {
    PathProviderPlatform.instance = PathProviderWindows();
  }

  @visibleForTesting
  VersionInfoQuerier versionInfoQuerier = VersionInfoQuerier();

  @override
  Future<String?> getTemporaryPath() async {
    final Pointer<Utf16> buffer = calloc<Uint16>(MAX_PATH + 1).cast<Utf16>();
    String result;
    try {
      final int length = GetTempPath(MAX_PATH, buffer);
      if (length == 0) {
        throw _createWin32Exception(GetLastError());
      } else {
        result = buffer.toDartString();
        if (result.endsWith(r'\')) {
          result = result.substring(0, result.length - 1);
        }
      }
      final Directory directory = Directory(result);
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }
      return result;
    } finally {
      calloc.free(buffer);
    }
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    final String? baseDir = await getPath(WindowsKnownFolder.RoamingAppData);
    if (baseDir == null) return null;
    final Directory directory = Directory(
      path.join(baseDir, _getApplicationSpecificSubdirectory()),
    );
    // Keep the upstream path_provider branch intact for the normal case.
    // The old directory is consulted only when the new destination does not exist.
    if (directory.path.length <= MAX_PATH) {
      if (!directory.existsSync()) {
        final Directory oldDirectory =
            Directory(path.join(baseDir, 'com.example', 'pilibro'));
        if (oldDirectory.existsSync()) {
          // Both locations are beneath RoamingAppData, so rename moves the data
          // directory rather than copying it. Create only the new parent path.
          await directory.parent.create(recursive: true);
          await oldDirectory.rename(directory.path);
        } else {
          await directory.create(recursive: true);
        }
      }
    }
    return directory.path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() =>
      getPath(WindowsKnownFolder.Documents);

  @override
  Future<String?> getApplicationCachePath() =>
      _createApplicationSubdirectory(WindowsKnownFolder.LocalAppData);

  @override
  Future<String?> getDownloadsPath() => getPath(WindowsKnownFolder.Downloads);

  Future<String?> getPath(String folderID) {
    final Pointer<Pointer<Utf16>> pathPtrPtr = calloc<Pointer<Utf16>>();
    final Pointer<GUID> knownFolderID = calloc<GUID>()..ref.parse(folderID);
    try {
      final int hr = SHGetKnownFolderPath(
        knownFolderID,
        KF_FLAG_DEFAULT,
        NULL,
        pathPtrPtr,
      );
      if (FAILED(hr)) {
        if (hr == E_INVALIDARG || hr == E_FAIL) {
          throw _createWin32Exception(hr);
        }
        return Future<String?>.value();
      }
      final String value = pathPtrPtr.value.toDartString();
      return Future<String>.value(value);
    } finally {
      calloc.free(pathPtrPtr);
      calloc.free(knownFolderID);
    }
  }

  String? _getStringValue(Pointer<Uint8>? infoBuffer, String key) =>
      versionInfoQuerier.getStringValue(
        infoBuffer,
        key,
        language: languageEn,
        encoding: encodingCP1252,
      ) ??
      versionInfoQuerier.getStringValue(
        infoBuffer,
        key,
        language: languageEn,
        encoding: encodingUnicode,
      );

  String _getApplicationSpecificSubdirectory() {
    String? companyName;
    String? productName;
    final Pointer<Utf16> moduleNameBuffer =
        calloc<WCHAR>(MAX_PATH + 1).cast<Utf16>();
    final Pointer<DWORD> unused = calloc<DWORD>();
    Pointer<BYTE>? infoBuffer;
    try {
      final int moduleNameLength =
          GetModuleFileName(0, moduleNameBuffer, MAX_PATH);
      if (moduleNameLength == 0) {
        throw _createWin32Exception(GetLastError());
      }
      final int infoSize = GetFileVersionInfoSize(moduleNameBuffer, unused);
      if (infoSize != 0) {
        infoBuffer = calloc<BYTE>(infoSize);
        if (GetFileVersionInfo(moduleNameBuffer, 0, infoSize, infoBuffer) == 0) {
          calloc.free(infoBuffer);
          infoBuffer = null;
        }
      }
      companyName =
          _sanitizedDirectoryName(_getStringValue(infoBuffer, 'CompanyName'));
      productName =
          _sanitizedDirectoryName(_getStringValue(infoBuffer, 'ProductName'));
      productName ??=
          path.basenameWithoutExtension(moduleNameBuffer.toDartString());
      return companyName != null
          ? path.join(companyName, productName)
          : productName;
    } finally {
      calloc.free(moduleNameBuffer);
      calloc.free(unused);
      if (infoBuffer != null) calloc.free(infoBuffer);
    }
  }

  String? _sanitizedDirectoryName(String? rawString) {
    if (rawString == null) return null;
    String sanitized = rawString
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .trimRight()
        .replaceAll(RegExp(r'[.]+$'), '');
    const int maxComponentLength = 255;
    if (sanitized.length > maxComponentLength) {
      sanitized = sanitized.substring(0, maxComponentLength);
    }
    return sanitized.isEmpty ? null : sanitized;
  }

  Future<String?> _createApplicationSubdirectory(String folderId) async {
    final String? baseDir = await getPath(folderId);
    if (baseDir == null) return null;
    final Directory directory =
        Directory(path.join(baseDir, _getApplicationSpecificSubdirectory()));
    if (directory.path.length <= MAX_PATH) {
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }
    }
    return directory.path;
  }
}

Exception _createWin32Exception(int errorCode) => PlatformException(
      code: 'Win32 Error',
      message: 'Error code 0x${errorCode.toRadixString(16)}',
    );
