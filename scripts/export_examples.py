#!/usr/bin/env python3
import json
import re
from pathlib import Path


LEMMA_LINE_RE = re.compile(r'^\s*"([^"]+)"\s*:\s*\[\s*$')


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


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    examples_path = root / "LearnLanguageLikeABaby" / "Resources" / "exampleSentences_fr.json"
    output_path = root / "examples_review.txt"

    raw = examples_path.read_text(encoding="utf-8")

    examples_by_lemma: dict[str, list[dict]]
    try:
        data = json.loads(raw)
        examples_by_lemma = data.get("examples_by_lemma", {})
    except json.JSONDecodeError:
        examples_by_lemma = parse_examples_fallback(raw)

    lines: list[str] = []
    lemma_count = 0
    sentence_count = 0

    for lemma in sorted(examples_by_lemma.keys()):
        items = examples_by_lemma.get(lemma, [])
        lemma_count += 1
        lines.append(f"[{lemma}]")
        for i, sentence in enumerate(items, start=1):
            text = sentence.get("text", "")
            translation = sentence.get("translation", "")
            lines.append(f"  {i}. {text}")
            lines.append(f"     {translation}")
            sentence_count += 1
        lines.append("")

    output_path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    print(f"Exported {lemma_count} lemmas and {sentence_count} example sentences to {output_path}")


if __name__ == "__main__":
    main()
