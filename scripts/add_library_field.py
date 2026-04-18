#!/usr/bin/env python3
import json
from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    path = root / "LearnLanguageLikeABaby" / "Resources" / "sentences_fr.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    sentences = data.get("sentences", [])

    for s in sentences:
        s["library"] = "A2"

    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Updated library field for {len(sentences)} sentences.")


if __name__ == "__main__":
    main()
