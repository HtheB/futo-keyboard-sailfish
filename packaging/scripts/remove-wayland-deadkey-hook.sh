#!/bin/sh
set -eu

libdir=@FUTO_LIBDIR@
system_library=$libdir/libQt5WaylandClient.so.5.6.3
stock_backup=$libdir/libQt5WaylandClient.so.5.6.3.futo-stock
original_library=$libdir/libQt5WaylandClientFutoOriginal.so.5.6.3
payload_hook=/usr/share/futo-keyboard-sailfish/hardware/libQt5WaylandClient.so.5.6.3
expected_stock_sha256=$(sed -n '1p' /usr/share/futo-keyboard-sailfish/hardware/stock-wayland.sha256)

if [ -s "$stock_backup" ]; then
    backup_sha256=$(sha256sum "$stock_backup" | cut -d' ' -f1)
    if [ "$backup_sha256" != "$expected_stock_sha256" ]; then
        echo "Not restoring an unexpected QtWayland stock backup: $backup_sha256" >&2
        exit 1
    fi
    if [ -s "$system_library" ] && [ -s "$payload_hook" ] && \
            ! cmp -s "$system_library" "$payload_hook"; then
        current_sha256=$(sha256sum "$system_library" | cut -d' ' -f1)
        if [ "$current_sha256" != "$expected_stock_sha256" ]; then
            echo "QtWayland was changed by another component; leaving it untouched" >&2
            exit 1
        fi
    fi
    install -m 0755 "$stock_backup" "$system_library.new"
    mv -f "$system_library.new" "$system_library"
    rm -f "$stock_backup"
fi
rm -f "$libdir/libQt5WaylandClientFutoOriginal.so.5" \
    "$original_library"
/sbin/ldconfig >/dev/null 2>&1 || :
