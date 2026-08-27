#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ARCH=${FUTO_ARCH:-aarch64}
BUILD=${FUTO_BUILD_DIR:-$ROOT/build/$ARCH}
SHARED_ROOT=${FUTO_SHARED_ROOT:-$ROOT/../shared}
TARGET_LIB_ROOT=${FUTO_TARGET_LIB_ROOT:-${FUTO_PHONE_LIB_ROOT:-$SHARED_ROOT/futo-phone-sysroot}}
CROSS_ROOT=${FUTO_CROSS_ROOT:-}
case "$ARCH" in
    aarch64)
        TOOL_PREFIX=aarch64-linux-gnu
        DEFAULT_STOCK_SHA256=010984f4d31601b06c2c9589a3dbd223465d63434415ccaf45fc9bf232902b29
        DEFAULT_RELOCATION=00000000000e09c0
        ;;
    armv7hl)
        TOOL_PREFIX=armv7hl-meego-linux-gnueabi
        DEFAULT_STOCK_SHA256=c0df1ba2a00856cf210d13a5c97353f89c7a1f67a7e8d35b45b4c31cc4b382d1
        DEFAULT_RELOCATION=000a0454
        ;;
    i486)
        TOOL_PREFIX=i486-meego-linux-gnu
        DEFAULT_STOCK_SHA256=3ce3c1a3f47f4a8eed0847e279a9191a545f22e5dd056b28230d5b075edef832
        DEFAULT_RELOCATION=000bd2e0
        ;;
    *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac
if [[ -n "$CROSS_ROOT" ]]; then
    DEFAULT_CXX="$CROSS_ROOT/usr/bin/$TOOL_PREFIX-g++"
    DEFAULT_STRIP="$CROSS_ROOT/usr/bin/$TOOL_PREFIX-strip"
    DEFAULT_READELF="$CROSS_ROOT/usr/bin/$TOOL_PREFIX-readelf"
else
    DEFAULT_CXX="$TOOL_PREFIX-g++"
    DEFAULT_STRIP="$TOOL_PREFIX-strip"
    DEFAULT_READELF="$TOOL_PREFIX-readelf"
fi
CXX=${FUTO_CXX:-${CXX_AARCH64:-$DEFAULT_CXX}}
STRIP=${FUTO_STRIP:-${STRIP_AARCH64:-$DEFAULT_STRIP}}
READELF=${FUTO_READELF:-${READELF_AARCH64:-$DEFAULT_READELF}}
PATCHELF=${FUTO_PATCHELF:-$SHARED_ROOT/patchelf-host/usr/bin/patchelf}
INCLUDE=${FUTO_QT_INCLUDE_ROOT:-$BUILD/qt-compose-includes/include}
XKB_INCLUDE_ROOT=${FUTO_XKBCOMMON_INCLUDE_ROOT:-}
XKB_INCLUDE_FLAGS=()
if [[ -n "$XKB_INCLUDE_ROOT" ]]; then
    XKB_INCLUDE_FLAGS=(-I"$XKB_INCLUDE_ROOT")
fi
STOCK=$TARGET_LIB_ROOT/libQt5WaylandClient.so.5.6.3
ORIGINAL=$BUILD/libQt5WaylandClientFutoOriginal.so.5.6.3
HOOK=$BUILD/libQt5WaylandClient.so.5.6.3
OBJECT=$BUILD/futo_wayland_deadkey_hook.o
EXPECTED_STOCK_SHA256=${FUTO_EXPECTED_STOCK_SHA256:-$DEFAULT_STOCK_SHA256}
EXPECTED_RELOCATION=${FUTO_EXPECTED_WAYLAND_RELOCATION:-$DEFAULT_RELOCATION}
PREPATCHED_ORIGINAL=${FUTO_PREPATCHED_WAYLAND_ORIGINAL:-}

