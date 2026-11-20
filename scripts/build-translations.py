#!/usr/bin/env python3
"""Compile translations/futo-keyboard-sailfish-<lang>.ts into .qm catalogs.

The settings entry page is installed as main.qml, so QML looks up its
strings under the context "main" instead of "FutoSettingsPage". The
settings catalog therefore carries a copy of that context.

usage: build-translations.py LRELEASE SETTINGS_DIR EDITOR_DIR
"""
import copy, glob, os, subprocess, sys, tempfile
import xml.etree.ElementTree as ET

lrelease, settings_dir, editor_dir = sys.argv[1:4]
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
for ts in sorted(glob.glob(os.path.join(root, "translations", "futo-keyboard-sailfish-*.ts"))):
    lang = os.path.basename(ts)[len("futo-keyboard-sailfish-"):-len(".ts")]
    subprocess.run([lrelease, "-silent", ts, "-qm",
                    os.path.join(editor_dir, "futo-layout-editor-%s.qm" % lang)], check=True)
    tree = ET.parse(ts)
    for context in list(tree.getroot().iter("context")):
        if context.findtext("name") == "FutoSettingsPage":
            alias = copy.deepcopy(context)
            alias.find("name").text = "main"
            tree.getroot().append(alias)
    with tempfile.TemporaryDirectory() as tmp:
        merged = os.path.join(tmp, "settings.ts")
        tree.write(merged, encoding="utf-8", xml_declaration=True)
        subprocess.run([lrelease, "-silent", merged, "-qm",
                        os.path.join(settings_dir, "settings-futo-keyboard-%s.qm" % lang)], check=True)
