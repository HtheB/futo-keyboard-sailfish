#!/bin/sh
set -eu

libdir=@FUTO_LIBDIR@
system_library=$libdir/libQt5WaylandClient.so.5.6.3
stock_backup=$libdir/libQt5WaylandClient.so.5.6.3.futo-stock
original_library=$libdir/libQt5WaylandClientFutoOriginal.so.5.6.3
payload=/usr/share/futo-keyboard-sailfish/hardware
expected_stock_sha256=$(sed -n '1p' "$payload/stock-wayland.sha256")

test -s "$payload/libQt5WaylandClient.so.5.6.3"
test -s "$payload/libQt5WaylandClientFutoOriginal.so.5.6.3"
test -s "$system_library"

if [ ! -s "$stock_backup" ]; then
    current_sha256=$(sha256sum "$system_library" | cut -d' ' -f1)
    if [ "$current_sha256" != "$expected_stock_sha256" ]; then
        echo "Refusing to patch an unsupported QtWayland client: $current_sha256" >&2
        exit 1
    fi
    cp -p "$system_library" "$stock_backup"
fi

backup_sha256=$(sha256sum "$stock_backup" | cut -d' ' -f1)
if [ "$backup_sha256" != "$expected_stock_sha256" ]; then
    echo "Refusing to use an unexpected QtWayland stock backup: $backup_sha256" >&2
    exit 1
fi

install -m 0755 "$payload/libQt5WaylandClientFutoOriginal.so.5.6.3" \
    "$original_library.new"
mv -f "$original_library.new" "$original_library"
ln -sfn libQt5WaylandClientFutoOriginal.so.5.6.3 \
    "$libdir/libQt5WaylandClientFutoOriginal.so.5"

install -m 0755 "$payload/libQt5WaylandClient.so.5.6.3" \
    "$system_library.new"
mv -f "$system_library.new" "$system_library"
/sbin/ldconfig >/dev/null 2>&1 || :
