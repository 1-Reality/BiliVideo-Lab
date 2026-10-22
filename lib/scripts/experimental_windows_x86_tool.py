#!/usr/bin/env python3
"""Best-effort patcher for the isolated Windows x86 Flutter experiment.

This intentionally patches only the ephemeral Flutter SDK / pub cache on the
GitHub runner. It does not rewrite the repository's normal Windows x64 setup.
"""
from __future__ import annotations

import argparse
import hashlib
import re
import shutil
import subprocess
import sys
from pathlib import Path


def md5(path: Path) -> str:
    h = hashlib.md5()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8", newline="")


def insert_enum_target(build_info: Path) -> int:
    text = build_info.read_text(encoding="utf-8")
    if "windows_x86" in text:
        return 0
    patterns = [
        (r"(^[ \t]*windows_x64\(['\"]windows-x64['\"][^)]*\),?)[ \t]*$", r"\1\n  windows_x86('windows-x86'),"),
    ]
    for pattern, replacement in patterns:
        updated, count = re.subn(pattern, replacement, text, count=1, flags=re.M)
        if count:
            write_text(build_info, updated)
            return 1
    raise RuntimeError(f"Could not locate TargetPlatform.windows_x64 enum in {build_info}")


def patch_flutter_sdk(flutter_root: Path) -> None:
    src = flutter_root / "packages/flutter_tools/lib/src"
    build_info = src / "build_info.dart"
    if not build_info.exists():
        raise RuntimeError(f"Flutter source tree not found at {src}; this experiment needs a source SDK")

    changed: list[str] = []
    enum_changes = insert_enum_target(build_info)
    if enum_changes:
        changed.append(str(build_info))

    # The target must be recognized when parsing the platform string.
    text = build_info.read_text(encoding="utf-8")
    if "'windows-x86' => TargetPlatform.windows_x86" not in text:
        text, count = re.subn(
            r"(^\s*['\"]windows-x64['\"]\s*=>\s*TargetPlatform\.windows_x64\s*,?\s*$)",
            r"\1\n      'windows-x86' => TargetPlatform.windows_x86,",
            text,
            count=1,
            flags=re.M,
        )
        if count:
            write_text(build_info, text)
            changed.append(str(build_info) + " [fromName]")

    # Expand common exhaustive Dart switch patterns and platform collections.
    # Treat x86 like x64 unless a dedicated x86 mapping is required below.
    for path in src.rglob("*.dart"):
        original = path.read_text(encoding="utf-8")
        text = original

        # Switch statements: create an additional label so x86 initially follows
        # the x64 implementation for code that is architecture-independent.
        text = re.sub(
            r"(^[ \t]*)case TargetPlatform\.windows_x64:(?!\s*// x86 case already added)",
            r"\1case TargetPlatform.windows_x86:\n\1case TargetPlatform.windows_x64:",
            text,
            flags=re.M,
        )

        # Switch expressions/maps: duplicate single-line x64 arms for x86.
        lines = text.splitlines(keepends=True)
        out: list[str] = []
        for line in lines:
            body = line.rstrip("\r\n")
            newline = line[len(body):]
            match = re.match(r"^(\s*)TargetPlatform\.windows_x64(\s*=>\s*.+)$", body)
            if match and "TargetPlatform.windows_x86" not in body:
                out.append(f"{match.group(1)}TargetPlatform.windows_x86{match.group(2)}{newline}")
            out.append(line)
        text = "".join(out)

        # Lists and set literals used to enumerate supported desktop targets.
        text = re.sub(
            r"(^[ \t]*)(TargetPlatform\.windows_x64,)(?![^\n]*windows_x86)",
            r"\1TargetPlatform.windows_x86,\n\1\2",
            text,
            flags=re.M,
        )

        # Logical-or target checks used by asset bundling and build selection.
        text = re.sub(
            r"TargetPlatform\.windows_x64\s*\|\|",
            "TargetPlatform.windows_x86 || TargetPlatform.windows_x64 ||",
            text,
        )
        # Plain equality checks should treat x86 as a Windows desktop target too.
        text = re.sub(
            r"\b([A-Za-z_][A-Za-z0-9_.]*)\s*==\s*TargetPlatform\.windows_x64(?!\s*\|\|)",
            r"(\1 == TargetPlatform.windows_x86 || \1 == TargetPlatform.windows_x64)",
            text,
        )

        if text != original:
            write_text(path, text)
            changed.append(str(path))

    # Target-platform-specific bits which must not inherit x64's architecture.
    windows_builder = src / "windows/build_windows.dart"
    if windows_builder.exists():
        text = windows_builder.read_text(encoding="utf-8")
        text = re.sub(
            r"(TargetPlatform\.windows_x86\s*=>\s*)['\"]x64['\"]",
            r"\1'Win32'",
            text,
        )
        # For statement-style switches, split an x86 label accidentally grouped
        # with x64 and direct it to CMake's Win32 platform.
        text = re.sub(
            r"case TargetPlatform\.windows_x86:\s*\n(\s*)case TargetPlatform\.windows_x64:\s*\n\s*return ['\"]x64['\"]\s*;",
            r"case TargetPlatform.windows_x86:\n\1  return 'Win32';\n\1case TargetPlatform.windows_x64:\n\1  return 'x64';",
            text,
        )
        write_text(windows_builder, text)
        changed.append(str(windows_builder) + " [Win32 override]")

    # Force the CLI's default Windows target to x86 for this ephemeral SDK only.
    command_builder = src / "commands/build_windows.dart"
    if command_builder.exists():
        text = command_builder.read_text(encoding="utf-8")
        text = re.sub(
            r"(\?\s*)TargetPlatform\.windows_x64",
            r"\1TargetPlatform.windows_x86",
            text,
        )
        text = re.sub(
            r"(case HostPlatform\.windows:\s*\n\s*return\s*)TargetPlatform\.windows_x64",
            r"\1TargetPlatform.windows_x86",
            text,
        )
        write_text(command_builder, text)
        changed.append(str(command_builder) + " [force target x86]")

    native_assets = src / "isolated/native_assets/targets.dart"
    if native_assets.exists():
        text = native_assets.read_text(encoding="utf-8")
        text = re.sub(
            r"(TargetPlatform\.windows_x86\s*=>[^\n]*Architecture\.)x64",
            r"\1ia32",
            text,
        )
        # Statement-style switch in older/newer Flutter tool versions.
        text = re.sub(
            r"case TargetPlatform\.windows_x86:\s*\n\s*case TargetPlatform\.windows_x64:\s*\n(\s*)return (_windowsTarget\([^\n]*Architecture\.)x64(\)?;?)",
            r"case TargetPlatform.windows_x86:\n\1return _windowsTarget(supportedAssetTypes, Architecture.ia32);\n\1case TargetPlatform.windows_x64:\n\1return \2x64\3",
            text,
        )
        write_text(native_assets, text)
        changed.append(str(native_assets) + " [IA32 override]")

    report = flutter_root / "x86-experimental-tool-patch-report.txt"
    report.write_text("\n".join(changed) + "\n", encoding="utf-8")
    print(f"Patched experimental Flutter SDK files: {len(changed)}")
    print(f"Patch report: {report}")
    print("Note: any remaining exhaustive switch or unsupported GN setting will be visible in the build log.")


