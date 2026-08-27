#!/bin/sh
set -eu

dconf write /sailfish/text_input/enabled_layouts \
    "['nl.qml', 'en.qml', 'tr.qml', 'futo.qml']"
dconf write /sailfish/text_input/active_layout "'futo.qml'"
systemctl --user restart maliit-server.service
sleep 2
systemctl --user is-active maliit-server.service
dconf read /sailfish/text_input/enabled_layouts
dconf read /sailfish/text_input/active_layout
