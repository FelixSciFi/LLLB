#!/usr/bin/env python3
"""Merge IPA strings (same order as words in word_table_fr.json) into the word table."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WT = ROOT / "LearnLanguageLikeABaby" / "Resources" / "word_table_fr.json"
IPA_LINES = Path(__file__).with_name("_ipas_fr_ordered.txt")


def main() -> None:
    ipas = [ln.strip() for ln in IPA_LINES.read_text(encoding="utf-8").splitlines() if ln.strip()]
    with WT.open(encoding="utf-8") as f:
        data = json.load(f)
    words = data.get("words", [])
    if len(ipas) != len(words):
        raise SystemExit(f"IPA count {len(ipas)} != words {len(words)}")
    for w, ipa in zip(words, ipas):
        w["ipa"] = ipa
    with WT.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"updated {len(words)} ipa fields -> {WT}")


if __name__ == "__main__":
    main()
