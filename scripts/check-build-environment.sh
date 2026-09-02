#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ARCH=${FUTO_ARCH:-aarch64}
DEPS_ROOT=${FUTO_DEPS_ROOT:-$ROOT/build/dependencies}
QT_SOURCE=${FUTO_QT_SOURCE:-$DEPS_ROOT/sources/qtbase-5.6.3}
SECRETS_SOURCE=${FUTO_SECRETS_SOURCE:-$DEPS_ROOT/sources/sailfish-secrets-0.2.44}
TARGET_LIB_ROOT=${FUTO_TARGET_LIB_ROOT:-${FUTO_PHONE_LIB_ROOT:-$DEPS_ROOT/$ARCH/lib}}
QT_CONFIG_ROOT=${FUTO_QT_CONFIG_ROOT:-$DEPS_ROOT/$ARCH/qt-config}
XKB_INCLUDE_ROOT=${FUTO_XKBCOMMON_INCLUDE_ROOT:-$DEPS_ROOT/$ARCH/xkbcommon-include}
TOOLCHAIN_DIRECTORY=${FUTO_TOOLCHAIN_DIR:-}
CROSS_ROOT=${FUTO_CROSS_ROOT:-}
TOOLCHAIN_SHIM=${FUTO_TOOLCHAIN_SHIM:-}
COMPILER_FLAGS=()
if [[ -n "$TOOLCHAIN_SHIM" ]]; then
    COMPILER_FLAGS=(-B"$TOOLCHAIN_SHIM/")
fi

case "$ARCH" in
    aarch64) DEFAULT_TOOL_PREFIX=aarch64-linux-gnu ;;
    armv7hl) DEFAULT_TOOL_PREFIX=armv7hl-meego-linux-gnueabi ;;
    i486) DEFAULT_TOOL_PREFIX=i486-meego-linux-gnu ;;
    *) echo "Unsupported architecture: $ARCH" >&2; exit 2 ;;
esac
TOOL_PREFIX=${FUTO_TOOL_PREFIX:-$DEFAULT_TOOL_PREFIX}

tool_path() {
    local name=$1
    if [[ -n "$TOOLCHAIN_DIRECTORY" ]]; then
        printf '%s/%s\n' "$TOOLCHAIN_DIRECTORY" "$name"
    elif [[ -n "$CROSS_ROOT" && -x "$CROSS_ROOT/usr/bin/$name" ]]; then
        printf '%s/usr/bin/%s\n' "$CROSS_ROOT" "$name"
    elif [[ -n "$CROSS_ROOT" && -x "$CROSS_ROOT/bin/$name" ]]; then
        printf '%s/bin/%s\n' "$CROSS_ROOT" "$name"
    else
        command -v "$name" 2>/dev/null || true
    fi
}

CXX=${FUTO_CXX:-$(tool_path "$TOOL_PREFIX-g++")}
CC=${FUTO_CC:-$(tool_path "$TOOL_PREFIX-gcc")}
STRIP=${FUTO_STRIP:-$(tool_path "$TOOL_PREFIX-strip")}
READELF=${FUTO_READELF:-$(tool_path "$TOOL_PREFIX-readelf")}
PATCHELF=${FUTO_PATCHELF:-$(command -v patchelf 2>/dev/null || true)}

failed=0
require_tool() {
    local label=$1
    local value=$2
    if [[ -z "$value" || ! -x "$value" ]]; then
        echo "Missing $label${value:+: $value}" >&2
        failed=1
    fi
}
require_file() {
    local label=$1
    local value=$2
    if [[ ! -s "$value" ]]; then
        echo "Missing $label: $value" >&2
        failed=1
    fi
}

