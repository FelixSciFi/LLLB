#!/usr/bin/env python3
"""
Check sentences_fr.json: for library A1 or A1-CDI, every token lemma must be in
word_table_fr.json lemmas ∪ function-word whitelist.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SENTENCES_PATH = ROOT / "LearnLanguageLikeABaby" / "Resources" / "sentences_fr.json"
WORD_TABLE_PATH = ROOT / "LearnLanguageLikeABaby" / "Resources" / "word_table_fr.json"

# From user spec: le/la/les/.../s'il/vous/plaît/...
FUNCTION_WORDS = frozenset(
    """
le la les un une du de des je tu il elle c'est est être a au ma mon et
s'il vous plaît dans sur en à pour avec pas ne qui que se son sa ses leur
ce cet cette mes tes nos vos
""".split()
)


def load_allowed_lemmas() -> set[str]:
    with WORD_TABLE_PATH.open(encoding="utf-8") as f:
        data = json.load(f)
    return {w["lemma"] for w in data["words"]}


def lemma_violations(
    tokens: list[dict], allowed: set[str]
) -> list[str]:
    bad: list[str] = []
    for t in tokens:
        lem = t.get("lemma")
        if lem is None or lem == "":
            continue
        if lem not in allowed:
            bad.append(lem)
    return bad


def main() -> None:
    table_lemmas = load_allowed_lemmas()
    allowed = table_lemmas | FUNCTION_WORDS

    with SENTENCES_PATH.open(encoding="utf-8") as f:
        data = json.load(f)

    checked = 0
    violations: list[tuple[str, str, list[str]]] = []

    for s in data["sentences"]:
        lib = s.get("library")
        if lib not in ("A1", "A1-CDI"):
            continue
        checked += 1
        bad = lemma_violations(s.get("tokens") or [], allowed)
        if bad:
            # unique preserve order
            seen: set[str] = set()
            uniq = []
            for b in bad:
                if b not in seen:
                    seen.add(b)
                    uniq.append(b)
            violations.append((s["id"], s.get("text", ""), uniq))

    for sid, text, lemmas in violations:
        print(f"id: {sid}")
        print(f"  text: {text}")
        print(f"  lemmas_not_allowed: {', '.join(lemmas)}")
        print()

    offending_count = len(violations)
    suggest_remove = [sid for sid, _, _ in violations]

    print("—— summary ——")
    print(f"checked_sentences: {checked}")
    print(f"sentences_with_out_of_vocab: {offending_count}")
    print(f"suggested_remove_ids: {suggest_remove}")


if __name__ == "__main__":
    main()
