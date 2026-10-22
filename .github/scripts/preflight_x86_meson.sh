#!/usr/bin/env bash
# Fast, source-level preflight for the exact Meson dependency chain that has
# previously failed after the expensive custom GCC build.
set -Eeuo pipefail

ROOT="$(pwd)"
TOOLCHAIN="$ROOT/mpv-winbuild-cmake"
RUN_TMP="${RUNNER_TEMP:-$(mktemp -d)}"
PREFIX="$RUN_TMP/x86-preflight/install"
TARGET_PREFIX="$PREFIX/i686-w64-mingw32"
TOOL_BIN="$PREFIX/bin"
CROSS_FILE="$RUN_TMP/x86-preflight/meson-cross.ini"
MESON="$RUN_TMP/mpv-preflight-venv/bin/meson"

mkdir -p "$RUN_TMP/x86-preflight" "$TOOL_BIN" "$TARGET_PREFIX/lib/pkgconfig"

echo "== Preflight source =="
test -f "$TOOLCHAIN/CMakeLists.txt"
test -f "$TOOLCHAIN/meson_cross.txt.in"
test -f "$TOOLCHAIN/packages/libdvdcss.cmake"
test -f "$TOOLCHAIN/packages/libdvdread.cmake"

# Fail if upstream changes the recipe and this test no longer mirrors it.
grep -Fq 'GIT_REPOSITORY https://code.videolan.org/videolan/libdvdcss.git' "$TOOLCHAIN/packages/libdvdcss.cmake"
grep -Fq 'GIT_REPOSITORY https://code.videolan.org/videolan/libdvdread.git' "$TOOLCHAIN/packages/libdvdread.cmake"
grep -Fq -- '-Dlibdvdcss=enabled' "$TOOLCHAIN/packages/libdvdread.cmake"
grep -Fq -- '--cross-file=${MESON_CROSS}' "$TOOLCHAIN/packages/libdvdread.cmake"
grep -Fq "sed -i" "$TOOLCHAIN/packages/libdvdread.cmake"

export PATH="$RUN_TMP/mpv-preflight-venv/bin:$PATH"
export PREFLIGHT_TARGET_PREFIX="$TARGET_PREFIX"
export PKG_CONFIG="pkgconf --static"
export PKG_CONFIG_LIBDIR="$TARGET_PREFIX/lib/pkgconfig"
unset PKG_CONFIG_PATH || true

echo "== Tool versions =="
"$MESON" --version
ninja --version
i686-w64-mingw32-gcc --version | head -n 1

# Recreate the target-prefixed compiler names expected by meson_cross.txt.in.
for tool in gcc g++ ar strip windres dlltool; do
  source_tool="$(command -v "i686-w64-mingw32-$tool")"
  ln -sf "$source_tool" "$TOOL_BIN/i686-w64-mingw32-$tool"
done

cat > "$TOOL_BIN/i686-w64-mingw32-pkgconf" <<'PKGCONF'
#!/usr/bin/env bash
set -Eeuo pipefail
export PKG_CONFIG_LIBDIR="${PREFLIGHT_TARGET_PREFIX:?}/lib/pkgconfig"
unset PKG_CONFIG_PATH || true
exec pkgconf --static "$@"
PKGCONF
chmod +x "$TOOL_BIN/i686-w64-mingw32-pkgconf"

sed \
  -e "s|@CMAKE_INSTALL_PREFIX@|$PREFIX|g" \
  -e 's|@TARGET_ARCH@|i686-w64-mingw32|g' \
  -e 's|@TARGET_CPU_FAMILY@|x86|g' \
  "$TOOLCHAIN/meson_cross.txt.in" > "$CROSS_FILE"

echo "== Validate 32-bit Windows compiler output =="
cat > "$RUN_TMP/x86-preflight/hello.c" <<'C'
int main(void) { return 0; }
C
i686-w64-mingw32-gcc "$RUN_TMP/x86-preflight/hello.c" -o "$RUN_TMP/x86-preflight/hello.exe"
file "$RUN_TMP/x86-preflight/hello.exe"
i686-w64-mingw32-objdump -f "$RUN_TMP/x86-preflight/hello.exe" | tee "$RUN_TMP/x86-preflight/hello-objdump.txt"
grep -Eqi 'file format pei-i386' "$RUN_TMP/x86-preflight/hello-objdump.txt"

