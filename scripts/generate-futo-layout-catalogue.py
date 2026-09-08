#!/usr/bin/env python3
"""Generate the Sailfish layout catalogue from a pinned FUTO layout checkout.

The generated JavaScript is runtime data; this script is deliberately strict so
that a new upstream key shape cannot silently be approximated or dropped.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys
import unicodedata
from typing import Any

import yaml


class FutoYamlLoader(yaml.SafeLoader):
    """YAML loader matching the catalogue's use of unquoted symbol keys."""


# PyYAML treats an unquoted '=' inside a flow sequence as YAML's special
# ``value`` token.  In the FUTO format it is simply the equals key.
FutoYamlLoader.add_constructor(
    "tag:yaml.org,2002:value", lambda loader, node: loader.construct_scalar(node)
)


def load_yaml(path: pathlib.Path) -> Any:
    return yaml.load(path.read_text(encoding="utf-8"), Loader=FutoYamlLoader)


EXCLUDED_LANGUAGES = {
    # Explicit project policy.
    "iw",
    # These need an IME, combiner, dead-key state, or sub-keyboard renderer.
    "zh", "zh_Hant", "ja", "ko", "vi", "ga", "haw", "lkt", "ks_Latn",
    "dz", "lbj", "sip", "xsr",
    # Upstream's language-neutral test entry is not a user language.
    "zz",
}

# FUTO dictionaries use either the complete locale or the base language.  Only
# entries backed by a real downloadable pack are listed here.
PREDICTION_PACKS = {
    "ar": "ar", "cs": "cs", "da": "da", "de": "de", "de_CH": "de",
    "el": "el", "en_GB": "en-gb", "en_IN": "en-gb", "en_US": "en-us",
    "es": "es", "es_419": "es", "es_US": "es", "fa": "fa", "fi": "fi",
    "fr": "fr", "fr_CA": "fr", "fr_CH": "fr", "hr": "hr", "hu": "hu",
    "it": "it", "it_CH": "it", "lt": "lt", "lv": "lv", "nb": "nb",
    "nl": "nl", "nl_BE": "nl", "pl": "pl", "pt_BR": "pt-br",
    "pt_PT": "pt-pt", "ro": "ro", "ru": "ru", "sl": "sl", "sr": "sr",
    "sr_Latn": "sr-latn", "sv": "sv", "tr": "tr",
}


def find_layout_files(root: pathlib.Path) -> dict[str, pathlib.Path]:
    result: dict[str, pathlib.Path] = {}
    for path in root.rglob("*.yaml"):
        if path.name in {"mapping.yaml", "names.yaml"}:
            continue
        if path.stem in result:
            raise ValueError(f"duplicate layout id {path.stem}: {path} and {result[path.stem]}")
        result[path.stem] = path
    return result


def layout_supported(document: dict[str, Any]) -> bool:
    return not any(document.get(key) for key in ("combiners", "imeHint", "subKeyboards"))


DIRECTIVE = re.compile(r"^!(?:auto|fixed)ColumnOrder!")
TEMPLATE_KEYS = {
    "$shift": "shift",
    "$delete": "delete",
    "$gap": "gap",
    "$zwnj": "zwnj",
    "$optionalzwnj": "zwnj",
    "$symbols": "symbols",
    "$alphabet": "alphabet",
    "$action": "action",
    "$space": "space",
    "$enter": "enter",
    "$number": "number",
    "$contextual": "contextual",
    "$period": "period",
}


def normalized_code(code: str) -> str:
    normalized = code.replace("-", "_").upper()
    return "EN" if normalized == "EN_US" else normalized


def display_for_icon(value: str) -> str:
    icons = {
        "!icon/zwnj_key": "ZWNJ",
        "!icon/zwj_key": "ZWJ",
    }
    return icons.get(value, value)


