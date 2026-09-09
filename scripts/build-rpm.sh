#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ARCH=${FUTO_ARCH:-aarch64}
VERSION=0.4.2
RELEASE=2
NAME=futo-keyboard-sailfish
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
tar -C "$ROOT" \
    --exclude='./.git' \
    --exclude='./.mb2' \
    --exclude='./reference' \
    --exclude='./build/rpm' \
	--exclude='./build' \
	--exclude='./emoji' \
	--exclude='./upstream/dictionaries' \
	--exclude='./voice/models' \
	--exclude='./swipe/models' \
    --exclude='./PAUSED-CHECKPOINT.md' \
    -cf - . | tar -C "$STAGING/$NAME-$VERSION" -xf -
mkdir -p "$STAGING/$NAME-$VERSION/build/$ARCH"
for file in \
    futo-keyboard-engine futo-keyboard-swipe futo-keyboard-helper futo-keyboard-secrets \
    futo-keyboard-keyring futo-keyboard-focus futo-keyboard-appsupport futo-keyboard-voice \
    libfuto-maliit-policy.so.1 libcomposeplatforminputcontextplugin.so \
    libafutomaliitcomposewrapper.so libQt5WaylandClient.so.5.6.3 \
    libQt5WaylandClientFutoOriginal.so.5.6.3 stock-wayland.sha256; do
    cp "$ROOT/build/$ARCH/$file" "$STAGING/$NAME-$VERSION/build/$ARCH/$file"
done
# Components that are not rebuilt here keep the paths they were first built
# with, and those name the machine and account that built them. The engine and
# helper are compiled with -ffile-prefix-map and carry none; the rest are
# scrubbed in place. Refuse to package anything that still says otherwise
# rather than finding out after a release is public.
#
# grep -c rather than grep -q: -q stops reading at the first match, strings
# then dies of SIGPIPE, and under pipefail that failure would mask the match.
FORBIDDEN='chatgpt|/mnt/c/users/[^b]|htheb|claude|codex|openai|anthropic'
for binary in "$STAGING/$NAME-$VERSION/build/$ARCH"/*; do
    test -f "$binary" || continue
    hits=$(strings -a "$binary" 2>/dev/null | grep -ciE "$FORBIDDEN" || true)
    if [ "${hits:-0}" -gt 0 ]; then
        printf 'Build path or account name left in %s\n' "$binary" >&2
        strings -a "$binary" | grep -iE "$FORBIDDEN" | head -3 >&2
        exit 1
    fi
done

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
rpmbuild --target "$ARCH" --nodeps --define "_topdir $TOPDIR" -bb "$TOPDIR/SPECS/$NAME.spec"

mkdir -p "$ROOT/build/rpm"
OUTPUT_RPM="$ROOT/build/rpm/$NAME-$VERSION-$RELEASE.$ARCH.rpm"
cp "$TOPDIR/RPMS/$ARCH/$NAME-$VERSION-$RELEASE.$ARCH.rpm" "$OUTPUT_RPM"
cp "$TOPDIR/SOURCES/$NAME-$VERSION.tar.gz" \
    "$ROOT/build/rpm/$NAME-$VERSION-$ARCH-source.tar.gz"
rpm -qplv "$OUTPUT_RPM"
sha256sum "$OUTPUT_RPM" "$ROOT/build/rpm/$NAME-$VERSION-$ARCH-source.tar.gz"
