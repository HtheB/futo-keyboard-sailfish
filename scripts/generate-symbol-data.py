#!/usr/bin/env python3
"""Generate the extended symbol picker from the phone's installed fonts."""

from __future__ import annotations

import argparse
import json
import re
import unicodedata
from collections import OrderedDict
from pathlib import Path

from fontTools.ttLib import TTFont


# Characters already available directly or by long-press on FUTO's two normal
# symbol pages.  The extended picker deliberately spends its space on more
# unusual characters.
NORMAL_KEYBOARD_SYMBOLS = set(
    "!\"#$%&'()*+,-./0123456789:;<=>?@[\\]^_`{|}~"
    "£€﷼₺¥¢½¼¹⅛⅓⅔²³¾⅜⁴⅝ⁿ…•×„“«»”ʼ‡†‹›≈≠±¯—–‰÷"
    "©®™§¶°¬¦"
)

REQUIRED_SYMBOLS = set(
    "←↑→↓↔↕↨∂∆∏∑∙√∞▀▄█▌▐░▒▓■□▪▫▬▲►▼◄◊○◌●◘◙◦☺☻ﷲﷴﷺﷻ﷽"
)

# Keep the most useful numeric forms complete and in a predictable order.
# Some superscripts are also normal long-press alternatives, but omitting
# them here made the picker start with ⁰⁵⁶⁷⁸⁹, which looked broken.
NUMBER_PRIORITY = (
    "$£€﷼₺¥¢"
    "⁰¹²³⁴⁵⁶⁷⁸⁹"
    "₀₁₂₃₄₅₆₇₈₉"
    "٠١٢٣٤٥٦٧٨٩"  # Arabic-Indic digits
    "۰۱۲۳۴۵۶۷۸۹"  # Eastern Arabic/Persian digits
)

# Present the Arabic religious ligatures by practical meaning rather than by
# Unicode code-point number. The common phrases come first, related salutation
# fragments remain adjacent, and specialized Qur'anic stop signs come last.
ARABIC_LIGATURE_PRIORITY = "﷽ﷲﷻﷴﷺﷹﷷﷸﷵﷶﷳﷰﷱ"

ALLOWED_CATEGORIES = {
    "Pc", "Pd", "Ps", "Pe", "Pi", "Pf", "Po",
    "Sc", "Sk", "Sm", "So", "Nl", "No",
}

CATEGORIES = OrderedDict([
    ("favorites", ("Favorites", "☆")),
    ("arrows", ("Arrows", "→")),
    ("math", ("Math", "∑")),
    ("currency_numbers", ("Currency & numbers", "$")),
    ("punctuation", ("Punctuation", "¶")),
    ("boxes_blocks", ("Boxes & blocks", "▓")),
    ("shapes", ("Shapes", "◆")),
    ("technical", ("Technical", "⌘")),
    ("letterlike", ("Letter-like", "Ω")),
    ("enclosed", ("Enclosed", "⑴")),
    ("music_games", ("Music & games", "♪")),
    ("cultural", ("Cultural", "☯")),
    ("misc", ("More", "※")),
])


def load_codepoints(font_paths: list[Path]) -> set[int]:
    result: set[int] = set()
    for path in font_paths:
        font = TTFont(str(path), lazy=True)
        try:
            for table in font["cmap"].tables:
                if table.isUnicode():
                    result.update(table.cmap.keys())
        finally:
            font.close()
    return result


def load_single_codepoint_emoji(path: Path) -> set[int]:
    """Read single-code-point entries already present in FutoEmojiData.js."""
    source = path.read_text(encoding="utf-8")
    return {
        int(match.group(1), 16)
        for match in re.finditer(r'"c":"([0-9a-f]+)"', source)
    }


def is_picker_symbol(codepoint: int) -> bool:
    if not 0 <= codepoint <= 0x10FFFF:
        return False
    character = chr(codepoint)
    if character in NUMBER_PRIORITY:
        return True
    category = unicodedata.category(character)
    if category in ALLOWED_CATEGORIES:
        return character not in NORMAL_KEYBOARD_SYMBOLS
    # Arabic religious ligatures are letters in Unicode, but function as
    # single typographic symbols and are specifically useful in this picker.
    if 0xFDF0 <= codepoint <= 0xFDFD:
        return True
    # Mathematical alphabets are useful symbols even though Unicode assigns
    # most of them ordinary upper/lower-case letter categories.
    if 0x1D400 <= codepoint <= 0x1D7FF:
        return category[0] in {"L", "N"}
    return False


