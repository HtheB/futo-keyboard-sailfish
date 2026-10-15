#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DEPS_ROOT=${FUTO_DEPS_ROOT:-$ROOT/build/dependencies}
SOURCE_ROOT=${FUTO_COMPOSITION_SOURCE_ROOT:-$DEPS_ROOT/sources}

checkout() {
    local name=$1 url=$2 revision=$3
    local destination="$SOURCE_ROOT/$name"
    if [[ ! -d "$destination/.git" ]]; then
        mkdir -p "$SOURCE_ROOT"
        git clone --filter=blob:none --no-checkout "$url" "$destination"
        git -C "$destination" fetch --depth 1 origin "$revision"
        git -C "$destination" checkout --detach "$revision"
    fi
    if [[ $(git -C "$destination" rev-parse HEAD) != "$revision" ]]; then
        echo "Wrong pinned composition dependency: $name" >&2
        exit 1
    fi
}

checkout futo-mozc-lib https://gitlab.futo.org/keyboard/mozc-lib.git \
    872ec0754f0ea0aa547f186364931c70870f6873
checkout futo-mozc https://github.com/google/mozc.git \
    22ccfeb9fe04ea2b72da0d455e5a5423b0e8554a
checkout futo-rime-jni https://gitlab.futo.org/keyboard/RimeJni.git \
    db6a753fd1318a11e216aa4c1fd95385e26cbd08
checkout futo-rime-predict https://github.com/rime/librime-predict.git \
    920bd41ebf6f9bf6855d14fbe80212e54e749791

echo "Pinned Japanese and Chinese conversion sources are ready"