def resolve_text_reference(value: str, texts: dict[str, Any]) -> Any:
    if not value.startswith("!text/"):
        return value
    reference = value[6:]
    for prefix in ("keyspec_", "morekeys_", "additional_morekeys_"):
        if reference.startswith(prefix):
            group = prefix[:-1]
            key = reference[len(prefix):]
            if key not in texts.get(group, {}):
                # Locale-specific more-key slots are deliberately optional in
                # FUTO's text catalogue (for example Danish å has no extra
                # key in nordic_row1_11). An absent slot therefore means an
                # empty alternative list, whereas a missing primary keyspec is
                # an invalid layout and must remain a hard error.
                if group in {"morekeys", "additional_morekeys"}:
                    return []
                raise ValueError(f"unresolved FUTO text reference {value}")
            return texts[group][key]
    raise ValueError(f"unsupported FUTO text reference {value}")


def parse_spec(value: Any, texts: dict[str, Any], explicit_code: Any = None) -> dict[str, str]:
    if isinstance(value, (int, float)):
        value = str(value)
    if not isinstance(value, str):
        raise TypeError(f"unsupported key spec {value!r}")
    resolved = resolve_text_reference(value, texts)
    if isinstance(resolved, list):
        raise ValueError(f"more-key list used as a primary key: {value}")
    value = str(resolved)
    if value in TEMPLATE_KEYS:
        return {"kind": TEMPLATE_KEYS[value]}
    if len(value) > 1 and value.startswith("$") and value not in TEMPLATE_KEYS:
        raise ValueError(f"unsupported template key {value}")
    display = value
    output = value
    if "|" in value:
        display, output = value.rsplit("|", 1)
    if explicit_code is not None:
        if isinstance(explicit_code, int):
            output = chr(explicit_code)
        else:
            output = str(explicit_code)
    if output.startswith("!code/"):
        raise ValueError(f"unsupported key-code output {output}")
    return {"kind": "character", "caption": display_for_icon(display), "output": output}


def more_key_values(value: Any) -> list[Any]:
    if value is None:
        return []
    if isinstance(value, list):
        return value
    # In the catalogue a scalar moreKeys value denotes one key, even when its
    # output is a multi-codepoint grapheme.
    return [value]


def parse_choices(value: Any, texts: dict[str, Any]) -> list[dict[str, str]]:
    if isinstance(value, str) and DIRECTIVE.match(value):
        return []
    if isinstance(value, str) and value == "%":
        # AOSP's '%' placeholder asks the keyboard to append its generic
        # per-letter set. FutoCharacterKey already does that after these
        # official locale choices.
        return []
    if isinstance(value, str) and value.startswith("!text/"):
        resolved = resolve_text_reference(value, texts)
        values = resolved if isinstance(resolved, list) else [resolved]
        result: list[dict[str, str]] = []
        for item in values:
            result.extend(parse_choices(item, texts))
        return result
    if isinstance(value, dict):
        if value.get("type", "base") != "base":
            raise ValueError(f"a more-key must be a base key: {value!r}")
        return [parse_spec(value.get("spec", ""), texts, value.get("code"))]
    return [parse_spec(value, texts)]


def parse_base(value: Any, texts: dict[str, Any]) -> dict[str, Any]:
    if isinstance(value, list):
        if not value:
            raise ValueError("empty key list")
        primary = parse_base(value[0], texts)
        if primary.get("kind") != "character":
            if len(value) != 1:
                raise ValueError(f"template key cannot have alternatives: {value!r}")
            return primary
        choices: list[dict[str, str]] = []
        for item in value[1:]:
            choices.extend(parse_choices(item, texts))
        primary["more"] = choices
        return primary
    if isinstance(value, dict):
        key_type = value.get("type", "base")
        if key_type != "base":
            raise ValueError(f"expected a base key, got {key_type}: {value!r}")
        primary = parse_spec(value.get("spec", ""), texts, value.get("code"))
        if primary.get("kind") == "character":
            choices = []
            for item in more_key_values(value.get("moreKeys")):
                choices.extend(parse_choices(item, texts))
            primary["more"] = choices
        return primary
    return parse_spec(value, texts)