def find_media_kit_cmake(repo: Path) -> Path:
    relative = Path("libs/windows/media_kit_libs_windows_video/windows/CMakeLists.txt")
    candidates = list((Path.home() / "AppData/Local/Pub/Cache/git").glob("*"))
    candidates += list((Path.home() / ".pub-cache/git").glob("*"))
    candidates += list((repo / ".dart_tool/package_config.json").parent.glob("__no_candidates__"))
    found = [p / relative for p in candidates if (p / relative).exists()]
    if not found:
        raise RuntimeError("Could not find media-kit Windows video CMakeLists.txt in pub git cache")
    # Current pub cache often contains more than one checkout of the same repo.
    found.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return found[0]


def prepare_media_kit(repo: Path, archive_dir: Path) -> None:
    cmake = find_media_kit_cmake(repo)
    libmpv = archive_dir / "PiliBro-libmpv-x86.7z"
    angle = archive_dir / "ANGLE.7z"
    print(f"media-kit CMake: {cmake}")
    if not libmpv.exists():
        raise RuntimeError(f"No x86 libmpv archive found at {libmpv}")
    if not angle.exists():
        raise RuntimeError(f"No x86 ANGLE archive found at {angle}")

    text = cmake.read_text(encoding="utf-8")
    libmpv_md5 = md5(libmpv)
    angle_md5 = md5(angle)
    if "windows-x86" not in text:
        marker = '\nelse()\nset(LIBMPV_ARCH "aarch64")'
        if marker not in text:
            # Current or forked media-kit CMake may format the fallback branch differently.
            marker_match = re.search(r"\nelse\(\)\s*\nset\(LIBMPV_ARCH [\"']aarch64[\"']\)", text)
            if not marker_match:
                raise RuntimeError("Could not identify media-kit x64/ARM64 architecture branch")
            marker = marker_match.group(0)
        x86_branch = (
            '\nelseif(${FLUTTER_TARGET_PLATFORM} STREQUAL "windows-x86")\n'
            'set(LIBMPV_ARCH "i686")\n'
            'set(LIBMPV "PiliBro-libmpv-x86.7z")\n'
            f'set(LIBMPV_MD5 "{libmpv_md5}")'
        )
        text = text.replace(marker, x86_branch + marker, 1)
    else:
        text = re.sub(
            r'(elseif\(\$\{FLUTTER_TARGET_PLATFORM\} STREQUAL "windows-x86"\).*?set\(LIBMPV_MD5 ")[^"]*("\))',
            lambda m: m.group(1) + libmpv_md5 + m.group(2),
            text,
            flags=re.S,
        )

    # The local archive is pre-staged in CMAKE_BINARY_DIR. Its matching MD5
    # tells media-kit not to attempt a network download.
    text = re.sub(r'(set\(ANGLE_MD5\s+")[^"]*("\))', lambda m: m.group(1) + angle_md5 + m.group(2), text, count=1)

    # If the experimental archive has fewer ANGLE side DLLs than the upstream
    # bundle, remove only missing optional entries so CMake doesn't copy files
    # that do not exist. libmpv and the two core EGL/GLES files remain required.
    import tempfile
    with tempfile.TemporaryDirectory(prefix="pilibro-angle-check-") as tmp:
        sevenz = shutil.which("7z") or shutil.which("7za")
        if sevenz:
            subprocess.run([sevenz, "x", "-y", str(angle), f"-o{tmp}"], check=True, stdout=subprocess.DEVNULL)
            available = {p.name.lower() for p in Path(tmp).rglob("*.dll")}
            dll_names = ["d3dcompiler_47.dll", "libEGL.dll", "libGLESv2.dll", "vk_swiftshader.dll", "vulkan-1.dll", "zlib.dll"]
            for name in dll_names:
                entry = f'"${{ANGLE_SRC}}/{name}"'
                if name.lower() not in available:
                    text = text.replace(entry + "\n", "")
                    text = text.replace(entry + "\r\n", "")
                    print(f"ANGLE DLL absent in experimental archive, omitting from bundle list: {name}")

    write_text(cmake, text)
    print(f"Patched x86 libmpv MD5: {libmpv_md5}")
    print(f"Patched x86 ANGLE MD5: {angle_md5}")


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    sdk = sub.add_parser("patch-sdk")
    sdk.add_argument("--flutter-root", required=True, type=Path)
    mk = sub.add_parser("prepare-media-kit")
    mk.add_argument("--repo", type=Path, default=Path.cwd())
    mk.add_argument("--archive-dir", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == "patch-sdk":
            patch_flutter_sdk(args.flutter_root.resolve())
        else:
            prepare_media_kit(args.repo.resolve(), args.archive_dir.resolve())
        return 0
    except Exception as error:  # log and return a nonzero status for Actions
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())