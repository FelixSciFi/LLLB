"""
Stage 1 of "every lemma needs ≥ 3 sentences" workstream.

Mechanically extract the unique set of lemmas that appear inside sentences
filtered to CEFR ≤ B2 (HSK1-4 for Chinese). Read-only — does not touch
sentences_*.json. Output goes to tools/lemma_extracted_{lang}.json.

The output is *raw*: it includes everything the corpus claims is a lemma,
including proper nouns, foreign loanwords, and any garbage that slipped
through. Stage 2 (separate script, uses Sonnet) is what filters those out.

No LLM is used here. No CEFR is recorded per-lemma — sentence CEFR is the
only level we trust; lemma-level CEFR is left for sentence-generation time.
"""
import json
from datetime import date
from pathlib import Path


CONFIG = {
    "fr": {"cefr_filter": {"A1", "A2", "B1", "B2"}},
    "en": {"cefr_filter": {"A1", "A2", "B1", "B2"}},
    "zh": {"cefr_filter": {"HSK1", "HSK2", "HSK3", "HSK4"}},
}


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    out_dir = root / "tools"

    for lang, cfg in CONFIG.items():
        src = root / "LearnLanguageLikeABaby" / "Resources" / f"sentences_{lang}.json"
        data = json.loads(src.read_text(encoding="utf-8"))
        sents = data.get("sentences", [])

        cefr_filter = cfg["cefr_filter"]
        lemmas: set[str] = set()
        filtered_count = 0
        for s in sents:
            if s.get("cefr") not in cefr_filter:
                continue
            filtered_count += 1
            for tok in s.get("tokens", []):
                lemma = (tok.get("lemma") or "").strip()
                if lemma:
                    lemmas.add(lemma)

        sorted_lemmas = sorted(lemmas)

        out = {
            "language": lang,
            "source": f"LearnLanguageLikeABaby/Resources/sentences_{lang}.json",
            "cefr_filter": sorted(cefr_filter),
            "extracted_at": str(date.today()),
            "filtered_sentence_count": filtered_count,
            "unique_lemmas": len(sorted_lemmas),
            "lemmas": sorted_lemmas,
            "_note": (
                "Raw mechanical extraction of token.lemma values — proper nouns, "
                "loanwords, and other non-teaching items are still in here. "
                "Stage 2 (LLM-based) is responsible for cleaning the list."
            ),
        }

        out_path = out_dir / f"lemma_extracted_{lang}.json"
        out_path.write_text(
            json.dumps(out, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        print(
            f"{lang}: {filtered_count} sentences (CEFR/HSK ≤ B2/HSK4) "
            f"-> {len(sorted_lemmas):,} unique lemmas "
            f"-> {out_path.relative_to(root)}"
        )


if __name__ == "__main__":
    main()