def category_for(codepoint: int) -> str:
    character = chr(codepoint)
    category = unicodedata.category(character)
    name = unicodedata.name(character, "")

    if character in NUMBER_PRIORITY:
        return "currency_numbers"

    if (0x2190 <= codepoint <= 0x21FF
            or 0x27F0 <= codepoint <= 0x27FF
            or 0x2900 <= codepoint <= 0x297F
            or "ARROW" in name):
        return "arrows"
    if 0x2500 <= codepoint <= 0x259F:
        return "boxes_blocks"
    if (category == "Sm"
            or 0x2200 <= codepoint <= 0x22FF
            or 0x27C0 <= codepoint <= 0x27EF
            or 0x2980 <= codepoint <= 0x2AFF):
        return "math"
    if category in {"Sc", "Nl", "No"} or 0x2070 <= codepoint <= 0x209F:
        return "currency_numbers"
    if category.startswith("P"):
        return "punctuation"
    if (0x25A0 <= codepoint <= 0x25FF
            or any(word in name for word in (
                "CIRCLE", "SQUARE", "TRIANGLE", "DIAMOND", "STAR",
                "LOZENGE", "BULLET", "GEOMETRIC",
            ))):
        return "shapes"
    if (0x2300 <= codepoint <= 0x245F
            or 0x2800 <= codepoint <= 0x28FF
            or any(word in name for word in (
                "TECHNICAL", "CONTROL", "KEYBOARD", "ELECTRICAL",
                "APL FUNCTIONAL", "DENTISTRY",
            ))):
        return "technical"
    if 0x2100 <= codepoint <= 0x214F or 0x1D400 <= codepoint <= 0x1D7FF:
        return "letterlike"
    if (0x2460 <= codepoint <= 0x24FF
            or 0x1F100 <= codepoint <= 0x1F1FF
            or "ENCLOSED" in name or "CIRCLED" in name
            or "PARENTHESIZED" in name):
        return "enclosed"
    if (0x1D100 <= codepoint <= 0x1D24F
            or 0x1F000 <= codepoint <= 0x1F0FF
            or any(word in name for word in (
                "MUSIC", "MUSICAL", "CHESS", "DICE", "PLAYING CARD",
                "DOMINO", "MAHJONG", "CHECKER", "SHOGI",
            ))):
        return "music_games"
    if (0xFDF0 <= codepoint <= 0xFDFD
            or any(word in name for word in (
                "RELIGIOUS", "CROSS", "ANKH", "YIN YANG", "TRIGRAM",
                "HEXAGRAM", "ZODIAC", "PLANET", "ASTROLOGICAL",
                "ARABIC LIGATURE",
            ))):
        return "cultural"
    return "misc"


def js_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


def render(font_paths: list[Path], emoji_data_path: Path,
           output_path: Path) -> dict[str, int]:
    coverage = load_codepoints(font_paths)
    emoji_codepoints = load_single_codepoint_emoji(emoji_data_path)
    # Keep explicitly requested entries even if fontconfig cannot currently
    # find a glyph.  The character must still be available for insertion into
    # apps which bundle a broader font, and a later system font can render it
    # without requiring another keyboard update.
    coverage.update(ord(character) for character in REQUIRED_SYMBOLS)
    coverage.update(ord(character) for character in NUMBER_PRIORITY)

    categorized: dict[str, list[str]] = {key: [] for key in CATEGORIES}
    for codepoint in sorted(coverage):
        if not is_picker_symbol(codepoint):
            continue
        # The dedicated picker already carries every Unicode 17 emoji with
        # artwork and search metadata. Keep the user's explicitly requested
        # text symbols, but do not duplicate the remaining pictographs here.
        if (codepoint in emoji_codepoints
                and chr(codepoint) not in REQUIRED_SYMBOLS):
            continue
        categorized[category_for(codepoint)].append(chr(codepoint))

    priority = list(NUMBER_PRIORITY)
    priority_set = set(priority)
    categorized["currency_numbers"] = priority + [
        value for value in categorized["currency_numbers"]
        if value not in priority_set
    ]

    # Keep religious groups visually separate. Arabic presentation-form
    # ligatures belong first; every cross/ankh variant belongs at the bottom.
    cultural = categorized["cultural"]
    available_arabic_ligatures = {
        value for value in cultural if 0xFDF0 <= ord(value) <= 0xFDFD
    }
    arabic_ligatures = [
        value for value in ARABIC_LIGATURE_PRIORITY
        if value in available_arabic_ligatures
    ]
    cross_symbols = [
        value for value in cultural
        if ("CROSS" in unicodedata.name(value, "")
            or "ANKH" in unicodedata.name(value, ""))
    ]
    other_cultural = [
        value for value in cultural
        if value not in arabic_ligatures and value not in cross_symbols
    ]
    categorized["cultural"] = (
        arabic_ligatures + other_cultural + cross_symbols
    )

    lines = [
        "/* Generated by scripts/generate-symbol-data.py from the Sailfish phone's fonts.",
        " * Do not edit this file by hand.",
        " * Fonts: " + ", ".join(path.name for path in font_paths),
        " */",
        ".pragma library",
        "",
        "var categories = [",
    ]
    for key, (name, icon) in CATEGORIES.items():
        lines.append("    {")
        lines.append(f"        id: {js_string(key)},")
        lines.append(f"        name: {js_string(name)},")
        lines.append(f"        icon: {js_string(icon)},")
        lines.append("        entries: [")
        entries = categorized[key]
        for start in range(0, len(entries), 24):
            chunk = ",".join(js_string(value) for value in entries[start:start + 24])
            lines.append(f"            {chunk},")
        lines.append("        ]")
        lines.append("    },")
    lines.extend([
        "]",
        "",
        "function entriesForCategory(index) {",
        "    index = Math.max(0, Math.min(categories.length - 1, Number(index)))",
        "    return categories[index].entries",
        "}",
        "",
    ])
    output_path.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    return {key: len(values) for key, values in categorized.items()}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--font", action="append", required=True, type=Path)
    parser.add_argument("--emoji-data", type=Path,
                        default=Path("layouts/FutoEmojiData.js"))
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    stats = render(args.font, args.emoji_data, args.output)
    print(f"Generated {sum(stats.values())} symbols in {len(stats)} categories")
    for key, count in stats.items():
        print(f"{key}: {count}")


if __name__ == "__main__":
    main()
