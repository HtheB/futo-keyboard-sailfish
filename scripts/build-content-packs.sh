#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUTPUT=${FUTO_CONTENT_OUTPUT:-"$ROOT/build/content-packs"}
PACK_VERSION=0.1.0-1

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

for style in twemoji openmoji noto; do
    archive_directory \
        "futo-content-emoji-$style-$PACK_VERSION.tar.gz" \
        "emoji/$style"
done

archive_file "futo-content-voice-multilingual-39-$PACK_VERSION.tar.gz" \
    "voice/models/tiny_acft_q8_0.bin" "voice/tiny_acft_q8_0.bin"

for file in "$ROOT"/build/dictionaries/*.fksidx; do
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
