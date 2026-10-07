#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=0.7.0
NAME=futo-keyboard-sailfish
OUTPUT_DIR=${FUTO_RPM_OUTPUT_DIR:-$ROOT/build/rpm}
STAGING=$(mktemp -d)
cleanup() {
    rm -rf "$STAGING"
}
trap cleanup EXIT

mkdir -p "$STAGING/$NAME-$VERSION"
git -C "$ROOT" ls-files -z \
    | grep -z -Ev '^(build/|reference/|swipe/models/|PAUSED-CHECKPOINT\.md$)' \
    | tar -C "$ROOT" --null -T - -cf - \
    | tar -C "$STAGING/$NAME-$VERSION" -xf -
find "$STAGING/$NAME-$VERSION" -type d -exec chmod 0755 {} +
find "$STAGING/$NAME-$VERSION" -type f -exec chmod 0644 {} +
chmod 0755 "$STAGING/$NAME-$VERSION/scripts/"*.sh \
    "$STAGING/$NAME-$VERSION/packaging/scripts/"*.sh

mkdir -p "$OUTPUT_DIR"
OUTPUT_SOURCE="$OUTPUT_DIR/$NAME-$VERSION-source.tar.gz"
if [[ -e "$OUTPUT_SOURCE" ]]; then
    echo "Release source archive already exists: $OUTPUT_SOURCE" >&2
    exit 1
fi
tar -C "$STAGING" -czf "$OUTPUT_SOURCE" \
    "$NAME-$VERSION"
sha256sum "$OUTPUT_SOURCE"
