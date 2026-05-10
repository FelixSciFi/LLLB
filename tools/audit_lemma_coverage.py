"""
Stage 3 of "every lemma needs ≥ 3 sentences" workstream.

For each lemma in tools/lemma_clean_{lang}.json, count how many ≤ B2
sentences (HSK1-4 for ZH, but we only do EN+FR here) contain a token
whose lemma matches. Anything < 3 goes into the gap list. Output
lands at tools/lemma_coverage_{lang}.json.

Read-only — does not touch the corpus. No LLM. The next step
(generation) takes this gap list as its work queue.
"""
import json
from collections import defaultdict
from datetime import date
from pathlib import Path


CEFR_FILTER = {
    "en": {"A1", "A2", "B1", "B2"},
    "fr": {"A1", "A2", "B1", "B2"},
}

TARGET_PER_LEMMA = 2


def main() -> None:
    root = Path(__file__).resolve().parent.parent

    for lang in ("en", "fr"):
        clean_path = root / "tools" / f"lemma_clean_{lang}.json"
        sents_path = root / "LearnLanguageLikeABaby" / "Resources" / f"sentences_{lang}.json"

        clean = json.loads(clean_path.read_text(encoding="utf-8"))
        sents_data = json.loads(sents_path.read_text(encoding="utf-8"))

        kept_lemmas: set[str] = set(clean["kept"])
        cefr_set = CEFR_FILTER[lang]

        # lemma -> list of sentence ids (filtered to CEFR ≤ B2)
        coverage: dict[str, list[str]] = defaultdict(list)

        for s in sents_data.get("sentences", []):
            if s.get("cefr") not in cefr_set:
                continue
            sid = s.get("id", "")
            seen_in_this_sentence: set[str] = set()
            for tok in s.get("tokens", []):
                lemma = (tok.get("lemma") or "").strip()
                if not lemma or lemma not in kept_lemmas:
                    continue
                # One sentence counts at most once per lemma — even if the
                # lemma appears in multiple tokens of the same sentence
                # (rare but possible for repeated words).
                if lemma in seen_in_this_sentence:
                    continue
                seen_in_this_sentence.add(lemma)
                coverage[lemma].append(sid)

        # Gap list: lemmas with strictly fewer than TARGET_PER_LEMMA matches.
        # Sorted ascending by current count so smallest gaps surface first
        # (they're the highest-leverage to fix — fewest sentences needed).
        gaps: list[dict] = []
        bucket_counts = {0: 0, 1: 0, 2: 0, "3+": 0}
        for lemma in sorted(kept_lemmas):
            ids = coverage.get(lemma, [])
            n = len(ids)
            if n >= TARGET_PER_LEMMA:
                bucket_counts["3+"] += 1
            else:
                bucket_counts[n] += 1
                gaps.append({
                    "lemma": lemma,
                    "current_count": n,
                    "needs": TARGET_PER_LEMMA - n,
                    "existing_sentence_ids": ids,
                })
        gaps.sort(key=lambda g: (g["current_count"], g["lemma"]))

        out = {
            "language": lang,
            "audited_at": str(date.today()),
            "lemmas_in_scope": len(kept_lemmas),
            "target_sentences_per_lemma": TARGET_PER_LEMMA,
            "buckets": {
                "exactly_0": bucket_counts[0],
                "exactly_1": bucket_counts[1],
                "exactly_2": bucket_counts[2],
                "at_least_3": bucket_counts["3+"],
            },
            "gap_count": len(gaps),
            "gaps": gaps,
            "_note": (
                "Mechanical count, no LLM. existing_sentence_ids are sentence "
                "UUIDs from sentences_*.json — feed them to the generation step "
                "as 'don't duplicate this' context."
            ),
        }

        out_path = root / "tools" / f"lemma_coverage_{lang}.json"
        out_path.write_text(
            json.dumps(out, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        print(
            f"{lang}: scope={len(kept_lemmas):,}  "
            f"0-cov={bucket_counts[0]}  1-cov={bucket_counts[1]}  "
            f"2-cov={bucket_counts[2]}  3+-cov={bucket_counts['3+']:,}  "
            f"-> gaps={len(gaps)}  -> {out_path.relative_to(root)}"
        )


if __name__ == "__main__":
    main()
