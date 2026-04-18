#!/usr/bin/env python3
import json
import re
from pathlib import Path


LEMMA_LINE_RE = re.compile(r'^\s*"([^"]+)"\s*:\s*\[\s*$')
DELETE_PATTERNS = [
    "Je note «",
    "Tu entends «",
    "C'est écrit",
    "Réponse courte",
]


def parse_examples_fallback(raw: str) -> dict[str, list[dict]]:
    """Best-effort parser for partially malformed exampleSentences.json."""
    lines = raw.splitlines()
    result: dict[str, list[dict]] = {}
    i = 0
    while i < len(lines):
        m = LEMMA_LINE_RE.match(lines[i])
        if not m:
            i += 1
            continue

        lemma = m.group(1)
        result.setdefault(lemma, [])
        i += 1

        while i < len(lines):
            stripped = lines[i].strip()
            if stripped.startswith("]"):
                i += 1
                break

            if stripped.startswith("{"):
                obj_lines = [lines[i]]
                depth = lines[i].count("{") - lines[i].count("}")
                i += 1
                while i < len(lines) and depth > 0:
                    obj_lines.append(lines[i])
                    depth += lines[i].count("{") - lines[i].count("}")
                    i += 1

                block = "\n".join(obj_lines).rstrip().rstrip(",")
                try:
                    obj = json.loads(block)
                    if isinstance(obj, dict):
                        result[lemma].append(obj)
                except json.JSONDecodeError:
                    pass
                continue

            i += 1
    return result


def should_delete_sentence(text: str) -> bool:
    return any(p in text for p in DELETE_PATTERNS)


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    path = root / "LearnLanguageLikeABaby" / "Resources" / "exampleSentences_fr.json"
    raw = path.read_text(encoding="utf-8")

    try:
        data = json.loads(raw)
        examples_by_lemma = data.get("examples_by_lemma", {})
    except json.JSONDecodeError:
        examples_by_lemma = parse_examples_fallback(raw)

    cleaned: dict[str, list[dict]] = {}
    total_before = 0
    total_after = 0

    for lemma, sentences in examples_by_lemma.items():
        key = (lemma or "").strip()
        total_before += len(sentences)
        if key == "" or key == "-":
            continue

        kept = []
        for s in sentences:
            text = (s.get("text") or "").strip()
            if should_delete_sentence(text):
                continue
            kept.append(s)

        if kept:
            cleaned[key] = kept
            total_after += len(kept)

    total_deleted = total_before - total_after

    out = {"examples_by_lemma": dict(sorted(cleaned.items(), key=lambda kv: kv[0]))}
    path.write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"Original: {total_before}")
    print(f"Deleted: {total_deleted}")
    print(f"Remaining: {total_after}")


if __name__ == "__main__":
    main()
