#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
ARCH=${FUTO_ARCH:-aarch64}
BUILD=${FUTO_BUILD_DIR:-$ROOT/build/$ARCH}
DEPS_ROOT=${FUTO_DEPS_ROOT:-$ROOT/build/dependencies}
SOURCE_ROOT=${FUTO_COMPOSITION_SOURCE_ROOT:-$DEPS_ROOT/sources}
COMPOSITION_BUILD=${FUTO_COMPOSITION_BUILD_DIR:-$BUILD/composition}
[[ -n ${FUTO_TARGET_SYSROOT:-} ]] || { echo "Set FUTO_TARGET_SYSROOT to the Sailfish SDK target" >&2; exit 1; }
export FUTO_COMPOSITION_BUILD_DIR="$COMPOSITION_BUILD"
bash "$ROOT/scripts/build-futo-mozc.sh"
TARGET_CXX=${FUTO_CXX:?Set FUTO_CXX to the target compiler}
TARGET_CC=${FUTO_CC:?Set FUTO_CC to the target compiler}
PREFIX=${TARGET_CXX%g++}
SHIM="$SOURCE_ROOT/futo-mozc/src/futo_cross/bin"
FLAGS="-B$SHIM/ -ffile-prefix-map=$ROOT=. -fmacro-prefix-map=$ROOT=. -ffile-prefix-map=$SOURCE_ROOT=upstream -fmacro-prefix-map=$SOURCE_ROOT=upstream -ffile-prefix-map=$COMPOSITION_BUILD=composition -fmacro-prefix-map=$COMPOSITION_BUILD=composition -ffile-prefix-map=$FUTO_TARGET_SYSROOT=sdk -fmacro-prefix-map=$FUTO_TARGET_SYSROOT=sdk"
cmake -S "$ROOT/composition" -B "$COMPOSITION_BUILD/rime" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DFUTO_RIME_JNI_SOURCE="$SOURCE_ROOT/futo-rime-jni" \
    -DFUTO_RIME_PREDICT_SOURCE="$SOURCE_ROOT/futo-rime-predict" \
    -DDOWNLOAD_PATH="$DEPS_ROOT/archives/composition" \
    -DJNI_DEPS_DIR="$DEPS_ROOT/sources/composition-dependencies" \
    -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR="$ARCH" \
    -DCMAKE_C_COMPILER="$TARGET_CC" -DCMAKE_CXX_COMPILER="$TARGET_CXX" \
    -DCMAKE_AR="${PREFIX}ar" -DCMAKE_RANLIB="${PREFIX}ranlib" \
    -DCMAKE_SYSROOT="$FUTO_TARGET_SYSROOT" -DCMAKE_FIND_ROOT_PATH="$FUTO_TARGET_SYSROOT" \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_C_FLAGS="$FLAGS" -DCMAKE_CXX_FLAGS="$FLAGS" -DCMAKE_ASM_FLAGS="-B$SHIM/" \
    -DCMAKE_EXE_LINKER_FLAGS="-B$SHIM/ -static-libstdc++ -static-libgcc"
cmake --build "$COMPOSITION_BUILD/rime" --target futo-keyboard-rime --parallel "${FUTO_BUILD_JOBS:-4}"
mkdir -p "$BUILD"
cp "$COMPOSITION_BUILD/futo-keyboard-mozc" "$BUILD/futo-keyboard-mozc"
cp "$COMPOSITION_BUILD/rime/futo-keyboard-rime" "$BUILD/futo-keyboard-rime"
"${FUTO_STRIP:-${PREFIX}strip}" "$BUILD/futo-keyboard-mozc" "$BUILD/futo-keyboard-rime"