def parse_key(value: Any, texts: dict[str, Any]) -> dict[str, Any]:
    if isinstance(value, dict) and value.get("type") == "contextual":
        fallback = value.get("fallbackKey", ",")
        return parse_base(fallback, texts)
    if not isinstance(value, dict) or value.get("type", "base") == "base":
        return parse_base(value, texts)
    if value.get("type") != "case":
        raise ValueError(f"unsupported key type {value.get('type')}: {value!r}")
    normal = parse_base(value.get("normal"), texts)
    shifted_source = value.get("shiftedManually", value.get("shifted"))
    if shifted_source is not None:
        shifted = parse_base(shifted_source, texts)
        if normal.get("kind") != shifted.get("kind"):
            raise ValueError(f"normal/shifted key kind mismatch: {value!r}")
        if normal.get("kind") == "character":
            normal["shiftedCaption"] = shifted["caption"]
            normal["shiftedOutput"] = shifted["output"]
            normal["shiftedMore"] = shifted.get("more", [])
    return normal


def row_values(row: dict[str, Any]) -> tuple[str, list[Any]]:
    kinds = [(key, value) for key, value in row.items()
             if key in {"letters", "numbers", "bottom"}]
    if len(kinds) != 1:
        raise TypeError(f"unsupported row {row!r}")
    kind, values = kinds[0]
    if isinstance(values, str):
        values = values.split()
    if not isinstance(values, list):
        raise TypeError(f"unsupported {kind} row {values!r}")
    return kind, values


def script_for(root: pathlib.Path, path: pathlib.Path, layout_id: str) -> str:
    group = path.relative_to(root).parts[0]
    if group == "ArabicScript":
        return "persian" if layout_id == "farsi" else "arabic"
    return {
        "Amazigh": "tifinagh", "Armenian": "armenian", "Bengali": "bengali",
        "Cyrillic": "cyrillic", "Devanagari": "devanagari", "Georgian": "georgian",
        "Greek": "greek", "Gurmukhi": "gurmukhi", "InternationalPhoneticAlphabet": "latin",
        "Kannada": "kannada", "Khmer": "khmer", "Lao": "lao", "LatinScript": "latin",
        "Default": "latin", "Legacy": "latin", "Malayalam": "malayalam",
        "MyanmarScript": "myanmar", "Newa": "newa", "Sinhala": "sinhala",
        "Special": "latin", "Tamil": "tamil", "Telugu": "telugu", "Thai": "thai",
        "Tibetan": "tibetan", "ConstructedScripts": "shavian",
    }.get(group, group.lower())


def git_json(repo: pathlib.Path, revision: str, path: str) -> dict[str, Any]:
    raw = subprocess.check_output(
        ["git", "-C", str(repo), "show", f"{revision}:{path}"],
        text=True, encoding="utf-8")
    return json.loads(raw)


def android_locale_files(repo: pathlib.Path, revision: str) -> set[str]:
    raw = subprocess.check_output(
        ["git", "-C", str(repo), "ls-tree", "-r", "--name-only", revision,
         "tools/make-keyboard-text-py/locales"], text=True, encoding="utf-8")
    return {pathlib.PurePosixPath(line).name for line in raw.splitlines() if line.endswith(".json")}


def merge_texts(base: dict[str, Any], overlay: dict[str, Any]) -> dict[str, Any]:
    result = {key: (dict(value) if isinstance(value, dict) else value)
              for key, value in base.items()}
    for key, value in overlay.items():
        if isinstance(value, dict):
            current = dict(result.get(key, {}))
            current.update(value)
            result[key] = current
        else:
            result[key] = value
    return result


def locale_texts(repo: pathlib.Path, revision: str, files: set[str], code: str,
                 default: dict[str, Any]) -> dict[str, Any]:
    candidates: list[str] = []
    base = re.split(r"[_-]", code)[0]
    candidates.append(base + ".json")
    exact = code.replace("_Latn", "__Latn") + ".json"
    if exact not in candidates:
        candidates.append(exact)
    result = default
    for filename in candidates:
        if filename in files and filename != "DEFAULT.json":
            result = merge_texts(result, git_json(repo, revision,
                "tools/make-keyboard-text-py/locales/" + filename))
    return result


