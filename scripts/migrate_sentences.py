#!/usr/bin/env python3
import json
from pathlib import Path
from statistics import mean
from typing import Optional


ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "LearnLanguageLikeABaby" / "Resources"
SENTENCES_IN = RES / "sentences_fr.json"
WORD_TABLE_IN = RES / "word_table_fr.json"
SENTENCES_OUT = RES / "sentences_fr_v2.json"


def normalize_cefr(raw: Optional[str]) -> str:
    if raw == "A1-CDI":
        return "A1"
    if raw:
        return raw
    return "A2"


def main() -> None:
    with SENTENCES_IN.open("r", encoding="utf-8") as f:
        source = json.load(f)
    with WORD_TABLE_IN.open("r", encoding="utf-8") as f:
        word_table = json.load(f)

    rank_map = {w["lemma"]: int(w["rank"]) for w in word_table.get("words", []) if "lemma" in w and "rank" in w}

    migrated_sentences = []
    rank_computed = 0
    rank_default = 0
    default_rank_ids = []

    for s in source.get("sentences", []):
        tokens = []
        token_ranks = []

        for t in s.get("tokens", []):
            token = {
                "text": t.get("text", ""),
                "lemma": t.get("lemma"),
                "emoji": t.get("emoji", ""),
                "ipa": t.get("ipa"),
                "translation": t.get("translation"),
            }
            tokens.append(token)

            lemma = token.get("lemma")
            if lemma and lemma in rank_map:
                token_ranks.append(rank_map[lemma])

        if token_ranks:
            sent_rank = max(token_ranks)
            rank_computed += 1
        else:
            sent_rank = 50
            rank_default += 1
            default_rank_ids.append(s.get("id", ""))

        migrated_sentences.append(
            {
                "id": s.get("id", ""),
                "text": s.get("text", ""),
                "ipa": s.get("ipa", ""),
                "translation": s.get("translation", ""),
                "cefr": normalize_cefr(s.get("library")),
                "rank": sent_rank,
                "tokens": tokens,
            }
        )

    out = {"sentences": migrated_sentences}
    with SENTENCES_OUT.open("w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print("=== Migration Summary ===")
    print(f"Input: {SENTENCES_IN}")
    print(f"Output: {SENTENCES_OUT}")
    print(f"Migrated sentences: {len(migrated_sentences)}")
    print(f"Rank computed from word table: {rank_computed}")
    print(f"Rank defaulted to 50: {rank_default}")

    ranks = [s["rank"] for s in migrated_sentences]
    print("\n=== Validation ===")
    print(f"Total sentences: {len(migrated_sentences)}")
    print(f"Rank min/max/avg: {min(ranks)}/{max(ranks)}/{mean(ranks):.2f}")
    print(f"Used default rank=50: {rank_default}")

    print("\nSample 5 entries:")
    for s in migrated_sentences[:5]:
        print(
            f"- text={s['text']} | cefr={s['cefr']} | rank={s['rank']} | tokens={len(s['tokens'])}"
        )

    if default_rank_ids:
        print("\nFirst 10 default-rank IDs:")
        for sid in default_rank_ids[:10]:
            print(f"- {sid}")


if __name__ == "__main__":
    main()