compiler_smoke_test() {
    local label=$1
    local compiler=$2
    local language=$3
    local frontend_name=$4
    local compiler_output=""
    local frontend=""
    local missing_libraries=""
    local object_file

    object_file=$(mktemp)
    if compiler_output=$(printf 'int main(void) { return 0; }\n' \
            | "$compiler" "${COMPILER_FLAGS[@]}" -x "$language" -c -o "$object_file" - \
                2>&1); then
        rm -f "$object_file"
        return
    fi
    rm -f "$object_file"

    echo "$label cannot compile a minimal source file: $compiler" >&2
    if [[ -n "$compiler_output" ]]; then
        printf '%s\n' "$compiler_output" >&2
    fi

    frontend=$("$compiler" -print-prog-name="$frontend_name" 2>/dev/null || true)
    if [[ -n "$frontend" && -x "$frontend" ]] && command -v ldd >/dev/null 2>&1; then
        missing_libraries=$(ldd "$frontend" 2>/dev/null \
                | grep 'not found' || true)
        if [[ -n "$missing_libraries" ]]; then
            echo "Missing runtime libraries for $frontend_name:" >&2
            printf '%s\n' "$missing_libraries" >&2
        fi
    fi

    if [[ "$compiler_output$missing_libraries" == *libmpc.so.3* ]]; then
        echo "On Ubuntu or Debian, install the libmpc3 package." >&2
    fi
    failed=1
}

for host_tool in bash g++ gcc go node python3 perl curl dpkg-deb make rpm rpmbuild \
        tar gzip sha256sum file; do
    require_tool "host tool $host_tool" "$(command -v "$host_tool" 2>/dev/null || true)"
done
require_tool "cross C++ compiler" "$CXX"
require_tool "cross C compiler" "$CC"
require_tool "cross strip" "$STRIP"
require_tool "cross readelf" "$READELF"
require_tool "host patchelf" "$PATCHELF"
if [[ -n "$TOOLCHAIN_SHIM" ]]; then
    require_tool "target assembler" "$TOOLCHAIN_SHIM/as"
    require_tool "target linker" "$TOOLCHAIN_SHIM/ld"
fi

if [[ -n "$CXX" && -x "$CXX" ]]; then
    compiler_smoke_test "Cross C++ compiler" "$CXX" c++ cc1plus
fi
if [[ -n "$CC" && -x "$CC" ]]; then
    compiler_smoke_test "Cross C compiler" "$CC" c cc1
fi

require_file "Qt Compose source" \
    "$QT_SOURCE/src/plugins/platforminputcontexts/compose/qcomposeplatforminputcontext.cpp"
require_file "Sailfish Secrets source" "$SECRETS_SOURCE/lib/Secrets/secretmanager.h"
require_file "target Qt qconfig.h" "$QT_CONFIG_ROOT/qconfig.h"
require_file "target Qt qfeatures.h" "$QT_CONFIG_ROOT/qfeatures.h"
require_file "xkbcommon compose header" \
    "$XKB_INCLUDE_ROOT/xkbcommon/xkbcommon-compose.h"
require_file "xkbcommon keysym header" \
    "$XKB_INCLUDE_ROOT/xkbcommon/xkbcommon-keysyms.h"
for library in libQt5Core.so.5.6.3 libQt5DBus.so.5.6.3 libQt5Gui.so.5.6.3 \
        libQt5WaylandClient.so.5.6.3 libsailfishsecrets.so.0.2.44 \
        libxkbcommon.so.0.0.0; do
    require_file "target library" "$TARGET_LIB_ROOT/$library"
done

if (( failed )); then
    echo >&2
    echo "The build environment is incomplete." >&2
    echo "Run scripts/prepare-build-environment.sh with the matching Sailfish SDK target." >&2
    exit 1
fi

echo "FUTO Keyboard build environment is ready for $ARCH."
echo "  Qt source: $QT_SOURCE"
echo "  Sailfish Secrets source: $SECRETS_SOURCE"
echo "  target libraries: $TARGET_LIB_ROOT"
echo "  xkbcommon headers: $XKB_INCLUDE_ROOT"
echo "  compiler: $CXX"
