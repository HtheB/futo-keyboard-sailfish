#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ARCH=${FUTO_ARCH:-aarch64}
DEPS_ROOT=${FUTO_DEPS_ROOT:-$ROOT/build/dependencies}
SOURCE=${FUTO_SWIPE_SOURCE:-$DEPS_ROOT/sources/futo-swipe-library}
REVISION=1b13f2c85d6b347f6ea3fbc4b3aaf01fce42429a
JOBS=${FUTO_JOBS:-$(nproc 2>/dev/null || echo 4)}

case "$ARCH" in
    aarch64)
        TOOL_PREFIX=${FUTO_TOOL_PREFIX:-aarch64-linux-gnu}
        PROCESSOR=aarch64
        ;;
    armv7hl)
        TOOL_PREFIX=${FUTO_TOOL_PREFIX:-armv7hl-meego-linux-gnueabi}
        PROCESSOR=armv7
        ;;
    i486)
        TOOL_PREFIX=${FUTO_TOOL_PREFIX:-i486-meego-linux-gnu}
        PROCESSOR=i686
        ;;
    *)
        echo "Unsupported architecture: $ARCH" >&2
        exit 1
        ;;
esac

CC=${FUTO_CC:-$TOOL_PREFIX-gcc}
CXX=${FUTO_CXX:-$TOOL_PREFIX-g++}
ET_BUILD=${FUTO_SWIPE_ET_BUILD:-$SOURCE/third_party/executorch/cmake-out-sailfish-$ARCH}
TARGET_SYSROOT=${FUTO_TARGET_SYSROOT:-}
OPS='aten::_log_softmax.out,aten::arange.start_out,aten::atan2.out,aten::bitwise_not.out,aten::clamp.out,aten::cumsum.out,aten::embedding.out,aten::expand_copy.out,aten::full_like.out,aten::gt.Scalar_out,aten::lt.Scalar_out,aten::native_layer_norm.out,aten::scalar_tensor.out,aten::select_copy.int_out,aten::split_with_sizes_copy.out,aten::squeeze_copy.dims_out,aten::sum.IntList_out,aten::unsqueeze_copy.out,aten::where.self_out,dim_order_ops::_to_dim_order_copy.out'

TARGET_C_FLAGS=()
TARGET_CPU_FLAGS=""
if [[ "$ARCH" == i486 ]]; then
    # Sailfish's i486 target is used by Intel Atom devices. XNNPACK's x86
    # baseline uses SSE2, but the generic SDK compiler does not enable it
    # unless requested explicitly.
    TARGET_CPU_FLAGS="-msse2 -mfpmath=sse"
fi
if [[ -n "$TARGET_SYSROOT" ]]; then
    # Sailfish's cross compiler is relocatable, but a host-side invocation
    # does not know which installed target root it should use. Keep these
    # flags on target compilation only; ExecuTorch also builds a native flatc
    # helper, which must continue using the host headers and assembler.
    TOOL_SHIM="$ET_BUILD/toolchain-bin"
    TOOL_DIRECTORY=$(dirname "$CC")
    TARGET_AS=$(command -v "$TOOL_PREFIX-as" || true)
    TARGET_LD=$(command -v "$TOOL_PREFIX-ld" || true)
    [[ -n "$TARGET_AS" ]] || TARGET_AS="$TOOL_DIRECTORY/$TOOL_PREFIX-as"
    [[ -n "$TARGET_LD" ]] || TARGET_LD="$TOOL_DIRECTORY/$TOOL_PREFIX-ld"
    test -x "$TARGET_AS" || { echo "Missing target assembler: $TARGET_AS" >&2; exit 1; }
    test -x "$TARGET_LD" || { echo "Missing target linker: $TARGET_LD" >&2; exit 1; }
    mkdir -p "$TOOL_SHIM"
    ln -sfn "$TARGET_AS" "$TOOL_SHIM/as"
    ln -sfn "$TARGET_LD" "$TOOL_SHIM/ld"
    TARGET_C_FLAGS=(
        -DCMAKE_SYSROOT="$TARGET_SYSROOT"
        -DCMAKE_C_FLAGS="-B$TOOL_SHIM $TARGET_CPU_FLAGS"
        -DCMAKE_CXX_FLAGS="-B$TOOL_SHIM $TARGET_CPU_FLAGS"
        -DCMAKE_ASM_FLAGS="-B$TOOL_SHIM"
    )
fi

if [[ ! -d "$SOURCE/.git" ]]; then
    mkdir -p "$(dirname "$SOURCE")"
    git clone --recursive https://gitlab.futo.org/keyboard/swipe-library.git "$SOURCE"
fi

test "$(git -C "$SOURCE" rev-parse HEAD)" = "$REVISION" || {
    echo "FUTO Swipe checkout is not at pinned revision $REVISION" >&2
    echo "Use a clean dependency directory or check out that revision." >&2
    exit 1
}
git -C "$SOURCE" submodule update --init --recursive

# The upstream build owns its pinned ExecuTorch compatibility patch and the
# torchgen-only Python environment. Reuse both rather than duplicating them.
make -C "$SOURCE" "$SOURCE/.venv/bin/python3" patch-et
"$SOURCE/.venv/bin/cmake" -S "$SOURCE/third_party/executorch" -B "$ET_BUILD" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_SYSTEM_PROCESSOR="$PROCESSOR" \
    -DCMAKE_C_COMPILER="$CC" \
    -DCMAKE_CXX_COMPILER="$CXX" \
    "${TARGET_C_FLAGS[@]}" \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DPYTHON_EXECUTABLE="$SOURCE/.venv/bin/python3" \
    -DEXECUTORCH_BUILD_XNNPACK=ON \
    -DEXECUTORCH_BUILD_EXTENSION_MODULE=ON \
    -DEXECUTORCH_BUILD_EXTENSION_TENSOR=ON \
    -DEXECUTORCH_BUILD_EXTENSION_DATA_LOADER=ON \
    -DEXECUTORCH_BUILD_EXTENSION_FLAT_TENSOR=ON \
    -DEXECUTORCH_BUILD_EXTENSION_NAMED_DATA_MAP=ON \
    -DEXECUTORCH_BUILD_KERNELS_QUANTIZED=OFF \
    -DEXECUTORCH_BUILD_VULKAN=OFF \
    -DEXECUTORCH_BUILD_MPS=OFF \
    -DEXECUTORCH_BUILD_COREML=OFF \
    -DEXECUTORCH_BUILD_QNN=OFF \
    -DEXECUTORCH_BUILD_SDK=OFF \
    -DEXECUTORCH_BUILD_TESTS=OFF \
    -DEXECUTORCH_BUILD_EXAMPLES=OFF \
    -DEXECUTORCH_OPTIMIZE_SIZE=ON \
    -DEXECUTORCH_SELECT_OPS_LIST="$OPS" \
    -DXNNPACK_BUILD_ALL_MICROKERNELS=OFF \
    -DXNNPACK_ENABLE_SPARSE=OFF \
    -DXNNPACK_BUILD_TESTS=OFF \
    -DXNNPACK_BUILD_BENCHMARKS=OFF \
    -DXNNPACK_ENABLE_ARM_SME=OFF \
    -DXNNPACK_ENABLE_ARM_SME2=OFF
"$SOURCE/.venv/bin/cmake" --build "$ET_BUILD" --parallel "$JOBS"

test -s "$ET_BUILD/libexecutorch.a"
test -s "$ET_BUILD/libexecutorch_selected_kernels.a"
printf 'FUTO Swipe dependency ready: %s\n' "$ET_BUILD"
