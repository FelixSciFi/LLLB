#!/usr/bin/env python3
"""Append single-word A1-CDI sentences (cdi_word_001…) from word_table_fr.json."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WT_PATH = ROOT / "LearnLanguageLikeABaby" / "Resources" / "word_table_fr.json"
SENT_PATH = ROOT / "LearnLanguageLikeABaby" / "Resources" / "sentences_fr.json"

# Citation-style IPA for the word in isolation (word_table has no ipa field).
IPA_BY_LEMMA: dict[str, str] = {
    "maman": "mamɑ̃",
    "papa": "papa",
    "non": "nɔ̃",
    "oui": "wi",
    "encore": "ɑ̃kɔʁ",
    "bébé": "bebe",
    "chien": "ʃjɛ̃",
    "chat": "ʃa",
    "eau": "o",
    "pain": "pɛ̃",
    "lait": "lɛ",
    "manger": "mɑ̃ʒe",
    "boire": "bwaʁ",
    "dormir": "dɔʁmiʁ",
    "venir": "vəniʁ",
    "partir": "paʁtiʁ",
    "grand": "gʁɑ̃",
    "petit": "pəti",
    "chaud": "ʃo",
    "froid": "fʁwa",
    "bonjour": "bɔ̃ʒuʁ",
    "merci": "mɛʁsi",
    "main": "mɛ̃",
    "pied": "pje",
    "oeil": "œj",
    "bouche": "buʃ",
    "nez": "ne",
    "ventre": "vɑ̃tʁ",
    "pomme": "pɔm",
    "banane": "banan",
    "voiture": "vwatyʁ",
    "balle": "bal",
    "livre": "livʁ",
    "chaussure": "ʃosyʁ",
    "chapeau": "ʃapo",
    "rouge": "ʁuʒ",
    "bleu": "blø",
    "jaune": "ʒon",
    "vert": "vɛʁ",
    "un": "œ̃",
    "deux": "dø",
    "trois": "tʁwa",
    "lune": "lyn",
    "soleil": "sɔlɛj",
    "fleur": "flœʁ",
    "arbre": "aʁbʁ",
    "oiseau": "wazo",
    "poisson": "pwasɔ̃",
    "cheval": "ʃəval",
    "maison": "mɛzɔ̃",
}


def display_form(lemma: str) -> str:
    if lemma == "oeil":
        return "Œil"
    if not lemma:
        return lemma
    # Title case first character, keep rest (bébé → Bébé)
    return lemma[0].upper() + lemma[1:]


def collect_ipa_from_cdi(sentences: list[dict]) -> dict[str, str]:
    """Fallback: first token ipa seen for lemma in A1-CDI."""
    out: dict[str, str] = {}
    for s in sentences:
        if s.get("library") != "A1-CDI":
            continue
        for t in s.get("tokens") or []:
            lem = t.get("lemma")
            ip = t.get("ipa")
            if lem and ip and lem not in out:
                out[lem] = ip
    return out


def main() -> None:
    words = json.loads(WT_PATH.read_text(encoding="utf-8"))["words"]
    data = json.loads(SENT_PATH.read_text(encoding="utf-8"))
    sentences = data["sentences"]

    existing_ids = {s["id"] for s in sentences}
    fallback_ipa = collect_ipa_from_cdi(sentences)

    new_items: list[dict] = []
    for i, w in enumerate(words, start=1):
        lemma = w["lemma"]
        sid = f"cdi_word_{i:03d}"
        if sid in existing_ids:
            raise SystemExit(f"ID clash: {sid}")

        ipa = IPA_BY_LEMMA.get(lemma) or fallback_ipa.get(lemma)
        if not ipa:
            raise SystemExit(f"Missing IPA for lemma {lemma!r}")

        text = display_form(lemma)
        emoji = w.get("emoji") or ""
        translation = w["translation"]
        has_image = bool(emoji)

        new_items.append(
            {
                "id": sid,
                "text": text,
                "ipa": ipa,
                "translation": translation,
                "library": "A1-CDI",
                "core_lemma": lemma,
                "tokens": [
                    {
                        "text": text,
                        "lemma": lemma,
                        "hasImage": has_image,
                        "emoji": emoji,
                        "ipa": ipa,
                        "translation": translation,
                    }
                ],
            }
        )

    before = len(sentences)
    sentences.extend(new_items)
    data["sentences"] = sentences

    SENT_PATH.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    added = len(sentences) - before
    print(f"Appended {added} single-word CDI sentences (total sentences now {len(sentences)}).")


if __name__ == "__main__":
    main()
