#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUTPUT=${FUTO_CONTENT_OUTPUT:-"$ROOT/build/content-packs"}
PACK_VERSION=0.2.0-1

mkdir -p "$OUTPUT" "$ROOT/content"
find "$OUTPUT" -maxdepth 1 -type f \
    \( -name 'futo-content-*.tar.gz' -o -name 'manifest.json' -o -name 'SHA256SUMS' \) \
    -delete

archive_directory() {
    local archive=$1
    local relative=$2
    tar --sort=name --mtime='UTC 2026-08-26' --owner=0 --group=0 \
        --numeric-owner -C "$ROOT" -cf - "$relative" \
        | gzip -9 -n > "$OUTPUT/$archive"
}

archive_file() {
    local archive=$1
    local source=$2
    local installed=$3
    tar --sort=name --mtime='UTC 2026-08-26' --owner=0 --group=0 \
        --numeric-owner --transform="s#^$source\$#$installed#" \
        -C "$ROOT" -cf - "$source" | gzip -9 -n > "$OUTPUT/$archive"
}

archive_directory_as() {
    local archive=$1
    local source=$2
    local installed=$3
    tar --sort=name --mtime='UTC 2026-08-26' --owner=0 --group=0 \
        --numeric-owner --transform="s#^$source#$installed#" \
        -C "$ROOT" -cf - "$source" | gzip -9 -n > "$OUTPUT/$archive"
}

for style in twemoji openmoji noto; do
    archive_directory \
        "futo-content-emoji-$style-$PACK_VERSION.tar.gz" \
        "emoji/$style"
done

archive_file "futo-content-voice-multilingual-39-$PACK_VERSION.tar.gz" \
    "voice/models/tiny_acft_q8_0.bin" "voice/tiny_acft_q8_0.bin"

test -s "$ROOT/swipe/models/honorable_sturgeon/model_fp32.pte" \
    -a -s "$ROOT/swipe/models/magic_macaw/model_fp32.pte" \
    -a -s "$ROOT/swipe/models/hungry_jellyfish/context_lm.pte" \
    -a -s "$ROOT/swipe/models/hungry_jellyfish/vocab.txt" || \
        "$ROOT/scripts/fetch-swipe-model.sh"
cp "$ROOT/LICENSES/FUTO-SWIPE-MODEL-WEIGHTS-LICENSE.md" \
    "$ROOT/swipe/models/LICENSE.md"
archive_directory_as "futo-content-swipe-universal-$PACK_VERSION.tar.gz" \
    "swipe/models" "swipe/models"

dictionary_files=(
    ar cs da de el en_GB en_US es fa fi fr hr hu it lt lv nb nl pl
    pt_BR pt_PT ro ru sl sr sr_Latn sv tr
)
for dictionary in "${dictionary_files[@]}"; do
    file="$ROOT/build/dictionaries/$dictionary.fksidx"
    test -s "$file" || {
        printf 'Missing supported dictionary: %s\n' "$file" >&2
        exit 1
    }
    name=$(basename "$file" .fksidx | tr '[:upper:]_' '[:lower:]-')
    archive_file "futo-content-dictionary-$name-$PACK_VERSION.tar.gz" \
        "build/dictionaries/$(basename "$file")" \
        "dictionaries/$(basename "$file")"
done

node "$ROOT/scripts/generate-content-manifest.js" "$OUTPUT" "$ROOT/content/manifest.json"
cp "$ROOT/content/manifest.json" "$OUTPUT/manifest.json"
(
    cd "$OUTPUT"
    sha256sum futo-content-*.tar.gz manifest.json > SHA256SUMS
)
bash "$ROOT/scripts/check-content-packs.sh" "$OUTPUT" "$ROOT/content/manifest.json"
printf 'Content packs: %s\nManifest: %s\n' "$OUTPUT" "$ROOT/content/manifest.json"
