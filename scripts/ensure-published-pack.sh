#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUTPUT=${1:?content output directory required}
ID=${2:?published content id required}
REQUESTED_ARCHIVE=${3:-}
TEMPORARY=$(mktemp -d)
trap 'rm -rf -- "$TEMPORARY"' EXIT

node - "$ROOT/content/published-packs.json" "$ID" <<'NODE' > "$TEMPORARY/item.tsv"
const fs = require("fs");
const item = JSON.parse(fs.readFileSync(process.argv[2], "utf8"))[process.argv[3]];
if (!item || !/^futo-content-[a-z0-9.-]+\.tar\.gz$/.test(item.archive)
        || !/^https:\/\/github\.com\/HtheB\/futo-keyboard-sailfish\/releases\/download\//.test(item.url)
        || !/^[a-f0-9]{64}$/.test(item.sha256)
        || !Number.isSafeInteger(item.downloadBytes) || item.downloadBytes <= 0)
    throw new Error("invalid published pack pin");
process.stdout.write([item.archive, item.url, item.sha256, item.downloadBytes].join("\t") + "\n");
NODE
IFS=$'\t' read -r archive url expected_hash expected_size < "$TEMPORARY/item.tsv"
if [ -n "$REQUESTED_ARCHIVE" ] && [ "$REQUESTED_ARCHIVE" != "$archive" ]; then
    # A new filename is new content, not the pinned published artifact.
    exit 0
fi

verified() {
    test -s "$1" && test "$(stat -c %s "$1")" = "$expected_size" \
        && test "$(sha256sum "$1" | cut -d' ' -f1)" = "$expected_hash"
}

if verified "$OUTPUT/$archive"; then
    exit 0
fi
# Preserve the exact published artifact, not a reconstruction. Cached packs
# also allow subsequent builds without network access.
CACHE="$ROOT/build/published-content"
mkdir -p "$CACHE" "$OUTPUT"
if ! verified "$CACHE/$archive"; then
    curl --fail --location --retry 2 --connect-timeout 15 --max-time 120 \
        "$url" -o "$TEMPORARY/archive"
    verified "$TEMPORARY/archive" || {
        echo "Published pack failed size or checksum verification: $archive" >&2
        exit 1
    }
    mv "$TEMPORARY/archive" "$CACHE/$archive"
fi
cp "$CACHE/$archive" "$OUTPUT/$archive"
printf 'Using verified published content: %s\n' "$archive"
