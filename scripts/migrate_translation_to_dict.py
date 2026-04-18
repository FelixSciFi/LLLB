#!/usr/bin/env python3
"""Rewrite string `translation` fields to {\"zh\": \"...\", \"en\": \"\"} in bundle JSON."""

from __future__ import annotations

import json
from pathlib import Path

RESOURCES = Path(__file__).resolve().parents[1] / "LearnLanguageLikeABaby" / "Resources"

FILES = [
    "sentences_fr.json",
    "sentences_es.json",
    "word_table_fr.json",
    "exampleSentences_fr.json",
    "exampleSentences_es.json",
]


def normalize_translation(val):
    if isinstance(val, dict):
        zh = val.get("zh", "")
        if not isinstance(zh, str):
            zh = str(zh) if zh is not None else ""
        en = val.get("en", "")
        if not isinstance(en, str):
            en = str(en) if en is not None else ""
        return {"zh": zh, "en": en}
    if val is None:
        return {"zh": "", "en": ""}
    s = val if isinstance(val, str) else str(val)
    return {"zh": s, "en": ""}


def convert_translations(obj):
    if isinstance(obj, dict):
        out = {}
        for k, v in obj.items():
            if k == "translation":
                out[k] = normalize_translation(v)
            else:
                out[k] = convert_translations(v)
        return out
    if isinstance(obj, list):
        return [convert_translations(x) for x in obj]
    return obj


def main():
    for name in FILES:
        path = RESOURCES / name
        if not path.is_file():
            print(f"skip (missing): {path}")
            continue
        raw = path.read_text(encoding="utf-8")
        data = json.loads(raw)
        new_data = convert_translations(data)
        path.write_text(
            json.dumps(new_data, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"ok: {path.name}")


if __name__ == "__main__":
    main()
