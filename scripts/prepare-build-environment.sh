#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ARCH=${FUTO_ARCH:-aarch64}
TARGET_SYSROOT=${FUTO_TARGET_SYSROOT:-}
LIB_DIRECTORY=
QT_CONFIG_DIRECTORY=
XKB_INCLUDE_DIRECTORY=${FUTO_XKBCOMMON_INCLUDE_ROOT:-}
DEPS_ROOT=${FUTO_DEPS_ROOT:-$ROOT/build/dependencies}
TOOLCHAIN_DIRECTORY=${FUTO_TOOLCHAIN_DIR:-}
TOOLCHAIN_LIB_DIRECTORY=${FUTO_TOOLCHAIN_LIB_DIR:-}
TOOL_PREFIX=${FUTO_TOOL_PREFIX:-}

QT_ARCHIVE_URL=https://codeload.github.com/qt/qtbase/tar.gz/e6f8b072d2bf15f8b82bede48ff29ce8ac8dbd9a
QT_COMMIT=e6f8b072d2bf15f8b82bede48ff29ce8ac8dbd9a
QT_ARCHIVE_SHA256=2379f234259c87ac87b7518243cc75c0bb6b8430d6c9f20d36052f4ad33bef1a
SECRETS_ARCHIVE_URL=https://codeload.github.com/sailfishos/sailfish-secrets/tar.gz/5a8d33e2eda2fe10a64acc42912dd3bedc736495
SECRETS_COMMIT=5a8d33e2eda2fe10a64acc42912dd3bedc736495
SECRETS_ARCHIVE_SHA256=aa1c07b1e8af5a692616160a48ac35114272e5efa2c3d106127ee3714c41ffe1

