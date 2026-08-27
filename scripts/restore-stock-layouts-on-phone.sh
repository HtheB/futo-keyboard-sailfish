#!/bin/sh
set -eu

dconf write /sailfish/text_input/enabled_layouts "['nl.qml', 'en.qml', 'tr.qml']"
dconf write /sailfish/text_input/active_layout "'nl.qml'"
systemctl --user restart maliit-server.service
