#!/usr/bin/env python3
"""Extract the non-JNI KeyboardLM implementation from pinned FUTO source."""

import pathlib
import sys


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: generate-core.py SOURCE OUTPUT")
    source = pathlib.Path(sys.argv[1])
    output = pathlib.Path(sys.argv[2])
    text = source.read_text(encoding="utf-8")
    start_marker = "#define EPS 0.0001"
    end_marker = "namespace latinime {"
    start = text.find(start_marker)
    end = text.find(end_marker, start)
    if start < 0 or end < 0:
        raise SystemExit("pinned FUTO KeyboardLM source markers changed")
    core = text[start:end].rstrip() + "\n"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        "// Generated verbatim from the pinned FUTO Android Keyboard source.\n"
        + core,
        encoding="utf-8",
        newline="\n",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
