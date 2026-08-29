#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ARCH=${FUTO_ARCH:-aarch64}
BUILD=${FUTO_BUILD_DIR:-$ROOT/build/$ARCH}
HOST_BUILD=${FUTO_HOST_BUILD_DIR:-$ROOT/build}
CROSS_ROOT=${FUTO_CROSS_ROOT:-}
case "$ARCH" in
    aarch64)
        TOOL_PREFIX=aarch64-linux-gnu
        GO_ARCH=arm64
        GO_EXTRA=()
        VOICE_ARCH_FLAGS=()
        ;;
    armv7hl)
        TOOL_PREFIX=armv7hl-meego-linux-gnueabi
        GO_ARCH=arm
        GO_EXTRA=(GOARM=7)
        VOICE_ARCH_FLAGS=(-mfp16-format=ieee)
        ;;
    i486)
        TOOL_PREFIX=i486-meego-linux-gnu
        GO_ARCH=386
        GO_EXTRA=(GO386=softfloat)
        VOICE_ARCH_FLAGS=()
        ;;
    *)
        echo "Unsupported architecture: $ARCH" >&2
        exit 1
        ;;
esac
if [[ -n "$CROSS_ROOT" ]]; then
    DEFAULT_CXX="$CROSS_ROOT/usr/bin/$TOOL_PREFIX-g++"
    DEFAULT_CC="$CROSS_ROOT/usr/bin/$TOOL_PREFIX-gcc"
    DEFAULT_STRIP="$CROSS_ROOT/usr/bin/$TOOL_PREFIX-strip"
else
    DEFAULT_CXX="$TOOL_PREFIX-g++"
    DEFAULT_CC="$TOOL_PREFIX-gcc"
    DEFAULT_STRIP="$TOOL_PREFIX-strip"
fi
CXX=${FUTO_CXX:-${CXX_AARCH64:-$DEFAULT_CXX}}
CC=${FUTO_CC:-${CC_AARCH64:-$DEFAULT_CC}}
STRIP=${FUTO_STRIP:-${STRIP_AARCH64:-$DEFAULT_STRIP}}
HOST_CXX=${HOST_CXX:-g++}
SHARED_ROOT=${FUTO_SHARED_ROOT:-$ROOT/../shared}
QT_SOURCE=${FUTO_QT_SOURCE:-$SHARED_ROOT/qtbase-5.6.3}
QT_INCLUDE_ROOT=${FUTO_QT_INCLUDE_ROOT:-$QT_SOURCE/include}
SECRETS_SOURCE=${FUTO_SECRETS_SOURCE:-$SHARED_ROOT/sailfish-secrets-upstream}
TARGET_LIB_ROOT=${FUTO_TARGET_LIB_ROOT:-${FUTO_PHONE_LIB_ROOT:-$SHARED_ROOT/futo-phone-sysroot}}
TARGET_SYSROOT=${FUTO_TARGET_SYSROOT:-}
TARGET_COMPILE_FLAGS=()
if [[ -n "$TARGET_SYSROOT" ]]; then
    TARGET_COMPILE_FLAGS=(--sysroot="$TARGET_SYSROOT")
fi

mkdir -p "$BUILD" "$HOST_BUILD/dictionaries"

if [[ "$CXX" != */* ]]; then
    CXX=$(command -v "$CXX" || true)
fi
if [[ "$CC" != */* ]]; then
    CC=$(command -v "$CC" || true)