echo "== Validate Meson cross-file compile/link =="
mkdir -p "$RUN_TMP/x86-preflight/meson-smoke"
cat > "$RUN_TMP/x86-preflight/meson-smoke/meson.build" <<'MESON'
project('mingw-x86-preflight', 'c', meson_version: '>= 1.3.0')
executable('smoke', 'main.c')
MESON
cp "$RUN_TMP/x86-preflight/hello.c" "$RUN_TMP/x86-preflight/meson-smoke/main.c"
"$MESON" setup "$RUN_TMP/x86-preflight/meson-smoke-build" "$RUN_TMP/x86-preflight/meson-smoke" \
  --cross-file="$CROSS_FILE" --buildtype=release --default-library=static
"$MESON" compile -C "$RUN_TMP/x86-preflight/meson-smoke-build"
file "$RUN_TMP/x86-preflight/meson-smoke-build/smoke.exe"
i686-w64-mingw32-objdump -f "$RUN_TMP/x86-preflight/meson-smoke-build/smoke.exe" | grep -Eqi 'file format pei-i386'

echo "== Build and install libdvdcss with the tested cross-file =="
CSS_SRC="$RUN_TMP/x86-preflight/libdvdcss-src"
CSS_BUILD="$RUN_TMP/x86-preflight/libdvdcss-build"
git clone --depth=1 --filter=tree:0 https://code.videolan.org/videolan/libdvdcss.git "$CSS_SRC"
CSS_SHA="$(git -C "$CSS_SRC" rev-parse HEAD)"
CONF=1 "$MESON" setup "$CSS_BUILD" "$CSS_SRC" \
  --prefix="$TARGET_PREFIX" \
  --libdir="$TARGET_PREFIX/lib" \
  --cross-file="$CROSS_FILE" \
  --buildtype=release \
  --default-library=static
"$MESON" compile -C "$CSS_BUILD"
"$MESON" install -C "$CSS_BUILD"
"$TOOL_BIN/i686-w64-mingw32-pkgconf" --modversion libdvdcss

echo "== Configure, build, and install libdvdread using the production options =="
READ_SRC="$RUN_TMP/x86-preflight/libdvdread-src"
READ_BUILD="$RUN_TMP/x86-preflight/libdvdread-build"
git clone --depth=1 --filter=tree:0 https://code.videolan.org/videolan/libdvdread.git "$READ_SRC"
READ_SHA="$(git -C "$READ_SRC" rev-parse HEAD)"

# Mirror packages/libdvdread.cmake's compatibility edit; require the target block
# to exist so a changed upstream file cannot silently invalidate the preflight.
if ! grep -q "^if import" "$READ_SRC/meson.build"; then
  echo "Expected the upstream Meson import block removed by libdvdread.cmake was not found." >&2
  exit 1
fi
sed -i '/^if import/,/endif/d' "$READ_SRC/meson.build"

"$MESON" setup "$READ_BUILD" "$READ_SRC" \
  --prefix="$TARGET_PREFIX" \
  --libdir="$TARGET_PREFIX/lib" \
  --cross-file="$CROSS_FILE" \
  --buildtype=release \
  --default-library=static \
  -Dlibdvdcss=enabled
"$MESON" compile -C "$READ_BUILD"
"$MESON" install -C "$READ_BUILD"

find "$TARGET_PREFIX/lib" -maxdepth 2 -type f \( -iname '*dvdcss*.a' -o -iname '*dvdread*.a' \) -print
test -n "$(find "$TARGET_PREFIX/lib" -type f -iname '*dvdread*.a' -print -quit)"

# Pass the tested inputs to the real build job and pin it to these exact revisions.
printf 'libdvdcss_sha=%s\n' "$CSS_SHA" >> "$GITHUB_OUTPUT"
printf 'libdvdread_sha=%s\n' "$READ_SHA" >> "$GITHUB_OUTPUT"
{
  echo "### x86 dependency preflight passed"
  echo "- Toolchain template commit: $(git -C "$TOOLCHAIN" rev-parse HEAD)"
  echo "- libdvdcss source: $CSS_SHA"
  echo "- libdvdread source: $READ_SHA"
  echo "- Tested: i686 compiler, Meson cross-file, libdvdcss configure/build/install, libdvdread configure/build/install."
} >> "$GITHUB_STEP_SUMMARY"

echo "PASS: the compiler and the exact libdvdcss -> libdvdread Meson chain configured, built, and installed."
