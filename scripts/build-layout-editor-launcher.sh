#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUTPUT=${1:-$ROOT/build/layout-editor-launcher/launcher.rpm}
TOPDIR=$(mktemp -d)
trap 'rm -rf "$TOPDIR"' EXIT
mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
cp "$ROOT/editor/futo-layout-editor-launcher.desktop" "$TOPDIR/SOURCES/"
cp "$ROOT/packaging/rpm/futo-layout-editor-launcher.spec" "$TOPDIR/SPECS/"
rpmbuild --nodeps --define "_topdir $TOPDIR" --define '_buildhost release-builder' \
    -bb "$TOPDIR/SPECS/futo-layout-editor-launcher.spec"
mkdir -p "$(dirname "$OUTPUT")"
cp "$TOPDIR/RPMS/noarch/futo-layout-editor-launcher-0.9.6-1.noarch.rpm" "$OUTPUT"
test "$(rpm -qpl "$OUTPUT")" = /usr/share/applications/futo-layout-editor-launcher.desktop
