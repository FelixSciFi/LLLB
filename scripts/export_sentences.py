#!/usr/bin/env python3
import json
from pathlib import Path


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    sentences_path = root / "LearnLanguageLikeABaby" / "Resources" / "sentences_fr.json"
    output_path = root / "sentences_review.txt"

    with sentences_path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    sentences = data.get("sentences", [])

    lines: list[str] = []
    for idx, s in enumerate(sentences, start=1):
        sid = s.get("id", "")
        text = s.get("text", "")
        translation = s.get("translation", "")
        lines.append(f"{idx:03d}. [{sid}]")
        lines.append(text)
        lines.append(translation)
        lines.append("")

    output_path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    print(f"Exported {len(sentences)} sentences to {output_path}")


if __name__ == "__main__":
    main()
