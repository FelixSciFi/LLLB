#!/usr/bin/env python3
"""Replace every sentence `id` in sentences_fr.json and sentences_es.json with new UUID4 strings."""

import json
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = [
    ROOT / "LearnLanguageLikeABaby" / "Resources" / "sentences_fr.json",
    ROOT / "LearnLanguageLikeABaby" / "Resources" / "sentences_es.json",
]


def main() -> None:
    for path in FILES:
        with path.open(encoding="utf-8") as f:
            data = json.load(f)
        sentences = data.get("sentences", [])
        for s in sentences:
            s["id"] = str(uuid.uuid4())
        with path.open("w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")
        print(f"updated {len(sentences)} ids -> {path}")


if __name__ == "__main__":
    main()