fi
if [[ "$STRIP" != */* ]]; then
    STRIP=$(command -v "$STRIP" || true)
fi
if [[ -z "$CXX" || ! -x "$CXX" ]]; then
    echo "Missing $ARCH compiler: $CXX" >&2
    exit 1
fi
if [[ -z "$CC" || ! -x "$CC" ]]; then
    echo "Missing $ARCH C compiler: $CC" >&2
    exit 1
fi
if [[ -z "$STRIP" || ! -x "$STRIP" ]]; then
    echo "Missing $ARCH strip tool: $STRIP" >&2
    exit 1
fi

LANGUAGES=(
    en_US en_GB nl tr de fr es it pt_BR pt_PT sv nb da fi pl cs ro sl hr lv lt
    el ru sr sr_Latn hu
)

if [[ ${FUTO_SKIP_DICTIONARY_BUILD:-0} != 1 ]]; then
    rm -rf "$HOST_BUILD/dictionaries"
    mkdir -p "$HOST_BUILD/dictionaries"
    "$HOST_CXX" -std=c++17 -O2 -DNDEBUG \
        -I"$ROOT/upstream/native" \
        "$ROOT/engine/futo_engine.cpp" \
        "$ROOT/upstream/native/utils/char_utils.cpp" \
        -o "$HOST_BUILD/futo-dictionary-compiler"

    for language in "${LANGUAGES[@]}"; do
        source_file="$HOST_BUILD/dictionaries/${language}.combined.tmp"
        if [[ "$language" == sr_Latn ]]; then
            node "$ROOT/scripts/generate-serbian-latin-dictionary.js" \
                "$ROOT/upstream/dictionaries/sr_wordlist.combined.gz" \
                "$source_file"
        elif [[ -s "$ROOT/dictionaries/${language}_wordlist.combined.gz" ]]; then
            # Word lists maintained in this repository for languages the
            # pinned upstream revision does not cover (see dictionaries/).
            gzip -dc "$ROOT/dictionaries/${language}_wordlist.combined.gz" > "$source_file"
        else
            gzip -dc "$ROOT/upstream/dictionaries/${language}_wordlist.combined.gz" > "$source_file"
        fi
        "$HOST_BUILD/futo-dictionary-compiler" --compile "$source_file" \
            "$HOST_BUILD/dictionaries/${language}.fksidx"
        rm -f "$source_file"
    done
else
    for language in "${LANGUAGES[@]}"; do
        test -s "$HOST_BUILD/dictionaries/${language}.fksidx" || {
            echo "Missing prebuilt dictionary: $language" >&2
            exit 1
        }
    done
fi

if [[ ${FUTO_SKIP_CORE_BUILD:-0} != 1 ]]; then
"$CXX" "${TARGET_COMPILE_FLAGS[@]}" -std=c++17 -O2 -DNDEBUG \
    -I"$ROOT/upstream/native" \
    "$ROOT/engine/futo_engine.cpp" \
    "$ROOT/upstream/native/utils/char_utils.cpp" \
    -o "$BUILD/futo-keyboard-engine"
"$STRIP" "$BUILD/futo-keyboard-engine"

"$CC" "${TARGET_COMPILE_FLAGS[@]}" -std=c11 -O2 -DNDEBUG -fPIC -shared \
    -Wl,-soname,libfuto-maliit-policy.so.1 \
    "$ROOT/hardware/futo_maliit_policy.c" -ldl \
    -o "$BUILD/libfuto-maliit-policy.so.1"
"$STRIP" "$BUILD/libfuto-maliit-policy.so.1"

if [[ -n ${FUTO_HOST_MOC:-} ]]; then
    COMPOSE_MOC=$FUTO_HOST_MOC
else
    COMPOSE_MOC=$HOST_BUILD/qt-compose-host/root55/usr/lib/x86_64-linux-gnu/qt5/bin/moc
    if [[ ! -x "$COMPOSE_MOC" ]]; then
        "$ROOT/scripts/bootstrap-compose-moc.sh"
    fi
fi
FUTO_BUILD_DIR="$BUILD" FUTO_TARGET_LIB_ROOT="$TARGET_LIB_ROOT" \
    FUTO_HOST_MOC="$COMPOSE_MOC" "$ROOT/scripts/build-compose-plugin.sh"
FUTO_BUILD_DIR="$BUILD" FUTO_TARGET_LIB_ROOT="$TARGET_LIB_ROOT" \
    "$ROOT/scripts/build-wayland-deadkey-hook.sh"
else
    for required in futo-keyboard-engine libfuto-maliit-policy.so.1 \
            libcomposeplatforminputcontextplugin.so \
            libafutomaliitcomposewrapper.so libQt5WaylandClient.so.5.6.3 \
            libQt5WaylandClientFutoOriginal.so.5.6.3 stock-wayland.sha256; do
        test -s "$BUILD/$required" || {
            echo "Missing prebuilt $ARCH core component: $required" >&2
            exit 1
        }
    done
fi

if [[ ${FUTO_SKIP_VOICE_BUILD:-0} != 1 ]]; then
VOICE_BUILD="$BUILD/voice"
VOICE_SOURCE="$ROOT/voice/whisper"
rm -rf "$VOICE_BUILD"
mkdir -p "$VOICE_BUILD"
for source in ggml.c ggml-alloc.c ggml-backend.c ggml-quants.c; do
    # GCC 13's aarch64 cunroll pass intermittently crashes while compiling
    # ggml.c at -O3. Keep the remaining O3 optimisations, but disable the
    # specific loop transformations responsible for the compiler ICE.
    GGML_OPT_FLAGS=(-O3)
    if [[ "$source" == ggml.c ]]; then
        GGML_OPT_FLAGS+=(-fno-unroll-loops -fno-peel-loops -fno-loop-unroll-and-jam)
    fi
    "$CC" "${TARGET_COMPILE_FLAGS[@]}" -std=c11 "${GGML_OPT_FLAGS[@]}" "${VOICE_ARCH_FLAGS[@]}" \
        -DNDEBUG -D_GNU_SOURCE -pthread \
        -I"$VOICE_SOURCE" -c "$VOICE_SOURCE/$source" \
        -o "$VOICE_BUILD/${source%.c}.o"
done
"$CXX" "${TARGET_COMPILE_FLAGS[@]}" -std=c++17 -O3 "${VOICE_ARCH_FLAGS[@]}" -DNDEBUG -pthread \
    -I"$VOICE_SOURCE" -c "$VOICE_SOURCE/whisper.cpp" \
    -o "$VOICE_BUILD/whisper.o"
"$CXX" "${TARGET_COMPILE_FLAGS[@]}" -std=c++17 -O3 "${VOICE_ARCH_FLAGS[@]}" -DNDEBUG -pthread \
    -I"$VOICE_SOURCE" -c "$ROOT/voice/futo_voice.cpp" \
    -o "$VOICE_BUILD/futo_voice.o"
"$CXX" "${TARGET_COMPILE_FLAGS[@]}" -pthread "$VOICE_BUILD"/*.o -lm -o "$BUILD/futo-keyboard-voice"
"$STRIP" "$BUILD/futo-keyboard-voice"
else
    test -x "$BUILD/futo-keyboard-voice" || {
        echo "Missing prebuilt $ARCH voice worker" >&2
        exit 1
    }
fi

if [[ ${FUTO_SKIP_GO_BUILD:-0} != 1 ]]; then
    (
        cd "$ROOT/helper"
        env CGO_ENABLED=0 GOOS=linux GOARCH="$GO_ARCH" "${GO_EXTRA[@]}" \
            go build -trimpath -ldflags='-s -w' \
            -o "$BUILD/futo-keyboard-helper" ./cmd/futo-keyboard-helper
    )
else
    test -x "$BUILD/futo-keyboard-helper" || {
        echo "Missing prebuilt $ARCH Go helper: $BUILD/futo-keyboard-helper" >&2
        exit 1
    }
fi

for required in \
    "$QT_INCLUDE_ROOT/QtCore/QCoreApplication" \
    "$QT_INCLUDE_ROOT/QtDBus/QDBusConnection" \
    "$SECRETS_SOURCE/lib/Secrets/secretmanager.h" \
    "$TARGET_LIB_ROOT/libQt5Core.so.5.6.3" \
    "$TARGET_LIB_ROOT/libQt5DBus.so.5.6.3" \
    "$TARGET_LIB_ROOT/libsailfishsecrets.so.0.2.44"; do
    test -s "$required" || { echo "Missing Sailfish Secrets build input: $required" >&2; exit 1; }
done

"$CXX" "${TARGET_COMPILE_FLAGS[@]}" -std=c++17 -O2 -DNDEBUG -fPIC \
    -I"$QT_INCLUDE_ROOT" \
    -I"$QT_INCLUDE_ROOT/QtCore" \
    -I"$QT_INCLUDE_ROOT/QtDBus" \
    -I"$SECRETS_SOURCE/lib" \
    "$ROOT/vault/futo-keyboard-secrets.cpp" \
    -L"$TARGET_LIB_ROOT" -Wl,--allow-shlib-undefined \
    -l:libsailfishsecrets.so.0.2.44 \
    -l:libQt5DBus.so.5.6.3 \
    -l:libQt5Core.so.5.6.3 \
    -lpthread -ldl \
    -o "$BUILD/futo-keyboard-secrets"
"$STRIP" "$BUILD/futo-keyboard-secrets"

"$CC" "${TARGET_COMPILE_FLAGS[@]}" -std=c11 -O2 -DNDEBUG -fPIE -pie \
    -Wall -Wextra -Werror \
    "$ROOT/vault/futo-keyboard-keyring.c" \
    -o "$BUILD/futo-keyboard-keyring"
"$STRIP" "$BUILD/futo-keyboard-keyring"

"$CC" "${TARGET_COMPILE_FLAGS[@]}" -std=c11 -O2 -DNDEBUG -fPIE -pie \
    -Wall -Wextra -Werror \
    "$ROOT/vault/futo-keyboard-focus.c" \
    -o "$BUILD/futo-keyboard-focus"
"$STRIP" "$BUILD/futo-keyboard-focus"

"$CC" "${TARGET_COMPILE_FLAGS[@]}" -std=c11 -O2 -DNDEBUG -fPIE -pie \
    -Wall -Wextra -Werror \
    "$ROOT/vault/futo-keyboard-appsupport.c" \
    -o "$BUILD/futo-keyboard-appsupport"
"$STRIP" "$BUILD/futo-keyboard-appsupport"

file "$BUILD/futo-keyboard-engine" "$BUILD/futo-keyboard-helper" \
    "$BUILD/futo-keyboard-secrets" "$BUILD/futo-keyboard-keyring" \
    "$BUILD/futo-keyboard-focus" "$BUILD/futo-keyboard-appsupport" \
    "$BUILD/futo-keyboard-voice" \
    "$BUILD/libfuto-maliit-policy.so.1" \
    "$BUILD/libcomposeplatforminputcontextplugin.so" \
    "$BUILD/libafutomaliitcomposewrapper.so" \
    "$BUILD/libQt5WaylandClient.so.5.6.3" \
    "$BUILD/libQt5WaylandClientFutoOriginal.so.5.6.3"
echo "Build complete: $BUILD"
