## PiliBro for Windows (32-bit)

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

# Can't run on Windows 7? Error message: Here's a solution!

[The error message looks like this]

  pilibro.exe - Entry point not found  
  The program entry point GetHostNameW could not be located in the dynamic link library WS2_32.dll.

## Why

  GetHostNameW is a feature added to the system starting with Windows 8; it is not included in the WS2_32.dll that comes with Windows 7.  
  This has nothing to do with runtime libraries like VC++; even if you install every possible runtime library, it won’t fix the issue because the missing component is a Windows system file itself.  
  PiliBro is built on Flutter, and Flutter officially only supports Windows 10 and later, so the engine directly calls on system features exclusive to Windows 8 and Windows 10.  
  The 64-bit version also won’t run on Windows 7.

## Solution: VxKex (Applicable to Windows 7)

  VxKex is a third-party tool specifically designed to add system features introduced in Windows 8 and Windows 10 to Windows 7; many applications that only support Windows 10 rely on it to run on Windows 7.
  1. Your system must be Windows 7 SP1. It is recommended to install the two patches, KB2533623 and KB2670838, first.
  2. Download and install from the GitHub release page: https://github.com/i486/VxKex
  3. Right-click pilibro.exe → Properties → VxKex tab → Check the “Enable” box.
  4. Double-click pilibro.exe to run it.

## Alternative Solution: VxKex-Next
(If the previous installation fails, or if you’re using Windows 8/8.1)

  https://github.com/YuZhouRen86/VxKex-NEXT

  ## Note
  This is a third-party solution, and we cannot guarantee that all features will work;  
  however, this isn’t the college entrance exam—missing one question isn’t the end of the world, nor will a factory explode because of it. For something this straightforward, testing it yourself is the most effective approach; there’s no need to tiptoe around it.

## Additional Notes
  This is a 32-bit portable version: 

  simply unzip and use it; it doesn’t modify the registry, and deleting the folder completely uninstalls it.

  Requires Windows 10 or Windows 11 (both 32-bit and 64-bit systems are supported). On 64-bit systems, we recommend using the 64-bit version for faster performance.