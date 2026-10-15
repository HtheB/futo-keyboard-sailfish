#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEPS_ROOT=${FUTO_DEPS_ROOT:-$ROOT/build/dependencies}
SOURCE_ROOT=${FUTO_COMPOSITION_SOURCE_ROOT:-$DEPS_ROOT/sources}
SOURCE="$SOURCE_ROOT/futo-mozc/src"
BUILD=${FUTO_COMPOSITION_BUILD_DIR:-$ROOT/build/composition}
BAZEL=${FUTO_BAZEL:-bazel}
"$ROOT/scripts/bootstrap-futo-composition.sh"
mkdir -p "$BUILD"
TARGET_OPTIONS=()
TARGETS=(//android/jni:futo-keyboard-mozc)

# Stage our adapter inside the package permitted to access SessionHandler.
# The source checkout is ignored; only this adapter is maintained in our repo.
cp "$ROOT/composition/mozc_worker.cpp" "$SOURCE/android/jni/futo_mozc_worker.cpp"
cp "$ROOT/composition/protocol.h" "$SOURCE/android/jni/protocol.h"
if ! grep -q 'name = "futo-keyboard-mozc"' "$SOURCE/android/jni/BUILD.bazel"; then
    # Bulk staging, not a rewrite of maintained project files.
    sed '1d' "$ROOT/composition/mozc.BUILD.bazel" >> "$SOURCE/android/jni/BUILD.bazel"
fi
(
    cd "$SOURCE"
    if [[ -n ${FUTO_TARGET_SYSROOT:-} ]]; then
        "$BAZEL" --output_user_root="$BUILD/bazel-cache" build --nobuild \
            --config=oss_linux --config=release_build //android/jni:futo-keyboard-mozc
        EXECUTION_ROOT=$("$BAZEL" --output_user_root="$BUILD/bazel-cache" info execution_root)
        CC_CONFIG=$(find "$EXECUTION_ROOT/external" -path '*local_config_cc*/cc_toolchain_config.bzl' -print -quit)
        [[ -n "$CC_CONFIG" ]] || { echo "Bazel's Unix C++ toolchain was not found" >&2; exit 1; }
        TARGET_CXX=${FUTO_CXX:?Set FUTO_CXX to the target compiler}
        TARGET_PREFIX=${TARGET_CXX%g++}
        node "$ROOT/scripts/configure-mozc-cross.js" "$SOURCE" "$CC_CONFIG" \
            "$TARGET_PREFIX" "$FUTO_TARGET_SYSROOT" "${FUTO_ARCH:-aarch64}"
        TARGET_OPTIONS=(--platforms=//futo_cross:platform --extra_toolchains=//futo_cross:registered)
    else
        TARGETS+=(//data_manager/oss:mozc_dataset_for_oss)
    fi
    "$BAZEL" --output_user_root="$BUILD/bazel-cache" build \
        --config=oss_linux --config=release_build --jobs="${FUTO_BUILD_JOBS:-4}" \
        --copt="-ffile-prefix-map=$SOURCE=mozc" \
        --copt="-fmacro-prefix-map=$SOURCE=mozc" \
        "${TARGET_OPTIONS[@]}" "${TARGETS[@]}"
    install -m0755 bazel-bin/android/jni/futo-keyboard-mozc "$BUILD/futo-keyboard-mozc"
    if [[ -z ${FUTO_TARGET_SYSROOT:-} ]]; then
        cp bazel-bin/data_manager/oss/mozc.data "$BUILD/mozc.data"
    fi
)
echo "Japanese conversion worker built in $BUILD"
