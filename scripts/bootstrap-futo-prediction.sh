#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEPS_ROOT=${FUTO_DEPS_ROOT:-$ROOT/build/dependencies}
SOURCE=${FUTO_PREDICTION_SOURCE:-$DEPS_ROOT/sources/android-keyboard}
REVISION=eaf0389f962b0dba07778d0feab6511e6e98c581

if [[ ! -d "$SOURCE/.git" ]]; then
    mkdir -p "$(dirname "$SOURCE")"
    git clone --filter=blob:none --no-checkout \
        https://github.com/futo-org/android-keyboard.git "$SOURCE"
    git -C "$SOURCE" fetch --depth 1 origin "$REVISION"
    git -C "$SOURCE" checkout --detach "$REVISION"
fi

CURRENT=$(git -C "$SOURCE" rev-parse HEAD)
if [[ "$CURRENT" != "$REVISION" ]]; then
    echo "FUTO Android Keyboard checkout is not at pinned revision $REVISION" >&2
    echo "Use a clean dependency directory or check out that revision." >&2
    exit 1
fi

for required in \
    native/jni/org_futo_inputmethod_latin_xlm_LanguageModel.cpp \
    native/jni/src/ggml/LanguageModel.cpp \
    native/jni/src/ggml/llama.cpp \
    native/jni/src/sentencepiece/sentencepiece_processor.cc; do
    test -s "$SOURCE/$required" || {
        echo "Pinned FUTO KeyboardLM source is incomplete: $required" >&2
        exit 1
    }
done

printf 'FUTO KeyboardLM source ready: %s\n' "$SOURCE"
