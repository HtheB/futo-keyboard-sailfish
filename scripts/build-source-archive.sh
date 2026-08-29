#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=0.2.1
NAME=futo-keyboard-sailfish
STAGING=$(mktemp -d)
cleanup() {
    rm -rf "$STAGING"
}
trap cleanup EXIT

mkdir -p "$STAGING/$NAME-$VERSION"
tar -C "$ROOT" \
    --exclude='./.git' \
    --exclude='./.gitignore' \
    --exclude='./.mb2' \
    --exclude='./build' \
    --exclude='./reference' \
    --exclude='./PAUSED-CHECKPOINT.md' \
    -cf - . | tar -C "$STAGING/$NAME-$VERSION" -xf -
find "$STAGING/$NAME-$VERSION" -type d -exec chmod 0755 {} +
find "$STAGING/$NAME-$VERSION" -type f -exec chmod 0644 {} +
chmod 0755 "$STAGING/$NAME-$VERSION/scripts/"*.sh \
    "$STAGING/$NAME-$VERSION/packaging/scripts/"*.sh

mkdir -p "$ROOT/build/rpm"
tar -C "$STAGING" -czf "$ROOT/build/rpm/$NAME-$VERSION-source.tar.gz" \
    "$NAME-$VERSION"
sha256sum "$ROOT/build/rpm/$NAME-$VERSION-source.tar.gz"
