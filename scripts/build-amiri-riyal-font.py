#!/usr/bin/env python3
"""Build Amiri with AppSupport's compact U+FDFC Rial glyph."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont


AMIRI_VERSIONS = {
    "cd2550c0f4c05eb341bf97958211aaa39382bca96577ba3a67d4a3b4912c43c0":
        "Version 1.003; FUTO compact Rial glyph",
    "8d441c9b07d0ebc200c9752a5ec505eb41a61468fba985b4f6d7c8157cf02da0":
        "Version 000.107; FUTO compact Rial glyph",
}
ANDROID_UI_SHA256 = (
    "61e022fdf23df726b4fdf2e5022c166c97ec4b3846c5dbb76fc0922798a2083a"
)
RIAL_CODEPOINT = 0xFDFC


def verified_font(path: Path, expected_sha256: str) -> TTFont:
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != expected_sha256:
        raise SystemExit(f"Unexpected SHA-256 for {path}: {digest}")
    return TTFont(path, recalcTimestamp=False)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("amiri_source", type=Path)
    parser.add_argument("android_ui_source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    target_digest = hashlib.sha256(args.amiri_source.read_bytes()).hexdigest()
    version_name = AMIRI_VERSIONS.get(target_digest)
    if version_name is None:
        raise SystemExit(f"Unexpected SHA-256 for {args.amiri_source}: {target_digest}")
    target = TTFont(args.amiri_source, recalcTimestamp=False)
    source = verified_font(args.android_ui_source, ANDROID_UI_SHA256)

    target_name = target.getBestCmap()[RIAL_CODEPOINT]
    source_name = source.getBestCmap()[RIAL_CODEPOINT]
    scale = target["head"].unitsPerEm / source["head"].unitsPerEm

    target_glyph_set = target.getGlyphSet()
    source_glyph_set = source.getGlyphSet()
    pen = TTGlyphPen(target_glyph_set)
    source_glyph_set[source_name].draw(
        TransformPen(pen, (scale, 0, 0, scale, 0, 0))
    )
    target["glyf"][target_name] = pen.glyph()

    source_advance, source_lsb = source["hmtx"][source_name]
    target["hmtx"][target_name] = (
        round(source_advance * scale),
        round(source_lsb * scale),
    )

    name_table = target["name"]
    for platform_id, encoding_id, language_id in ((3, 1, 0x409), (0, 3, 0)):
        name_table.setName(
            version_name,
            5,
            platform_id,
            encoding_id,
            language_id,
        )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    target.save(args.output)

    check = TTFont(args.output)
    glyph_name = check.getBestCmap().get(RIAL_CODEPOINT)
    if glyph_name is None or check["glyf"][glyph_name].isComposite():
        raise SystemExit("Output font does not contain the compact simple U+FDFC glyph")
    print(hashlib.sha256(args.output.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
