#!/usr/bin/env python3
"""Normalize A1-CDI token text: strip + rstrip trailing .,!?;:
Then rebuild sentence text to stay grammatical (commas, apostrophes, final ? ! .).
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SENTENCES_PATH = ROOT / "LearnLanguageLikeABaby" / "Resources" / "sentences_fr.json"

PUNCT_TAIL = ".,!?;:"


def _smart_join(parts: list[str]) -> str:
    if not parts:
        return ""
    s = parts[0]
    for p in parts[1:]:
        if s.endswith("'") or s.endswith("\u2019"):  # straight / right single quote
            s += p
        else:
            s += " " + p
    return s


def _terminal_punct(s: str) -> str:
    s = s.rstrip()
    if s and s[-1] in ".?!":
        return s[-1]
    return ""


def rebuild_sentence_text(original: str, parts: list[str]) -> str:
    o = original.strip()
    tp = _terminal_punct(o)
    core = o[: -1].rstrip() if tp else o

    if "," in core:
        left, right = core.split(",", 1)
        left, right = left.strip(), right.strip()
        if len(parts) == 2:
            return f"{parts[0]}, {parts[1]}{tp}"
        if len(parts) == 3:
            return f"{parts[0]} {parts[1]}, {parts[2]}{tp}"
        raise ValueError(f"Unexpected comma pattern: {original!r} -> {parts!r}")

    body = _smart_join(parts)
    return f"{body}{tp}"


def clean_token_text(raw: str) -> str:
    s = raw.strip()
    while s and s[-1] in PUNCT_TAIL:
        s = s[:-1]
    return s


def main() -> None:
    with SENTENCES_PATH.open(encoding="utf-8") as f:
        data = json.load(f)

    text_changed = 0
    for s in data["sentences"]:
        if s.get("library") != "A1-CDI":
            continue
        for t in s["tokens"]:
            t["text"] = clean_token_text(t["text"])
        parts = [t["text"] for t in s["tokens"]]
        new_text = rebuild_sentence_text(s["text"], parts)
        if new_text != s["text"]:
            text_changed += 1
        s["text"] = new_text

    with SENTENCES_PATH.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"A1-CDI: normalized token text fields; {text_changed} sentence `text` strings rebuilt.")


if __name__ == "__main__":
    main()
