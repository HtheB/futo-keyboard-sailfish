#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PACK_DIRECTORY=${1:-"$ROOT/build/content-packs"}
MANIFEST=${2:-"$ROOT/content/manifest.json"}
TEMPORARY=$(mktemp -d)
cleanup() {
    rm -rf -- "$TEMPORARY"
}
trap cleanup EXIT

node - "$MANIFEST" <<'NODE' > "$TEMPORARY/items.tsv"
const fs = require("fs")
const manifest = JSON.parse(fs.readFileSync(process.argv[2], "utf8"))
if (manifest.formatVersion !== 1 || !Array.isArray(manifest.items) || !manifest.items.length)
    throw new Error("invalid or empty content manifest")
for (const item of manifest.items) {
    if (!item.id || !item.archive || !item.sha256 || !item.downloadBytes
            || !item.installedBytes || !Array.isArray(item.paths) || item.paths.length !== 1)
        throw new Error(`incomplete content item ${item.id || "<unknown>"}`)
    process.stdout.write([
        item.id, item.archive, item.sha256, item.downloadBytes,
        item.installedBytes, item.paths[0]
    ].join("\t") + "\n")
}
NODE

count=0
while IFS=$'\t' read -r id archive expected_hash expected_download \
        expected_installed declared_path; do
    pack="$PACK_DIRECTORY/$archive"
    test -s "$pack" || { echo "Missing content pack: $archive" >&2; exit 1; }
    actual_hash=$(sha256sum "$pack" | cut -d' ' -f1)
    test "$actual_hash" = "$expected_hash" || {
        echo "Checksum mismatch: $archive" >&2
        exit 1
    }
    actual_download=$(stat -c %s "$pack")
    test "$actual_download" = "$expected_download" || {
        echo "Download-size mismatch: $archive" >&2
        exit 1
    }

    list="$TEMPORARY/$id.list"
    tar -tzf "$pack" > "$list"
    while IFS= read -r entry; do
        trimmed=${entry%/}
        case "$trimmed" in
            "$declared_path"|"$declared_path"/*) ;;
            *) echo "Unexpected archive path in $archive: $entry" >&2; exit 1 ;;
        esac
        case "$trimmed" in
            /*|../*|*/../*) echo "Unsafe archive path in $archive: $entry" >&2; exit 1 ;;
        esac
    done < "$list"

    destination="$TEMPORARY/extract-$id"
    mkdir -p "$destination"
    tar --warning=no-timestamp -xzf "$pack" -C "$destination"
    test -e "$destination/$declared_path" || {
        echo "Declared path missing from $archive" >&2
        exit 1
    }
    test -z "$(find "$destination" -type l -print -quit)" || {
        echo "Symbolic link found in $archive" >&2
        exit 1
    }
    actual_installed=$(find "$destination" -type f -printf '%s\n' \
        | awk '{ total += $1 } END { print total + 0 }')
    test "$actual_installed" = "$expected_installed" || {
        echo "Installed-size mismatch: $archive" >&2
        exit 1
    }
    count=$((count + 1))
done < "$TEMPORARY/items.tsv"

actual_count=$(find "$PACK_DIRECTORY" -maxdepth 1 -type f \
    -name 'futo-content-*.tar.gz' | wc -l)
test "$actual_count" = "$count" || {
    echo "Found $actual_count archives but the manifest contains $count" >&2
    exit 1
}
echo "Verified $count content packs."
