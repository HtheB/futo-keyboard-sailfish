#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ARCH=${FUTO_ARCH:-aarch64}
VERSION=0.7.0
RELEASE=1
NAME=futo-keyboard-sailfish
OUTPUT_DIR=${FUTO_RPM_OUTPUT_DIR:-$ROOT/build/rpm}
BINARY_DIR=${FUTO_BINARY_DIR:-$ROOT/build/$ARCH}
TOPDIR=$(mktemp -d)
STAGING=$(mktemp -d)
cleanup() {
    rm -rf "$TOPDIR" "$STAGING"
}
trap cleanup EXIT

if [[ ${FUTO_SKIP_BUILD:-0} != 1 ]]; then
    "$ROOT/scripts/build.sh"
fi
if [[ ${FUTO_SKIP_CONTENT_BUILD:-0} != 1 ]]; then
    "$ROOT/scripts/build-content-packs.sh"
fi

mkdir -p "$TOPDIR"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
mkdir -p "$STAGING/$NAME-$VERSION"
# Package only repository files; ignored or local-only files never enter the
# published source payload, even if they sit beside the checked-in sources.
git -C "$ROOT" ls-files -z \
    | grep -z -Ev '^(build/|reference/|emoji/|upstream/dictionaries/|voice/models/|swipe/models/|PAUSED-CHECKPOINT\.md$)' \
    | tar -C "$ROOT" --null -T - -cf - \
    | tar -C "$STAGING/$NAME-$VERSION" -xf -
mkdir -p "$STAGING/$NAME-$VERSION/build/$ARCH"
for file in \
    futo-keyboard-engine futo-keyboard-swipe futo-keyboard-prediction futo-keyboard-helper futo-keyboard-secrets \
    futo-keyboard-keyring futo-keyboard-focus futo-keyboard-appsupport futo-keyboard-voice \
    libfuto-maliit-policy.so.1 libcomposeplatforminputcontextplugin.so \
    libafutomaliitcomposewrapper.so libQt5WaylandClient.so.5.6.3 \
    libQt5WaylandClientFutoOriginal.so.5.6.3 stock-wayland.sha256; do
    cp "$BINARY_DIR/$file" "$STAGING/$NAME-$VERSION/build/$ARCH/$file"
done
# Some prebuilt dependency objects retain their original build roots in error
# strings. Rewrite only staged copies, preserving every binary's byte offsets,
# and reject the package if any host path remains.
python3 "$ROOT/scripts/sanitize-build-paths.py" \
    "$STAGING/$NAME-$VERSION/build/$ARCH"/*

cp "$ROOT/emoji/manifest.json" "$STAGING/$NAME-$VERSION/emoji-manifest.json"
mkdir -p "$STAGING/$NAME-$VERSION/emoji"
mv "$STAGING/$NAME-$VERSION/emoji-manifest.json" \
    "$STAGING/$NAME-$VERSION/emoji/manifest.json"
for style in twemoji openmoji noto; do
    mkdir -p "$STAGING/$NAME-$VERSION/emoji/$style"
    for codepoint in 1f600 1f44d 1f389 2764; do
        case "$style" in
            noto) extension=png ;;
            *) extension=svg ;;
        esac
        cp "$ROOT/emoji/$style/$codepoint.$extension" \
            "$STAGING/$NAME-$VERSION/emoji/$style/$codepoint.$extension"
    done
done
for codepoint in 1f550 1f600 1f44b 1f43b 1f354 1f697 26bd 1f4a1 2764 1f3f3; do
    cp "$ROOT/emoji/noto/$codepoint.png" \
        "$STAGING/$NAME-$VERSION/emoji/noto/$codepoint.png"
done
find "$STAGING/$NAME-$VERSION" -type d -exec chmod 0755 {} +
find "$STAGING/$NAME-$VERSION" -type f -exec chmod 0644 {} +
chmod 0755 "$STAGING/$NAME-$VERSION/scripts/"*.sh \
	"$STAGING/$NAME-$VERSION/packaging/scripts/"*.sh \
    "$STAGING/$NAME-$VERSION/build/$ARCH/futo-keyboard-engine" \
    "$STAGING/$NAME-$VERSION/build/$ARCH/futo-keyboard-swipe" \
    "$STAGING/$NAME-$VERSION/build/$ARCH/futo-keyboard-prediction" \
    "$STAGING/$NAME-$VERSION/build/$ARCH/futo-keyboard-helper" \
    "$STAGING/$NAME-$VERSION/build/$ARCH/futo-keyboard-secrets" \
    "$STAGING/$NAME-$VERSION/build/$ARCH/futo-keyboard-keyring" \
    "$STAGING/$NAME-$VERSION/build/$ARCH/futo-keyboard-focus" \
    "$STAGING/$NAME-$VERSION/build/$ARCH/futo-keyboard-appsupport" \
    "$STAGING/$NAME-$VERSION/build/$ARCH/futo-keyboard-voice" \
    "$STAGING/$NAME-$VERSION/build/$ARCH/libfuto-maliit-policy.so.1" \
    "$STAGING/$NAME-$VERSION/build/$ARCH/libcomposeplatforminputcontextplugin.so" \
    "$STAGING/$NAME-$VERSION/build/$ARCH/libafutomaliitcomposewrapper.so" \
	"$STAGING/$NAME-$VERSION/build/$ARCH/libQt5WaylandClient.so.5.6.3" \
	"$STAGING/$NAME-$VERSION/build/$ARCH/libQt5WaylandClientFutoOriginal.so.5.6.3"

tar -C "$STAGING" -czf "$TOPDIR/SOURCES/$NAME-$VERSION.tar.gz" "$NAME-$VERSION"
cp "$ROOT/packaging/rpm/$NAME.spec" "$TOPDIR/SPECS/"
rpmbuild --target "$ARCH" --nodeps --define "_topdir $TOPDIR" \
    --define "_buildhost release-builder" -bb "$TOPDIR/SPECS/$NAME.spec"

mkdir -p "$OUTPUT_DIR"
OUTPUT_RPM="$OUTPUT_DIR/$NAME-$VERSION-$RELEASE.$ARCH.rpm"
OUTPUT_SOURCE="$OUTPUT_DIR/$NAME-$VERSION-$ARCH-source.tar.gz"
if [[ -e "$OUTPUT_RPM" || -e "$OUTPUT_SOURCE" ]]; then
    echo "Release output already exists; refusing to overwrite it: $OUTPUT_DIR" >&2
    exit 1
fi
cp "$TOPDIR/RPMS/$ARCH/$NAME-$VERSION-$RELEASE.$ARCH.rpm" "$OUTPUT_RPM"
cp "$TOPDIR/SOURCES/$NAME-$VERSION.tar.gz" "$OUTPUT_SOURCE"
rpm -qplv "$OUTPUT_RPM"
sha256sum "$OUTPUT_RPM" "$OUTPUT_SOURCE"