usage() {
    cat <<'EOF'
Usage: scripts/prepare-build-environment.sh [options]

Options:
  --arch ARCH             aarch64, armv7hl or i486
  --sysroot PATH          Matching Sailfish SDK target root
  --lib-dir PATH          Directory containing the target libraries
  --qt-config-dir PATH    Directory containing target qconfig.h/qfeatures.h
  --toolchain-dir PATH    Directory containing the cross compiler binaries
  --toolchain-lib-dir PATH
                          Directory containing the toolchain runtime libraries
  --tool-prefix PREFIX    Override the cross compiler prefix
  --xkb-include-root PATH Directory containing xkbcommon/*.h
  --deps-root PATH        Local dependency staging directory
  -h, --help              Show this help

Normally --sysroot and --toolchain-dir are enough. The other path options are
available for SDK installations that expose their files in unusual locations.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch) ARCH=${2:?Missing architecture}; shift 2 ;;
        --sysroot) TARGET_SYSROOT=${2:?Missing sysroot}; shift 2 ;;
        --lib-dir) LIB_DIRECTORY=${2:?Missing library directory}; shift 2 ;;
        --qt-config-dir) QT_CONFIG_DIRECTORY=${2:?Missing Qt config directory}; shift 2 ;;
        --toolchain-dir) TOOLCHAIN_DIRECTORY=${2:?Missing toolchain directory}; shift 2 ;;
        --toolchain-lib-dir) TOOLCHAIN_LIB_DIRECTORY=${2:?Missing toolchain library directory}; shift 2 ;;
        --tool-prefix) TOOL_PREFIX=${2:?Missing tool prefix}; shift 2 ;;
        --xkb-include-root) XKB_INCLUDE_DIRECTORY=${2:?Missing xkbcommon include root}; shift 2 ;;
        --deps-root) DEPS_ROOT=${2:?Missing dependency root}; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

case "$ARCH" in
    aarch64) DEFAULT_TOOL_PREFIX=aarch64-linux-gnu ;;
    armv7hl) DEFAULT_TOOL_PREFIX=armv7hl-meego-linux-gnueabi ;;
    i486) DEFAULT_TOOL_PREFIX=i486-meego-linux-gnu ;;
    *) echo "Unsupported architecture: $ARCH" >&2; exit 2 ;;
esac
if [[ -z "$TOOL_PREFIX" && -n "$TOOLCHAIN_DIRECTORY" ]]; then
    case "$ARCH" in
        aarch64) SDK_TOOL_PREFIX=aarch64-meego-linux-gnu ;;
        *) SDK_TOOL_PREFIX=$DEFAULT_TOOL_PREFIX ;;
    esac
    if [[ -x "$TOOLCHAIN_DIRECTORY/$SDK_TOOL_PREFIX-g++" ]]; then
        TOOL_PREFIX=$SDK_TOOL_PREFIX
    fi
fi
TOOL_PREFIX=${TOOL_PREFIX:-$DEFAULT_TOOL_PREFIX}

if [[ -z "$TARGET_SYSROOT" && -z "$LIB_DIRECTORY" ]]; then
    echo "Pass --sysroot with a matching Sailfish SDK target root." >&2
    echo "Use --lib-dir only when the target libraries are stored separately." >&2
    exit 2
fi
if [[ -n "$TARGET_SYSROOT" && ! -d "$TARGET_SYSROOT" ]]; then
    echo "Sailfish target root does not exist: $TARGET_SYSROOT" >&2
    exit 2
fi
if [[ -n "$LIB_DIRECTORY" && ! -d "$LIB_DIRECTORY" ]]; then
    echo "Target library directory does not exist: $LIB_DIRECTORY" >&2
    exit 2
fi
if [[ -n "$TOOLCHAIN_DIRECTORY" && ! -d "$TOOLCHAIN_DIRECTORY" ]]; then
    echo "Toolchain directory does not exist: $TOOLCHAIN_DIRECTORY" >&2
    exit 2
fi
if [[ -n "$TOOLCHAIN_LIB_DIRECTORY" && ! -d "$TOOLCHAIN_LIB_DIRECTORY" ]]; then
    echo "Toolchain library directory does not exist: $TOOLCHAIN_LIB_DIRECTORY" >&2
    exit 2
fi
if [[ -n "$XKB_INCLUDE_DIRECTORY" && \
      ! -s "$XKB_INCLUDE_DIRECTORY/xkbcommon/xkbcommon-compose.h" ]]; then
    echo "xkbcommon headers were not found below: $XKB_INCLUDE_DIRECTORY" >&2
    exit 2
fi

find_toolchain_lib_directory() {
    local candidate
    [[ -n "$TOOLCHAIN_LIB_DIRECTORY" ]] && {
        printf '%s\n' "$TOOLCHAIN_LIB_DIRECTORY"
        return 0
    }
    [[ -n "$TOOLCHAIN_DIRECTORY" ]] || return 1
    for candidate in \
        "$TOOLCHAIN_DIRECTORY/../../../usr/lib" \
        "$TOOLCHAIN_DIRECTORY/../../usr/lib" \
        "$TOOLCHAIN_DIRECTORY/../lib"; do
        if [[ -d "$candidate" ]] && \
           find -L "$candidate" -maxdepth 1 -name 'libmpc.so*' -print -quit \
               2>/dev/null | grep -q .; then
            (cd "$candidate" && pwd -P)
            return 0
        fi
    done
    return 1
}

if [[ -n "$TOOLCHAIN_DIRECTORY" && -z "$TOOLCHAIN_LIB_DIRECTORY" ]]; then
    TOOLCHAIN_LIB_DIRECTORY=$(find_toolchain_lib_directory || true)
fi

for tool in curl tar find cp grep ln sha256sum; do
    command -v "$tool" >/dev/null || {
        echo "Missing host tool: $tool" >&2
        exit 1
    }
done

SOURCE_ROOT="$DEPS_ROOT/sources"
DOWNLOAD_ROOT="$DEPS_ROOT/downloads"
TARGET_ROOT="$DEPS_ROOT/$ARCH"
TARGET_LIB_ROOT="$TARGET_ROOT/lib"
TARGET_QT_CONFIG_ROOT="$TARGET_ROOT/qt-config"
TARGET_XKB_INCLUDE_ROOT="$TARGET_ROOT/xkbcommon-include"
TARGET_TOOLCHAIN_SHIM="$TARGET_ROOT/toolchain-bin"
mkdir -p "$SOURCE_ROOT" "$DOWNLOAD_ROOT" "$TARGET_LIB_ROOT" \
    "$TARGET_QT_CONFIG_ROOT" "$TARGET_XKB_INCLUDE_ROOT"

if [[ -n "$TOOLCHAIN_DIRECTORY" ]]; then
    rm -rf "$TARGET_TOOLCHAIN_SHIM"
    mkdir -p "$TARGET_TOOLCHAIN_SHIM"
    for tool in as ld ar nm objcopy objdump ranlib; do
        source_tool="$TOOLCHAIN_DIRECTORY/$TOOL_PREFIX-$tool"
        if [[ -x "$source_tool" ]]; then
            ln -s "$source_tool" "$TARGET_TOOLCHAIN_SHIM/$tool"
        fi
    done
    for tool in as ld; do
        if [[ ! -x "$TARGET_TOOLCHAIN_SHIM/$tool" ]]; then
            echo "Missing target $tool: $TOOLCHAIN_DIRECTORY/$TOOL_PREFIX-$tool" >&2
            exit 1
        fi
    done
fi

extract_pinned() {
    local url=$1
    local commit=$2
    local expected_sha256=$3
    local archive_name=$4
    local destination=$5
    local label=$6
    local archive="$DOWNLOAD_ROOT/$archive_name"
    local marker="$destination/.futo-source-revision"
    if [[ -s "$marker" && $(cat "$marker") == "$commit" ]]; then
        return
    fi
    if [[ ! -s "$archive" ]]; then
        curl --fail --location --retry 3 --output "$archive" "$url"
    fi
    echo "$expected_sha256  $archive" | sha256sum --check --status || {
        rm -f "$archive"
        echo "$label source archive failed SHA-256 verification." >&2
        exit 1
    }
    local staging="$SOURCE_ROOT/.extract-${archive_name%.tar.gz}-$$"
    rm -rf "$staging" "$destination"
    mkdir -p "$staging"
    tar -xzf "$archive" --strip-components=1 -C "$staging"
    printf '%s\n' "$commit" > "$staging/.futo-source-revision"
    mv "$staging" "$destination"
}

echo "Preparing pinned source dependencies..."
extract_pinned "$QT_ARCHIVE_URL" "$QT_COMMIT" "$QT_ARCHIVE_SHA256" \
    qtbase-5.6.3.tar.gz "$SOURCE_ROOT/qtbase-5.6.3" "Qt 5.6.3"
extract_pinned "$SECRETS_ARCHIVE_URL" "$SECRETS_COMMIT" "$SECRETS_ARCHIVE_SHA256" \
    sailfish-secrets-0.2.44.tar.gz \
    "$SOURCE_ROOT/sailfish-secrets-0.2.44" "Sailfish Secrets 0.2.44"

find_target_file() {
    local name=$1
    local candidate
    if [[ -n "$LIB_DIRECTORY" ]]; then
        for candidate in "$LIB_DIRECTORY/$name" "$LIB_DIRECTORY"/*/"$name"; do
            [[ -e "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
        done
    fi
    if [[ -n "$TARGET_SYSROOT" ]]; then
        candidate=$(find -L "$TARGET_SYSROOT/usr/lib64" "$TARGET_SYSROOT/usr/lib" \
            -maxdepth 4 -name "$name" -print -quit 2>/dev/null || true)
        [[ -n "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
    fi
    return 1
}

REQUIRED_LIBRARIES=(
    libQt5Core.so.5.6.3
    libQt5DBus.so.5.6.3
    libQt5Gui.so.5.6.3
    libQt5WaylandClient.so.5.6.3
    libsailfishsecrets.so.0.2.44
    libxkbcommon.so.0.0.0
)

echo "Staging target libraries for $ARCH..."
rm -f "$TARGET_LIB_ROOT"/*
for library in "${REQUIRED_LIBRARIES[@]}"; do
    source_file=$(find_target_file "$library") || {
        echo "Missing $library in the selected Sailfish target." >&2
        echo "Install the corresponding development package in that SDK target." >&2
        exit 1
    }
    cp -L "$source_file" "$TARGET_LIB_ROOT/$library"
done

find_qt_config() {
    local name=$1
    local candidate
    if [[ -n "$QT_CONFIG_DIRECTORY" && -s "$QT_CONFIG_DIRECTORY/$name" ]]; then
        printf '%s\n' "$QT_CONFIG_DIRECTORY/$name"
        return 0
    fi
    if [[ -n "$TARGET_SYSROOT" ]]; then
        candidate=$(find -L "$TARGET_SYSROOT/usr/include" -path "*/QtCore/$name" \
            -print -quit 2>/dev/null || true)
        [[ -n "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
    fi
    return 1
}

for header in qconfig.h qfeatures.h; do
    source_file=$(find_qt_config "$header") || {
        echo "Missing target Qt header QtCore/$header." >&2
        echo "Install qt5-qtbase-devel in the Sailfish SDK target, or pass --qt-config-dir." >&2
        exit 1
    }
    cp -L "$source_file" "$TARGET_QT_CONFIG_ROOT/$header"
done

find_xkb_include_root() {
    local candidate
    if [[ -n "$XKB_INCLUDE_DIRECTORY" ]]; then
        printf '%s\n' "$XKB_INCLUDE_DIRECTORY"
        return 0
    fi
    if [[ -n "$TARGET_SYSROOT" ]]; then
        for candidate in "$TARGET_SYSROOT/usr/include" \
                "$TARGET_SYSROOT/usr/include"/*; do
            if [[ -s "$candidate/xkbcommon/xkbcommon-compose.h" ]]; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    fi
    if [[ -s /usr/include/xkbcommon/xkbcommon-compose.h ]]; then
        printf '%s\n' /usr/include
        return 0
    fi
    return 1
}

source_xkb_root=$(find_xkb_include_root) || {
    echo "Missing xkbcommon development headers." >&2
    echo "Install libxkbcommon-devel in the SDK target or libxkbcommon-dev on the host," >&2
    echo "or pass --xkb-include-root." >&2
    exit 1
}
rm -rf "$TARGET_XKB_INCLUDE_ROOT/xkbcommon"
cp -LR "$source_xkb_root/xkbcommon" "$TARGET_XKB_INCLUDE_ROOT/xkbcommon"

ENVIRONMENT_FILE="$TARGET_ROOT/environment.sh"
{
    printf '# Generated by scripts/prepare-build-environment.sh\n'
    printf 'export FUTO_ARCH=%q\n' "$ARCH"
    printf 'export FUTO_DEPS_ROOT=%q\n' "$DEPS_ROOT"
    if [[ -n "$TARGET_SYSROOT" ]]; then
        printf 'export FUTO_TARGET_SYSROOT=%q\n' "$TARGET_SYSROOT"
    fi
    if [[ -n "$TOOLCHAIN_DIRECTORY" ]]; then
        printf 'export FUTO_TOOLCHAIN_DIR=%q\n' "$TOOLCHAIN_DIRECTORY"
    fi
    if [[ -n "$TOOLCHAIN_LIB_DIRECTORY" ]]; then
        printf 'export FUTO_TOOLCHAIN_LIB_DIR=%q\n' "$TOOLCHAIN_LIB_DIRECTORY"
        printf 'case ":${LD_LIBRARY_PATH:-}:" in\n'
        printf '    *":${FUTO_TOOLCHAIN_LIB_DIR}:"*) ;;\n'
        printf '    *) export LD_LIBRARY_PATH="${FUTO_TOOLCHAIN_LIB_DIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" ;;\n'
        printf 'esac\n'
    fi
    if [[ -n "$TOOLCHAIN_DIRECTORY" ]]; then
        printf 'export FUTO_TOOLCHAIN_SHIM=%q\n' "$TARGET_TOOLCHAIN_SHIM"
    fi
    printf 'export FUTO_TOOL_PREFIX=%q\n' "$TOOL_PREFIX"
    printf 'export FUTO_XKBCOMMON_INCLUDE_ROOT=%q\n' "$TARGET_XKB_INCLUDE_ROOT"
} > "$ENVIRONMENT_FILE"

echo
echo "Build environment prepared:"
echo "  sources: $SOURCE_ROOT"
echo "  target libraries: $TARGET_LIB_ROOT"
echo "  target Qt configuration: $TARGET_QT_CONFIG_ROOT"
echo "  xkbcommon headers: $TARGET_XKB_INCLUDE_ROOT"
if [[ -n "$TOOLCHAIN_LIB_DIRECTORY" ]]; then
    echo "  toolchain runtime libraries: $TOOLCHAIN_LIB_DIRECTORY"
fi
if [[ -n "$TOOLCHAIN_DIRECTORY" ]]; then
    echo "  target binutils: $TARGET_TOOLCHAIN_SHIM"
fi
echo
echo "Next run:"
printf '  source %q\n' "$ENVIRONMENT_FILE"
echo "  scripts/check-build-environment.sh"
echo "  scripts/build-rpm.sh"
