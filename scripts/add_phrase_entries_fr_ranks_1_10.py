#!/usr/bin/env python3
"""Append two short phrase entries per word (rank 1–10) to sentences_fr.json. Token metadata matches word_table_fr.json."""

import json
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WT = ROOT / "LearnLanguageLikeABaby" / "Resources" / "word_table_fr.json"
OUT = ROOT / "LearnLanguageLikeABaby" / "Resources" / "sentences_fr.json"


def meta_by_lemma(words: list) -> dict:
    return {w["lemma"]: w for w in words}


def build_token(m: dict, text: str) -> dict:
    return {
        "text": text,
        "lemma": m["lemma"],
        "emoji": m.get("emoji", "") or "",
        "ipa": m.get("ipa", "") or "",
        "translation": m.get("translation", ""),
    }


def make_entry(
    rank: int,
    sentence: str,
    ipa: str,
    translation: str,
    token_specs: list[tuple[str, str]],
    by_lemma: dict,
    by_rank: dict,
) -> dict:
    tokens = [build_token(by_lemma[lemma], text) for text, lemma in token_specs]
    c = "".join(t["text"] for t in tokens)
    if c != sentence:
        raise ValueError(f"token concat {c!r} != sentence {sentence!r}")
    w = by_rank[rank]
    return {
        "id": str(uuid.uuid4()),
        "text": sentence,
        "ipa": ipa,
        "translation": translation,
        "cefr": w.get("cefr", "A1"),
        "rank": rank,
        "tokens": tokens,
    }


def main() -> None:
    words = json.load(WT.open(encoding="utf-8"))["words"]
    by_lemma = meta_by_lemma(words)
    by_rank = {w["rank"]: w for w in words}

    sil = by_rank[7]["lemma"]
    sil_cap = sil[0].upper() + sil[1:]

    rows: list[tuple[int, str, str, str, list[tuple[str, str]]]] = [
        (1, "Bonjour, maman.", "bɔ̃ʒuʁ mamɑ̃", "你好，妈妈。", [("Bonjour,", "bonjour"), (" maman.", "maman")]),
        (1, "Merci, maman.", "mɛʁsi mamɑ̃", "谢谢，妈妈。", [("Merci,", "merci"), (" maman.", "maman")]),
        (2, "Bonjour, papa.", "bɔ̃ʒuʁ papa", "你好，爸爸。", [("Bonjour,", "bonjour"), (" papa.", "papa")]),
        (2, "Merci, papa.", "mɛʁsi papa", "谢谢，爸爸。", [("Merci,", "merci"), (" papa.", "papa")]),
        (3, "Salut, bébé.", "saly bebe", "嗨，宝宝。", [("Salut,", "salut"), (" bébé.", "bébé")]),
        (3, "Bonjour, bébé.", "bɔ̃ʒuʁ bebe", "你好，宝宝。", [("Bonjour,", "bonjour"), (" bébé.", "bébé")]),
        (4, "Oui, merci.", "wi mɛʁsi", "好的，谢谢。", [("Oui,", "oui"), (" merci.", "merci")]),
        (4, "Oui, papa.", "wi papa", "嗯，爸爸。", [("Oui,", "oui"), (" papa.", "papa")]),
        (5, "Non, merci.", "nɔ̃ mɛʁsi", "不用了，谢谢。", [("Non,", "non"), (" merci.", "merci")]),
        (5, "Non, maman.", "nɔ̃ mamɑ̃", "不，妈妈。", [("Non,", "non"), (" maman.", "maman")]),
        (6, "Merci, maman.", "mɛʁsi mamɑ̃", "谢谢，妈妈。", [("Merci,", "merci"), (" maman.", "maman")]),
        (6, "Merci, papa.", "mɛʁsi papa", "谢谢，爸爸。", [("Merci,", "merci"), (" papa.", "papa")]),
        (
            7,
            f"{sil_cap}, maman.",
            "sil tə plɛ mamɑ̃",
            "请，妈妈。",
            [(f"{sil_cap}, ", sil), ("maman.", "maman")],
        ),
        (
            7,
            f"{sil_cap}, papa.",
            "sil tə plɛ papa",
            "请，爸爸。",
            [(f"{sil_cap}, ", sil), ("papa.", "papa")],
        ),
        (8, "Bonjour, maman.", "bɔ̃ʒuʁ mamɑ̃", "你好，妈妈。", [("Bonjour,", "bonjour"), (" maman.", "maman")]),
        (8, "Bonjour, papa.", "bɔ̃ʒuʁ papa", "你好，爸爸。", [("Bonjour,", "bonjour"), (" papa.", "papa")]),
        (9, "Salut, maman.", "saly mamɑ̃", "嗨，妈妈。", [("Salut,", "salut"), (" maman.", "maman")]),
        (9, "Salut, papa.", "saly papa", "嗨，爸爸。", [("Salut,", "salut"), (" papa.", "papa")]),
        (
            10,
            "Au revoir, maman.",
            "o ʁəvwaʁ mamɑ̃",
            "再见，妈妈。",
            [("Au revoir,", "au revoir"), (" maman.", "maman")],
        ),
        (
            10,
            "Au revoir, papa.",
            "o ʁəvwaʁ papa",
            "再见，爸爸。",
            [("Au revoir,", "au revoir"), (" papa.", "papa")],
        ),
    ]

    data = json.load(OUT.open(encoding="utf-8"))
    sentences = data["sentences"]

    for rank, sentence, ipa, translation, specs in rows:
        sentences.append(make_entry(rank, sentence, ipa, translation, specs, by_lemma, by_rank))

    with OUT.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"appended {len(rows)} entries -> {OUT} (total {len(sentences)})")


if __name__ == "__main__":
    main()
