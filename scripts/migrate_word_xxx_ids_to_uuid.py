#!/usr/bin/env python3
"""Replace sentence ids matching word_XXX (three digits) with new UUID4 in sentences_fr.json and sentences_es.json."""

import json
import re
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = [
    ROOT / "LearnLanguageLikeABaby" / "Resources" / "sentences_fr.json",
    ROOT / "LearnLanguageLikeABaby" / "Resources" / "sentences_es.json",
]

WORD_ID = re.compile(r"^word_\d{3}$")


def main() -> None:
    for path in FILES:
        with path.open(encoding="utf-8") as f:
            data = json.load(f)
        n = 0
        for s in data.get("sentences", []):
            sid = s.get("id", "")
            if isinstance(sid, str) and WORD_ID.match(sid):
                s["id"] = str(uuid.uuid4())
                n += 1
        with path.open("w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
        print(f"{path.name}: replaced {n} word_NNN ids")


if __name__ == "__main__":
    main()
