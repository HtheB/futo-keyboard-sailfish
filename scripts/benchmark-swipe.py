#!/usr/bin/env python3
"""Deterministic noisy-gesture benchmark for the offline swipe decoder."""

import argparse
import json
import math
import random
import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Layout:
    rows: tuple[str, ...]
    y_positions: tuple[float, ...] = (0.10, 0.50, 0.90)
    spans: tuple[tuple[float, float], ...] = (
        (0.0, 1.0), (0.0, 1.0), (0.0, 1.0))

    def centers(self) -> dict[str, tuple[float, float]]:
        result: dict[str, tuple[float, float]] = {}
        for row, y, (left, right) in zip(self.rows, self.y_positions, self.spans):
            for index, letter in enumerate(row):
                result[letter] = (left + (index + 0.5) * (right - left) / len(row), y)
        return result


LAYOUTS = {
    "EN": Layout(("qwertyuiop", "asdfghjkl", "zxcvbnm"),
                 spans=((0.0, 1.0), (0.0, 0.9), (0.1, 0.8))),
    "DE": Layout(("qwertzuiopü", "asdfghjklöä", "yxcvbnm")),
    "RU": Layout(("йцукенгшщзх", "фывапролджэ", "ячсмитьбю")),
}

CASES = {
    "EN": ("as", "hello", "keyboard", "world"),
    "DE": ("auto", "danke", "denke", "hallo"),
    "RU": ("привет", "спасибо"),
}

DICTIONARIES = {
    "EN": "en_US.fksidx",
    "DE": "de.fksidx",
    "RU": "ru.fksidx",
}


def serialized_geometry(centers: dict[str, tuple[float, float]]) -> str:
    return ";".join(
        f"{ord(letter)}:{x:.5f}:{y:.5f}"
        for letter, (x, y) in centers.items()
    )


def noisy_gesture(word: str, centers: dict[str, tuple[float, float]],
                  generator: random.Random, noise: float) -> str:
    target = [centers[letter] for letter in word]
    points: list[tuple[float, float]] = []
    for index in range(len(target) - 1):
        start_x, start_y = target[index]
        end_x, end_y = target[index + 1]
        distance = math.hypot(end_x - start_x, end_y - start_y)
        steps = max(3, int(math.ceil(distance * 18)))
        for step in range(steps):
            if index > 0 and step == 0:
                continue
            fraction = step / steps
            # The endpoint keys remain reliable while intermediate touch
            # samples receive realistic deterministic finger jitter.
            jitter = math.sin(math.pi * fraction)
            x = start_x + (end_x - start_x) * fraction
            y = start_y + (end_y - start_y) * fraction
            x += generator.gauss(0.0, noise) * jitter
            y += generator.gauss(0.0, noise) * jitter
            points.append((max(0.0, min(1.0, x)), max(0.0, min(1.0, y))))
    points.append(target[-1])

    continuous = []
    for index, (x, y) in enumerate(points):
        key = ord(word[0]) if index == 0 else ord(word[-1]) if index == len(points) - 1 else 0
        continuous.append(f"{key}:{x:.5f}:{y:.5f}")

    return ";".join(continuous)


class Engine:
    def __init__(self, executable: Path, dictionaries: dict[str, Path]) -> None:
        arguments = [str(executable)]
        for language, path in dictionaries.items():
            arguments.extend(("--dictionary", f"{language}={path}"))
        self.process = subprocess.Popen(
            arguments, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL, text=True, bufsize=1)

    def swipe(self, language: str, path: str, geometry: str) -> list[str]:
        fields = ("SWIPE", language, "12", "0", path, geometry)
        assert self.process.stdin is not None
        assert self.process.stdout is not None
        self.process.stdin.write("\t".join(fields) + "\n")
        self.process.stdin.flush()
        response = self.process.stdout.readline().rstrip("\n").split("\t", 1)
        if len(response) != 2 or response[0] != "OK":
            raise RuntimeError("invalid engine response: " + "\t".join(response))
        return [candidate["word"].casefold() for candidate in json.loads(response[1])]

    def close(self) -> None:
        if self.process.stdin is not None:
            self.process.stdin.close()
        self.process.wait(timeout=10)


def rank(candidates: list[str], target: str) -> int | None:
    target = target.casefold()
    try:
        return candidates.index(target) + 1
    except ValueError:
        return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--iterations", type=int, default=20)
    parser.add_argument("--noise", type=float, default=0.018)
    parser.add_argument("--seed", type=int, default=2303)
    options = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    executable = root / "build" / "futo-dictionary-compiler"
    dictionaries = {
        language: root / "build" / "dictionaries" / filename
        for language, filename in DICTIONARIES.items()
    }
    missing = [path for path in (executable, *dictionaries.values()) if not path.is_file()]
    if missing:
        raise SystemExit("Build the host engine and dictionaries first: " +
                         ", ".join(str(path) for path in missing))

    generator = random.Random(options.seed)
    engine = Engine(executable, dictionaries)
    try:
        print("language word       top1/top5")
        print("-------- ---------- ---------")
        total = {"top1": 0, "top5": 0, "runs": 0}
        for language, words in CASES.items():
            centers = LAYOUTS[language].centers()
            geometry = serialized_geometry(centers)
            for word in words:
                counts = {"top1": 0, "top5": 0}
                for _ in range(options.iterations):
                    path = noisy_gesture(word, centers, generator, options.noise)
                    result_rank = rank(engine.swipe(language, path, geometry), word)
                    counts["top1"] += result_rank == 1
                    counts["top5"] += result_rank is not None and result_rank <= 5
                for name, value in counts.items():
                    total[name] += value
                total["runs"] += options.iterations
                print(f"{language:<8} {word:<10} {counts['top1']:>3}/{counts['top5']:<3}")
        print("-------- ---------- ---------")
        print(f"TOTAL               {total['top1']:>3}/{total['top5']:<3} "
              f"of {total['runs']} gestures")
    finally:
        engine.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
