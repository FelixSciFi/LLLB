#!/usr/bin/env python3
"""Generate minimal one-token sentences from word_table_fr.json into sentences_fr.json."""

import json
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WT = ROOT / "LearnLanguageLikeABaby" / "Resources" / "word_table_fr.json"
OUT = ROOT / "LearnLanguageLikeABaby" / "Resources" / "sentences_fr.json"


def text_for_display(lemma: str) -> str:
    if not lemma:
        return ""
    return lemma[0].upper() + lemma[1:]


def main() -> None:
    with WT.open("r", encoding="utf-8") as f:
        data = json.load(f)

    words = data.get("words", [])
    sentences = []

    for i, w in enumerate(words, start=1):
        lemma = w.get("lemma", "")
        disp = text_for_display(lemma)
        ipa = w.get("ipa", "") or ""
        sentences.append(
            {
                "id": str(uuid.uuid4()),
                "text": disp,
                "ipa": ipa,
                "translation": w.get("translation", ""),
                "cefr": w.get("cefr", "A1"),
                "rank": w.get("rank", i),
                "tokens": [
                    {
                        "text": disp,
                        "lemma": lemma,
                        "emoji": w.get("emoji", "") or "",
                        "ipa": ipa,
                        "translation": w.get("translation", ""),
                    }
                ],
            }
        )

    out_obj = {"sentences": sentences}
    with OUT.open("w", encoding="utf-8") as f:
        json.dump(out_obj, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"generated {len(sentences)} entries -> {OUT}")


if __name__ == "__main__":
    main()