CYRILLIC_MOREKEY_BASES = {
    "cyrillic_u": "у", "cyrillic_ka": "к", "cyrillic_en": "н",
    "cyrillic_ghe": "г", "cyrillic_a": "а", "cyrillic_o": "о",
    "cyrillic_i": "и", "cyrillic_ie": "е", "cyrillic_soft_sign": "ь",
}


def language_morekeys(texts: dict[str, Any]) -> dict[str, list[dict[str, str]]]:
    result: dict[str, list[dict[str, str]]] = {}
    for key, raw_values in texts.get("morekeys", {}).items():
        base = key if len(key) == 1 else CYRILLIC_MOREKEY_BASES.get(key, "")
        if not base or key.startswith("misc_"):
            continue
        choices: list[dict[str, str]] = []
        for value in more_key_values(raw_values):
            choices.extend(parse_choices(value, texts))
        if choices:
            result[base] = choices
    return result


def language_name(code: str, names: dict[str, Any]) -> str:
    values = names.get(code) or names.get(code.replace("-", "_")) or {}
    if not isinstance(values, dict):
        return code
    for key in (code, code.replace("-", "_"), code.split("_")[0], code.split("-")[0], "en"):
        if values.get(key):
            return str(values[key])
    return str(next(iter(values.values()), code))


def has_latin_lead(value: str) -> bool:
    for character in value:
        if character.isalpha():
            return "LATIN" in unicodedata.name(character, "")
    return True


