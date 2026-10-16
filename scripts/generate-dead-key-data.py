#!/usr/bin/env python3
"""Canonical Unicode composition pairs for Qt versions without String.normalize."""
import json
from pathlib import Path
import sys
import unicodedata

pairs = {}
for code in range(0x110000):
    value = chr(code)
    parts = unicodedata.decomposition(value).split()
    if len(parts) == 2 and not parts[0].startswith("<"):
        source = "".join(chr(int(part, 16)) for part in parts)
        if unicodedata.combining(source[1]) and unicodedata.normalize("NFC", source) == value:
            pairs[source] = value
text = ".pragma library\n\n// Generated from Unicode canonical composition, not locale-specific guesses.\n"
text += "var pairs = " + json.dumps(pairs, ensure_ascii=True, sort_keys=True, indent=2) + "\n"
target = Path(__file__).resolve().parents[1] / "layouts/FutoDeadKeyData.js"
if "--check" in sys.argv:
    if not target.exists() or target.read_text() != text:
        raise SystemExit("Regenerate the Unicode dead-key composition data")
else:
    target.write_text(text, encoding="utf-8")
