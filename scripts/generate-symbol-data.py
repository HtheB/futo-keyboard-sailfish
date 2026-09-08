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
    "£€₺⃁﷼¥¢½¼¹⅛⅓⅔²³¾⅜⁴⅝ⁿ…•×„“«»”ʼ‡†‹›≈≠±¯—–‰÷"
    "©®™§¶°¬¦"
)

REQUIRED_SYMBOLS = set(
    "←↑→↓↔↕↨∂∆∏∑∙√∞▀▄█▌▐░▒▓■□▪▫▬▲►▼◄◊○◌●◘◙◦☺☻⃁﷼ﷲﷴﷺﷻ﷽"
)

# Keep the most useful families complete and in a predictable order. These
# intentionally duplicate a handful of normal long-press alternatives: an
# exhaustive picker should not make the user hunt across two interfaces.
CURRENCY_PRIORITY = "$£€₺⃁﷼¥¢"
NUMBER_PRIORITY = (
    "⁰¹²³⁴⁵⁶⁷⁸⁹ⁿ"
    "₀₁₂₃₄₅₆₇₈₉"
    "٠١٢٣٤٥٦٧٨٩"  # Arabic-Indic digits
    "۰۱۲۳۴۵۶۷۸۹"  # Eastern Arabic/Persian digits
    "½⅓⅔¼¾⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞⅟"
)
BRACKET_QUOTE_PRIORITY = (
    "‘’“”«»‹›()[]{}<>⟨⟩⌈⌉⌊⌋"
    "〈〉《》「」『』【】〔〕〖〗"
)
PUNCTUATION_PRIORITY = "¡¿‽…·•※—–‐′″"
TAB_PRIORITIES = {
    "arrows": "←↑→↓↔↕↨↶↷↺↻⇐⇑⇒⇓⇔►◄",
    "math": "±×÷=≠≈<>≤≥∑∏√∞∫∂∆∈∉∩∪⊂⊃∧∨",
    "numbers": NUMBER_PRIORITY,
    "currency": CURRENCY_PRIORITY,
    "punctuation": PUNCTUATION_PRIORITY,
    "brackets_quotes": BRACKET_QUOTE_PRIORITY,
    "boxes_blocks": "─│┌┐└┘┼═║╬▀▄█░▒▓",
    "shapes": "■□▪▫▬▲△▼◆◇◊○◌●◘◙◦★☆",
    "technical": "⌘⌥⌫⌦⌧⏎⎋⏏⎙⌀",
    "letterlike": "℃℉№℗℞℠℡℧",
    "enclosed": "Ⓐⓐ⒜",
    "music": "♩♪♫♬♭♮♯",
    "games": "♔♕♖♗♘♙♚♛♜♝♞♟",
    "cultural": "☯☦☥☰",
    "marks_misc": "¨´¸˘˙˚˛˜˝",
}
EXPLICIT_TEXT_SYMBOLS = set().union(
    REQUIRED_SYMBOLS,
    *(set(values) for values in TAB_PRIORITIES.values()),
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
    ("numbers", ("Numbers", "①")),
    ("currency", ("Currency", "$")),
    ("punctuation", ("Punctuation", "¶")),
    ("brackets_quotes", ("Brackets & quotes", "「")),
    ("boxes_blocks", ("Boxes & blocks", "▓")),
    ("shapes", ("Shapes", "◆")),
    ("technical", ("Technical", "⌘")),
    ("braille", ("Braille", "⠿")),
    ("letterlike", ("Letter-like", "Ω")),
    # Plain A is deliberate: some Sailfish tab labels do not apply Symbola
    # fallback even though the full grid can render mathematical alphabets.
    ("styled_letters", ("Styled letters", "A")),
    ("enclosed", ("Enclosed", "⑴")),
    ("music", ("Music", "♪")),
    ("games", ("Games", "♟")),
    ("cultural", ("Cultural & religious", "☯")),
    ("marks_misc", ("Marks & more", "※")),
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
    if character in EXPLICIT_TEXT_SYMBOLS:
        return True
    # Regional indicators are implementation pieces for flag emoji rather
    # than useful standalone symbols. Complete flags already live in Emoji.
    if 0x1F1E6 <= codepoint <= 0x1F1FF:
        return False
    # U+2800 is a deliberately empty Braille cell and would appear as a
    # completely blank, tappable key.
    if codepoint == 0x2800:
        return False
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

    if character in CURRENCY_PRIORITY:
        return "currency"
    if character in NUMBER_PRIORITY:
        return "numbers"
    if character in BRACKET_QUOTE_PRIORITY:
        return "brackets_quotes"
    if character in PUNCTUATION_PRIORITY:
        return "punctuation"
    for category_id, priority_text in TAB_PRIORITIES.items():
        if character in priority_text:
            return category_id

    if (0x2190 <= codepoint <= 0x21FF
            or 0x27F0 <= codepoint <= 0x27FF
            or 0x2900 <= codepoint <= 0x297F
            or "ARROW" in name or "POINTER" in name):
        return "arrows"

    # The most specific semantic groups must be checked before generic visual
    # words such as CIRCLE, SQUARE, TRIANGLE, and STAR. The old order sent
    # circled letters, musical marks, APL keys, and religious signs to Shapes.
    if (0xFDF0 <= codepoint <= 0xFDFD or codepoint == 0x06DE
            or any(word in name for word in (
                "RELIGIOUS", "CROSS", "ANKH", "YIN YANG", "TRIGRAM",
                "HEXAGRAM", "ZODIAC", "PLANET", "ASTROLOGICAL",
                "ARABIC LIGATURE", "RUB EL HIZB",
            ))):
        return "cultural"
    if (0x1F000 <= codepoint <= 0x1F0FF
            or any(word in name for word in (
                "CHESS", "PLAYING CARD", "DOMINO", "MAHJONG",
                "CHECKER", "SHOGI", "DIE FACE",
            ))):
        return "games"
    if (0x1D000 <= codepoint <= 0x1D24F
            or any(word in name for word in (
                "MUSIC", "MUSICAL", "CLEF", "QUARTER NOTE",
                "EIGHTH NOTE", "SIXTEENTH NOTE",
            ))):
        return "music"
    if 0x2800 <= codepoint <= 0x28FF:
        return "braille"
    if 0x1D400 <= codepoint <= 0x1D7FF:
        return "styled_letters"
    if (0x2460 <= codepoint <= 0x24FF
            or 0x1F100 <= codepoint <= 0x1F1FF
            or "ENCLOSED" in name or "PARENTHESIZED" in name):
        # Numeric enclosed forms are more useful alongside the other number
        # styles; enclosed letters and signs remain together here.
        return "numbers" if category in {"Nl", "No"} else "enclosed"
    if category == "Sc":
        return "currency"
    if category in {"Nl", "No"} or 0x2070 <= codepoint <= 0x209F:
        return "numbers"
    if (category in {"Ps", "Pe", "Pi", "Pf"}
            or any(word in name for word in (
                "BRACKET", "PARENTHESIS", "QUOTATION MARK",
            ))):
        return "brackets_quotes"
    if category.startswith("P"):
        return "punctuation"
    if 0x2500 <= codepoint <= 0x259F:
        return "boxes_blocks"
    if (category == "Sm"
            or 0x2200 <= codepoint <= 0x22FF
            or 0x27C0 <= codepoint <= 0x27EF
            or 0x2980 <= codepoint <= 0x2AFF):
        return "math"
    if (0x2300 <= codepoint <= 0x245F
            or any(word in name for word in (
                "TECHNICAL", "CONTROL", "KEYBOARD", "ELECTRICAL",
                "APL FUNCTIONAL", "DENTISTRY",
            ))):
        return "technical"
    if 0x2100 <= codepoint <= 0x214F:
        return "letterlike"
    if (0x25A0 <= codepoint <= 0x25FF
            or any(word in name for word in (
                "CIRCLE", "SQUARE", "TRIANGLE", "DIAMOND", "STAR",
                "LOZENGE", "BULLET", "GEOMETRIC",
            ))):
        return "shapes"
    return "marks_misc"


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
                and chr(codepoint) not in EXPLICIT_TEXT_SYMBOLS):
            continue
        categorized[category_for(codepoint)].append(chr(codepoint))

    for category_id, priority_text in TAB_PRIORITIES.items():
        priority = [value for value in priority_text
                    if value in categorized[category_id]]
        priority_set = set(priority)
        categorized[category_id] = priority + [
            value for value in categorized[category_id]
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
    arabic_cultural_symbols = [
        value for value in cultural if value == "۞"
    ]
    other_cultural = [
        value for value in cultural
        if (value not in arabic_ligatures and value not in cross_symbols
            and value not in arabic_cultural_symbols)
    ]
    cultural_priority = [
        value for value in TAB_PRIORITIES["cultural"]
        if value in other_cultural
    ]
    cultural_priority_set = set(cultural_priority)
    other_cultural = [
        value for value in other_cultural
        if value not in cultural_priority_set
    ]
    categorized["cultural"] = (
        arabic_ligatures + arabic_cultural_symbols
        + cultural_priority + other_cultural + cross_symbols
    )

    # The generator's single code-point walk should make duplicates
    # impossible. Keep an explicit invariant so future priority or migration
    # rules cannot silently place the same character in multiple tabs.
    flattened = [value for values in categorized.values() for value in values]
    if len(flattened) != len(set(flattened)):
        raise RuntimeError("generated symbol categories contain duplicates")

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