def generate(root: pathlib.Path, android_root: pathlib.Path, android_revision: str,
             output: pathlib.Path, language_output: pathlib.Path) -> None:
    mapping = load_yaml(root / "mapping.yaml")["languages"]
    names = load_yaml(root / "names.yaml")
    files = find_layout_files(root)

    android_files = android_locale_files(android_root, android_revision)
    default_texts = git_json(android_root, android_revision,
        "tools/make-keyboard-text-py/locales/DEFAULT.json")
    language_source_layout: dict[str, str] = {}
    official_codes: dict[str, str] = {}
    for official_code, ids in mapping.items():
        if official_code in EXCLUDED_LANGUAGES:
            continue
        direct = [layout_id for layout_id in ids if layout_id in files
                  and layout_supported(load_yaml(files[layout_id]))]
        if not direct:
            raise ValueError(f"{official_code}: no directly typed layout")
        code = normalized_code(official_code)
        if code in language_source_layout:
            raise ValueError(f"duplicate normalized language code {code}")
        language_source_layout[code] = direct[0]
        official_codes[code] = official_code

    layouts: list[dict[str, Any]] = []
    language_layout: dict[str, str] = {}
    alternatives: dict[str, dict[str, list[dict[str, str]]]] = {}
    signatures: dict[str, str] = {}
    used_ids: set[str] = set()
    for code, layout_id in language_source_layout.items():
        official_code = official_codes[code]
        texts = locale_texts(android_root, android_revision, android_files,
                             official_code, default_texts)
        alternatives[code] = language_morekeys(texts)
        path = files[layout_id]
        document = load_yaml(path)
        letter_rows: list[list[dict[str, Any]]] = []
        number_row: list[dict[str, Any]] = []
        bottom_row: list[dict[str, Any]] = []
        for row in document.get("rows", []):
            kind, values = row_values(row)
            if kind == "bottom":
                # Sailfish supplies the functional bottom row. Its presence is
                # still significant because upstream then does not auto-add
                # Shift/Delete to the final letter row.
                bottom_row = [{"kind": "custom"}]
                continue
            parsed = [parse_key(value, texts) for value in values]
            if kind == "letters":
                letter_rows.append(parsed)
            elif kind == "numbers":
                number_row = parsed

        explicit_templates = any(key.get("kind") != "character"
                                 for row in letter_rows for key in row)
        if not bottom_row and not explicit_templates and letter_rows:
            letter_rows[-1] = ([{"kind": "shift"}] + letter_rows[-1]
                               + [{"kind": "delete"}])
        max_characters = max((sum(key.get("kind") == "character" for key in row)
                              for row in letter_rows), default=0)
        layout = {
            "id": layout_id,
            "name": str(document.get("name", layout_id)),
            "script": script_for(root, path, layout_id),
            "rtl": path.relative_to(root).parts[0] == "ArabicScript",
            "shiftable": bool((document.get("attributes") or {}).get("shiftable", True)),
            "autoShift": bool(document.get("autoShift", True)),
            "numberRowMode": str(document.get("numberRowMode", "Default")),
            "rows": letter_rows,
            "numberRow": number_row,
            "bottomRow": bottom_row,
            "independentSizing": max_characters >= 11
                or path.relative_to(root).parts[0] not in {"Default", "LatinScript"},
        }
        signature_value = dict(layout)
        signature_value.pop("id")
        signature_value.pop("name")
        signature = json.dumps(signature_value, ensure_ascii=False, sort_keys=True,
                               separators=(",", ":"))
        if signature in signatures:
            resolved_id = signatures[signature]
        else:
            resolved_id = layout_id
            if resolved_id in used_ids:
                resolved_id = layout_id + "__" + code.lower()
            layout["id"] = resolved_id
            if resolved_id != layout_id:
                layout["name"] += " (" + code.replace("_", "-") + ")"
            layouts.append(layout)
            signatures[signature] = resolved_id
            used_ids.add(resolved_id)
        language_layout[code] = resolved_id

    languages = []
    for code, layout_id in language_layout.items():
        official_code = official_codes[code]
        layout = next(item for item in layouts if item["id"] == layout_id)
        prediction_pack = PREDICTION_PACKS.get(official_code, "")
        languages.append({
            "code": code,
            "officialCode": official_code,
            "name": language_name(official_code, names),
            "layoutId": layout_id,
            "script": layout["script"],
            "prediction": bool(prediction_pack),
            "dictionaryPack": prediction_pack,
            "swipe": bool(prediction_pack),
        })
    languages.sort(key=lambda item: (not has_latin_lead(item["name"]),
                                     item["name"].casefold(), item["code"]))

    # The Sailfish edition deliberately keeps its established SwiftKey-style
    # QWERTY beside the exact upstream FUTO arrangement.  Make that distinction
    # visible in the editor instead of presenting two indistinguishable rows.
    for layout in layouts:
        if layout["id"] == "qwerty":
            layout["name"] = "QWERTY"
        elif layout["id"] == "ipa_qwerty":
            layout["name"] = "IPA QWERTY"

    revision = "unknown"
    head = root / ".git" / "HEAD"
    if head.exists():
        import subprocess
        revision = subprocess.check_output(
            ["git", "-C", str(root), "rev-parse", "HEAD"], text=True
        ).strip()
    header = (".pragma library\n\n"
              "// Generated by scripts/generate-futo-layout-catalogue.py from the pinned\n"
              "// Apache-2.0 futo-org/futo-keyboard-layouts revision. Do not hand-edit.\n")
    output.write_text(
        header + f"var upstreamRevision = {json.dumps(revision)}\n\n"
        + "var layouts = " + json.dumps(layouts, ensure_ascii=False, separators=(",", ":")) + "\n\n"
        + "var languageLayoutIds = " + json.dumps(language_layout, ensure_ascii=False,
                                                   separators=(",", ":")) + "\n\n"
        + "var languageAlternatives = " + json.dumps(alternatives, ensure_ascii=False,
                                                       separators=(",", ":")) + "\n",
        encoding="utf-8", newline="\n")
    language_output.write_text(
        header + "var languages = " + json.dumps(languages, ensure_ascii=False,
                                                   separators=(",", ":")) + "\n",
        encoding="utf-8", newline="\n")


