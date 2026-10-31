// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ffi';
import 'dart:typed_data';

/// Representation of the Win32 GUID struct.
@Packed(4)
base class GUID extends Struct {
  @Uint32()
  external int data1;

  @Uint16()
  external int data2;

  @Uint16()
  external int data3;

  @Uint64()
  external int data4;

  /// Parses a GUID string, with optional enclosing braces and dashes.
  void parse(String guid) {
    final String hexOnly = guid.replaceAll(RegExp(r'[{}-]'), '');
    if (hexOnly.length != 32) {
      throw ArgumentError.value(guid, 'guid', 'Invalid GUID string');
    }
    final ByteData bytes = ByteData(16);
    for (int i = 0; i < 16; ++i) {
      bytes.setUint8(i, int.parse(hexOnly.substring(i * 2, i * 2 + 2), radix: 16));
    }
    data1 = bytes.getInt32(0);
    data2 = bytes.getInt16(4);
    data3 = bytes.getInt16(6);
    data4 = bytes.getInt64(8, Endian.little);
  }
}
