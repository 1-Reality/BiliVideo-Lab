// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Stub used only to satisfy non-FFI compilation.
class PathProviderWindows extends PathProviderPlatform {
  PathProviderWindows() : assert(false);

  static void registerWith() {
    PathProviderPlatform.instance = PathProviderWindows();
  }

  VersionInfoQuerier versionInfoQuerier = VersionInfoQuerier();

  Future<String> getPath(String folderID) async => '';
}

class VersionInfoQuerier {}
