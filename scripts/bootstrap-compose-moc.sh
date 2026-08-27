#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOST_ROOT="$ROOT/build/qt-compose-host"
DEB="$HOST_ROOT/qtbase5-dev-tools_5.5.1+dfsg-16ubuntu7.7_amd64.deb"
EXTRACTED="$HOST_ROOT/root55"
MOC="$EXTRACTED/usr/lib/x86_64-linux-gnu/qt5/bin/moc"
URL=https://security.ubuntu.com/ubuntu/pool/main/q/qtbase-opensource-src/qtbase5-dev-tools_5.5.1+dfsg-16ubuntu7.7_amd64.deb
SHA256=03fac2070cf27c12776d92552bbae3a082dfea772509ee5ff9b5d97322af75ff

if [[ -x "$MOC" ]]; then
    exit 0
fi

mkdir -p "$HOST_ROOT"
if [[ ! -s "$DEB" ]]; then
    curl --fail --location --output "$DEB" "$URL"
fi
echo "$SHA256  $DEB" | sha256sum --check --status
rm -rf "$EXTRACTED"
mkdir -p "$EXTRACTED"
dpkg-deb --extract "$DEB" "$EXTRACTED"
"$MOC" -v
