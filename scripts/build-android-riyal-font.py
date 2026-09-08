#!/usr/bin/env python3
"""Build the renamed Android Riyal font bundled by the keyboard."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from fontTools.ttLib import TTFont


ANDROID_FONT_SHA256 = (
    "61e022fdf23df726b4fdf2e5022c166c97ec4b3846c5dbb76fc0922798a2083a"
)
FAMILY_NAME = "FUTO Android Riyal"
POSTSCRIPT_NAME = "FUTOAndroidRiyal-Regular"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    source_bytes = args.source.read_bytes()
    digest = hashlib.sha256(source_bytes).hexdigest()
    if digest != ANDROID_FONT_SHA256:
        raise SystemExit(f"Unexpected Android Noto font SHA-256: {digest}")

    font = TTFont(args.source, recalcTimestamp=False)

    name_table = font["name"]
    replacement_ids = {1, 2, 3, 4, 6, 16, 17}
    name_table.names = [
        record for record in name_table.names if record.nameID not in replacement_ids
    ]
    names = {
        1: FAMILY_NAME,
        2: "Regular",
        3: "FUTO Android Riyal Regular",
        4: f"{FAMILY_NAME} Regular",
        6: POSTSCRIPT_NAME,
        16: FAMILY_NAME,
        17: "Regular",
    }
    for name_id, value in names.items():
        name_table.setName(value, name_id, 3, 1, 0x409)
        name_table.setName(value, name_id, 0, 3, 0)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    font.save(args.output)

    check = TTFont(args.output)
    codepoints = set().union(*(table.cmap.keys() for table in check["cmap"].tables))
    if 0xFDFC not in codepoints:
        raise SystemExit("Output font does not contain U+FDFC")
    print(hashlib.sha256(args.output.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
