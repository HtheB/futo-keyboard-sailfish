#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ARCH=${FUTO_ARCH:-aarch64}
SOURCE_ARCHIVE=${1:?Usage: package-source-archive.sh /path/to/source.tar.gz}
NAME=futo-keyboard-sailfish
VERSION=0.1.0
RELEASE=1
TOPDIR=$(mktemp -d)
NORMALIZED=$(mktemp -d)

cleanup() {
    rm -rf "$TOPDIR" "$NORMALIZED"
}
trap cleanup EXIT

test -s "$SOURCE_ARCHIVE"
mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
tar -C "$NORMALIZED" -xzf "$SOURCE_ARCHIVE"
if [[ -d "$NORMALIZED/$NAME" && ! -d "$NORMALIZED/$NAME-$VERSION" ]]; then
    mv "$NORMALIZED/$NAME" "$NORMALIZED/$NAME-$VERSION"
fi
test -d "$NORMALIZED/$NAME-$VERSION"
tar -C "$NORMALIZED" -czf "$TOPDIR/SOURCES/$NAME-$VERSION.tar.gz" \
    "$NAME-$VERSION"
cp "$ROOT/packaging/rpm/$NAME.spec" "$TOPDIR/SPECS/"
rpmbuild --target "$ARCH" --nodeps --define "_topdir $TOPDIR" \
    -bb "$TOPDIR/SPECS/$NAME.spec"

mkdir -p "$ROOT/build/rpm"
cp "$TOPDIR/RPMS/$ARCH/$NAME-$VERSION-$RELEASE.$ARCH.rpm" \
    "$ROOT/build/rpm/"
cp "$TOPDIR/SOURCES/$NAME-$VERSION.tar.gz" \
    "$ROOT/build/rpm/$NAME-$VERSION-source.tar.gz"
rpm -qplv "$ROOT/build/rpm/$NAME-$VERSION-$RELEASE.$ARCH.rpm" \
    > "$ROOT/build/rpm/$NAME-$VERSION-$RELEASE.$ARCH.filelist.txt"
sha256sum "$ROOT/build/rpm/$NAME-$VERSION-$RELEASE.$ARCH.rpm" \
    "$ROOT/build/rpm/$NAME-$VERSION-source.tar.gz"
