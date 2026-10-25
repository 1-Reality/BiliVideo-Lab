# PiliBro for Windows (32-bit)

This is the 32-bit (x86) portable build of PiliBro. Extract the archive anywhere and run `pilibro.exe`. Nothing is installed and no registry keys are written; delete the folder to remove it.

## Requirements

- Windows 10 or 11, 32-bit or 64-bit. On 64-bit Windows the 64-bit build is faster; use this one only if you need a 32-bit program.
- A GPU with Direct3D 11 support (almost every PC since 2010).

## Differences from the 64-bit build

- Dart code runs in JIT mode (32-bit Windows has no AOT compiler), so startup and UI are a little slower. Video decoding is done by libmpv and is not affected.
- Portable only, no installer. In-app update offers the 32-bit package, not the 64-bit one.

## Windows 7 / 8

Not supported. The Flutter engine calls system functions that only exist in Windows 8 or later, for example `GetHostNameW` in `WS2_32.dll`, so it fails to start with "The procedure entry point ... could not be located". Installing runtimes does not help, because these are part of Windows itself.

The third-party tool VxKex adds many of these functions to Windows 7 SP1. Install it, open the Properties of `pilibro.exe`, enable it on the VxKex tab, then start the program. This is untested and unsupported, but it costs nothing to try.