def audit(root: pathlib.Path) -> None:
    mapping_document = load_yaml(root / "mapping.yaml")
    mapping = mapping_document["languages"]
    files = find_layout_files(root)
    selected_languages = {}
    for code, ids in mapping.items():
        if code in EXCLUDED_LANGUAGES:
            continue
        directly_typed = [layout_id for layout_id in ids
                          if layout_id in files
                          and layout_supported(load_yaml(files[layout_id]))]
        # mapping.yaml is ordered by upstream preference. Port the canonical
        # language layout exactly; this avoids pretending that specialized
        # alternative bottom rows are supported by Sailfish's fixed bottom row.
        selected_languages[code] = directly_typed[:1]
    empty = [code for code, ids in selected_languages.items() if not ids]
    if empty:
        raise ValueError("eligible languages without a directly typed layout: " + ", ".join(empty))

    layout_ids = sorted({layout_id for ids in selected_languages.values() for layout_id in ids})
    max_rows = 0
    max_columns = 0
    row_kinds: set[str] = set()
    key_types: set[str] = set()
    explicit_templates: dict[str, list[str]] = {}
    explicit_bottom: list[str] = []
    explicit_numbers: list[str] = []
    attributes: set[str] = set()

    def inspect_key(layout_id: str, key: Any) -> None:
        if isinstance(key, str):
            if key.startswith("$"):
                explicit_templates.setdefault(layout_id, []).append(key)
            return
        if isinstance(key, list):
            for item in key:
                inspect_key(layout_id, item)
            return
        if not isinstance(key, dict):
            raise TypeError(f"{layout_id}: unsupported key value {key!r}")
        key_types.add(str(key.get("type", "base")))
        attributes.update(str(k) for k in (key.get("attributes") or {}).keys())
        for field in ("spec", "normal", "shifted", "shiftedManually", "moreKeys"):
            if field in key:
                inspect_key(layout_id, key[field])

    for layout_id in layout_ids:
        document = load_yaml(files[layout_id])
        letter_rows = []
        for row in document.get("rows", []):
            if not isinstance(row, dict) or len(row) != 1:
                raise TypeError(f"{layout_id}: unsupported row {row!r}")
            kind, keys = next(iter(row.items()))
            row_kinds.add(str(kind))
            if kind == "bottom":
                explicit_bottom.append(layout_id)
                continue
            if kind == "numbers":
                explicit_numbers.append(layout_id)
                continue
            if kind != "letters":
                raise ValueError(f"{layout_id}: unsupported row kind {kind}")
            if isinstance(keys, str):
                keys = keys.split()
            if not isinstance(keys, list):
                raise TypeError(f"{layout_id}: unsupported letters row {keys!r}")
            letter_rows.append(keys)
            max_columns = max(max_columns, len(keys))
            for key in keys:
                inspect_key(layout_id, key)
        max_rows = max(max_rows, len(letter_rows))

    print(json.dumps({
        "languages": len(selected_languages),
        "layouts": len(layout_ids),
        "prediction_languages": len([c for c in selected_languages if c in PREDICTION_PACKS]),
        "typing_only_languages": len([c for c in selected_languages if c not in PREDICTION_PACKS]),
        "max_rows": max_rows,
        "max_columns": max_columns,
        "row_kinds": sorted(row_kinds),
        "key_types": sorted(key_types),
        "attributes": sorted(attributes),
        "layouts_with_templates": {k: sorted(set(v)) for k, v in explicit_templates.items()},
        "layouts_with_bottom": sorted(set(explicit_bottom)),
        "layouts_with_numbers": sorted(set(explicit_numbers)),
    }, ensure_ascii=False, indent=2))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=pathlib.Path,
                        help="checkout of futo-org/futo-keyboard-layouts")
    parser.add_argument("--audit", action="store_true")
    parser.add_argument("--output", type=pathlib.Path,
                        default=pathlib.Path("layouts/FutoGeneratedLayouts.js"))
    parser.add_argument("--language-output", type=pathlib.Path,
                        default=pathlib.Path("layouts/FutoLanguageCatalogue.js"))
    parser.add_argument("--android-source", type=pathlib.Path, required=not "--audit" in sys.argv,
                        help="checkout of the pinned futo-org/android-keyboard revision")
    parser.add_argument("--android-revision", default="eaf0389f962b0dba07778d0feab6511e6e98c581")
    args = parser.parse_args()
    if args.audit:
        audit(args.source.resolve())
        return 0
    generate(args.source.resolve(), args.android_source.resolve(), args.android_revision,
             args.output.resolve(), args.language_output.resolve())
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"error: {error}", file=sys.stderr)
        raise