for tool_name in CXX STRIP READELF; do
    tool_value=${!tool_name}
    if command -v "$tool_value" >/dev/null 2>&1; then
        printf -v "$tool_name" '%s' "$(command -v "$tool_value")"
    fi
done

for required in "$CXX" "$STRIP" "$READELF" "$STOCK" \
    "$INCLUDE/QtCore/QEvent" "$INCLUDE/QtGui/QWindow" \
    "$ROOT/hardware/compose/futo_wayland_deadkey_hook.cpp" \
    "$ROOT/hardware/compose/qt5-wayland-hook.map"; do
    test -s "$required" || { echo "Missing QtWayland hook input: $required" >&2; exit 1; }
done
if [[ -z "$PREPATCHED_ORIGINAL" ]]; then
    test -x "$PATCHELF" || { echo "Missing host patchelf: $PATCHELF" >&2; exit 1; }
else
    test -s "$PREPATCHED_ORIGINAL" || {
        echo "Missing prepatched QtWayland client: $PREPATCHED_ORIGINAL" >&2
        exit 1
    }
fi

actual_sha256=$(sha256sum "$STOCK" | cut -d' ' -f1)
test "$actual_sha256" = "$EXPECTED_STOCK_SHA256" || {
    echo "Unsupported libQt5WaylandClient build: $actual_sha256" >&2
    exit 1
}

relocation=$($READELF -rW "$STOCK" | awk \
	'/QWindowSystemInterface22handleExtendedKeyEvent/ && !found { value=$1; found=1 } \
	 END { if (found) print value }')
test "$relocation" = "$EXPECTED_RELOCATION" || {
    echo "Unexpected QtWayland key-event relocation: $relocation" >&2
    exit 1
}

if [[ -n "$PREPATCHED_ORIGINAL" ]]; then
    cp "$PREPATCHED_ORIGINAL" "$ORIGINAL"
else
    cp "$STOCK" "$ORIGINAL"
    "$PATCHELF" --set-soname libQt5WaylandClientFutoOriginal.so.5 "$ORIGINAL"
fi
"$READELF" -d "$ORIGINAL" | \
    grep -q 'Library soname: \[libQt5WaylandClientFutoOriginal.so.5\]' || {
        echo "Prepatched QtWayland client has the wrong SONAME" >&2
        exit 1
    }
printf '%s\n' "$EXPECTED_STOCK_SHA256" > "$BUILD/stock-wayland.sha256"

"$CXX" -std=c++11 -O2 -DNDEBUG -fPIC -DQT_SHARED -DQT_NO_DEBUG \
    -I"$INCLUDE" \
    -I"$INCLUDE/QtCore" \
    -I"$INCLUDE/QtCore/5.6.3" \
    -I"$INCLUDE/QtCore/5.6.3/QtCore" \
    -I"$INCLUDE/QtGui" \
    -I"$INCLUDE/QtGui/5.6.3" \
    -I"$INCLUDE/QtGui/5.6.3/QtGui" \
    "${XKB_INCLUDE_FLAGS[@]}" \
    -DFUTO_WAYLAND_RELOCATION_OFFSET="0x$relocation" \
    -c "$ROOT/hardware/compose/futo_wayland_deadkey_hook.cpp" -o "$OBJECT"

"$CXX" -shared \
    -Wl,-soname,libQt5WaylandClient.so.5 \
    -Wl,--version-script="$ROOT/hardware/compose/qt5-wayland-hook.map" \
    -Wl,--no-as-needed "$OBJECT" \
    -L"$BUILD" -l:libQt5WaylandClientFutoOriginal.so.5.6.3 \
    -Wl,--as-needed -L"$TARGET_LIB_ROOT" \
    -l:libQt5Gui.so.5.6.3 -l:libQt5Core.so.5.6.3 \
    -l:libxkbcommon.so.0.0.0 -ldl -lpthread \
    -o "$HOOK"
"$STRIP" "$HOOK"

file "$HOOK" "$ORIGINAL"
