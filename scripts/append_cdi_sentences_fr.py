#!/usr/bin/env python3
"""Append CDI French sentences to sentences_fr.json; validate CDI rank rules."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORDS_PATH = ROOT / "LearnLanguageLikeABaby" / "Resources" / "word_table_fr.json"
SENTENCES_PATH = ROOT / "LearnLanguageLikeABaby" / "Resources" / "sentences_fr.json"

# Function lemmas allowed with any core word (whitelist from spec + conjugation helpers).
WHITELIST = {
    "le",
    "la",
    "les",
    "un",
    "une",
    "du",
    "de",
    "des",
    "je",
    "tu",
    "il",
    "elle",
    "être",  # est, c'est
    "et",
    "à",
    "au",
    "ma",
    "mon",
    "plaire",  # s'il vous plaît (not used in CDI set)
}


def tok(text: str, lemma: str, has_image: bool, emoji: str, ipa: str, translation: str) -> dict:
    return {
        "text": text,
        "lemma": lemma,
        "hasImage": has_image,
        "emoji": emoji or "",
        "ipa": ipa,
        "translation": translation,
    }


def sentence(
    sid: str,
    core_lemma: str,
    text: str,
    ipa: str,
    translation: str,
    tokens: list[dict],
) -> dict:
    return {
        "id": sid,
        "text": text,
        "ipa": ipa,
        "translation": translation,
        "tokens": tokens,
        "core_lemma": core_lemma,
        "library": "A1-CDI",
    }


def load_ranks() -> dict[str, int]:
    with WORDS_PATH.open(encoding="utf-8") as f:
        data = json.load(f)
    return {w["lemma"]: w["rank"] for w in data["words"]}


def validate(sentences: list[dict], rank_by_lemma: dict[str, int]) -> None:
    for s in sentences:
        core = s["core_lemma"]
        cr = rank_by_lemma[core]
        for t in s["tokens"]:
            lem = t["lemma"]
            if lem is None:
                raise ValueError(f"{s['id']}: null lemma in token {t!r}")
            if lem == core:
                continue
            if lem in WHITELIST:
                continue
            if lem not in rank_by_lemma:
                raise ValueError(f"{s['id']}: unknown lemma {lem!r}")
            if rank_by_lemma[lem] >= cr:
                raise ValueError(
                    f"{s['id']}: lemma {lem!r} rank {rank_by_lemma[lem]} >= core {core!r} rank {cr}"
                )
        if not (2 <= len(s["tokens"]) <= 3):
            raise ValueError(f"{s['id']}: need 2–3 tokens, got {len(s['tokens'])}")


def build_new_sentences() -> list[dict]:
    # Two sentences per CDI word in rank order; auxiliary lemmas must be lower rank or whitelist.
    return [
        sentence(
            "cdi_001",
            "maman",
            "Ma maman.",
            "ma mamɑ̃",
            "我的妈妈。",
            [
                tok("Ma", "ma", False, "", "ma", "我的"),
                tok(" maman.", "maman", True, "👩", "mamɑ̃", "妈妈。"),
            ],
        ),
        sentence(
            "cdi_002",
            "maman",
            "La maman.",
            "la mamɑ̃",
            "那位妈妈。",
            [
                tok("La", "la", False, "", "la", "那（阴性）"),
                tok(" maman.", "maman", True, "👩", "mamɑ̃", "妈妈。"),
            ],
        ),
        sentence(
            "cdi_003",
            "papa",
            "Mon papa.",
            "mɔ̃ papa",
            "我的爸爸。",
            [
                tok("Mon", "mon", False, "", "mɔ̃", "我的"),
                tok(" papa.", "papa", True, "👨", "papa", "爸爸。"),
            ],
        ),
        sentence(
            "cdi_004",
            "papa",
            "Papa et maman.",
            "papa e mamɑ̃",
            "爸爸和妈妈。",
            [
                tok("Papa", "papa", True, "👨", "papa", "爸爸"),
                tok(" et maman.", "maman", True, "👩", "e mamɑ̃", "和妈妈。"),
            ],
        ),
        sentence(
            "cdi_005",
            "non",
            "Non, maman.",
            "nɔ̃ mamɑ̃",
            "不，妈妈。",
            [
                tok("Non,", "non", False, "", "nɔ̃", "不，"),
                tok(" maman.", "maman", True, "👩", "mamɑ̃", "妈妈。"),
            ],
        ),
        sentence(
            "cdi_006",
            "non",
            "Non, papa.",
            "nɔ̃ papa",
            "不，爸爸。",
            [
                tok("Non,", "non", False, "", "nɔ̃", "不，"),
                tok(" papa.", "papa", True, "👨", "papa", "爸爸。"),
            ],
        ),
        sentence(
            "cdi_007",
            "oui",
            "Oui, maman.",
            "wi mamɑ̃",
            "好的，妈妈。",
            [
                tok("Oui,", "oui", False, "", "wi", "好的，"),
                tok(" maman.", "maman", True, "👩", "mamɑ̃", "妈妈。"),
            ],
        ),
        sentence(
            "cdi_008",
            "oui",
            "Oui, papa.",
            "wi papa",
            "好的，爸爸。",
            [
                tok("Oui,", "oui", False, "", "wi", "好的，"),
                tok(" papa.", "papa", True, "👨", "papa", "爸爸。"),
            ],
        ),
        sentence(
            "cdi_009",
            "encore",
            "Encore, maman.",
            "ɑ̃kɔʁ mamɑ̃",
            "还要，妈妈。",
            [
                tok("Encore,", "encore", False, "", "ɑ̃kɔʁ", "还要，"),
                tok(" maman.", "maman", True, "👩", "mamɑ̃", "妈妈。"),
            ],
        ),
        sentence(
            "cdi_010",
            "encore",
            "Encore, papa.",
            "ɑ̃kɔʁ papa",
            "还要，爸爸。",
            [
                tok("Encore,", "encore", False, "", "ɑ̃kɔʁ", "还要，"),
                tok(" papa.", "papa", True, "👨", "papa", "爸爸。"),
            ],
        ),
        sentence(
            "cdi_011",
            "bébé",
            "Mon bébé.",
            "mɔ̃ bebe",
            "我的宝宝。",
            [
                tok("Mon", "mon", False, "", "mɔ̃", "我的"),
                tok(" bébé.", "bébé", True, "👶", "bebe", "宝宝。"),
            ],
        ),
        sentence(
            "cdi_012",
            "bébé",
            "Bébé et maman.",
            "bebe e mamɑ̃",
            "宝宝和妈妈。",
            [
                tok("Bébé", "bébé", True, "👶", "bebe", "宝宝"),
                tok(" et maman.", "maman", True, "👩", "e mamɑ̃", "和妈妈。"),
            ],
        ),
        sentence(
            "cdi_013",
            "chien",
            "Le chien.",
            "lə ʃjɛ̃",
            "狗。",
            [
                tok("Le", "le", False, "", "lə", "这（阳性）"),
                tok(" chien.", "chien", True, "🐶", "ʃjɛ̃", "狗。"),
            ],
        ),
        sentence(
            "cdi_014",
            "chien",
            "Chien et bébé.",
            "ʃjɛ̃ e bebe",
            "狗和宝宝。",
            [
                tok("Chien", "chien", True, "🐶", "ʃjɛ̃", "狗"),
                tok(" et bébé.", "bébé", True, "👶", "e bebe", "和宝宝。"),
            ],
        ),
        sentence(
            "cdi_015",
            "chat",
            "Le chat.",
            "lə ʃa",
            "猫。",
            [
                tok("Le", "le", False, "", "lə", "这（阳性）"),
                tok(" chat.", "chat", True, "🐱", "ʃa", "猫。"),
            ],
        ),
        sentence(
            "cdi_016",
            "chat",
            "Chat et chien.",
            "ʃa e ʃjɛ̃",
            "猫和狗。",
            [
                tok("Chat", "chat", True, "🐱", "ʃa", "猫"),
                tok(" et chien.", "chien", True, "🐶", "e ʃjɛ̃", "和狗。"),
            ],
        ),
        sentence(
            "cdi_017",
            "eau",
            "De l'eau.",
            "dəl o",
            "（一点）水。",
            [
                tok("De l'", "de", False, "", "dəl", "一点"),
                tok("eau.", "eau", True, "💧", "o", "水。"),
            ],
        ),
        sentence(
            "cdi_018",
            "eau",
            "L'eau, maman.",
            "lo mamɑ̃",
            "水，妈妈。",
            [
                tok("L'eau,", "eau", True, "💧", "lo", "水，"),
                tok(" maman.", "maman", True, "👩", "mamɑ̃", "妈妈。"),
            ],
        ),
        sentence(
            "cdi_019",
            "pain",
            "Du pain.",
            "dy pɛ̃",
            "面包。",
            [
                tok("Du", "du", False, "", "dy", "一些"),
                tok(" pain.", "pain", True, "🍞", "pɛ̃", "面包。"),
            ],
        ),
        sentence(
            "cdi_020",
            "pain",
            "Pain et eau.",
            "pɛ̃ e o",
            "面包和水。",
            [
                tok("Pain", "pain", True, "🍞", "pɛ̃", "面包"),
                tok(" et eau.", "eau", True, "💧", "e o", "和水。"),
            ],
        ),
        sentence(
            "cdi_021",
            "lait",
            "Du lait.",
            "dy lɛ",
            "牛奶。",
            [
                tok("Du", "du", False, "", "dy", "一些"),
                tok(" lait.", "lait", True, "🥛", "lɛ", "牛奶。"),
            ],
        ),
        sentence(
            "cdi_022",
            "lait",
            "Lait et pain.",
            "lɛ e pɛ̃",
            "牛奶和面包。",
            [
                tok("Lait", "lait", True, "🥛", "lɛ", "牛奶"),
                tok(" et pain.", "pain", True, "🍞", "e pɛ̃", "和面包。"),
            ],
        ),
        sentence(
            "cdi_023",
            "manger",
            "Je mange.",
            "ʒə mɑ̃ʒ",
            "我吃。",
            [
                tok("Je", "je", False, "", "ʒə", "我"),
                tok(" mange.", "manger", True, "🍽️", "mɑ̃ʒ", "吃。"),
            ],
        ),
        sentence(
            "cdi_024",
            "manger",
            "Manger du pain.",
            "mɑ̃ʒe dy pɛ̃",
            "吃面包。",
            [
                tok("Manger", "manger", True, "🍽️", "mɑ̃ʒe", "吃"),
                tok(" du pain.", "pain", True, "🍞", "dy pɛ̃", "面包。"),
            ],
        ),
        sentence(
            "cdi_025",
            "boire",
            "Je bois.",
            "ʒə bwa",
            "我喝。",
            [
                tok("Je", "je", False, "", "ʒə", "我"),
                tok(" bois.", "boire", True, "🥤", "bwa", "喝。"),
            ],
        ),
        sentence(
            "cdi_026",
            "boire",
            "Boire de l'eau.",
            "bwaʁ dəl o",
            "喝水。",
            [
                tok("Boire", "boire", True, "🥤", "bwaʁ", "喝"),
                tok(" de l'eau.", "eau", True, "💧", "dəl o", "水。"),
            ],
        ),
        sentence(
            "cdi_027",
            "dormir",
            "Je dors.",
            "ʒə dɔʁ",
            "我睡。",
            [
                tok("Je", "je", False, "", "ʒə", "我"),
                tok(" dors.", "dormir", True, "😴", "dɔʁ", "睡。"),
            ],
        ),
        sentence(
            "cdi_028",
            "dormir",
            "Dormir, maman.",
            "dɔʁmiʁ mamɑ̃",
            "睡觉吧，妈妈。",
            [
                tok("Dormir,", "dormir", True, "😴", "dɔʁmiʁ", "睡觉，"),
                tok(" maman.", "maman", True, "👩", "mamɑ̃", "妈妈。"),
            ],
        ),
        sentence(
            "cdi_029",
            "venir",
            "Viens, maman.",
            "vjɛ̃ mamɑ̃",
            "来吧，妈妈。",
            [
                tok("Viens,", "venir", False, "", "vjɛ̃", "来吧，"),
                tok(" maman.", "maman", True, "👩", "mamɑ̃", "妈妈。"),
            ],
        ),
        sentence(
            "cdi_030",
            "venir",
            "Tu viens, papa?",
            "ty vjɛ̃ papa",
            "你来吗，爸爸？",
            [
                tok("Tu", "tu", False, "", "ty", "你"),
                tok(" viens,", "venir", False, "", "vjɛ̃", "来吗，"),
                tok(" papa?", "papa", True, "👨", "papa", "爸爸？"),
            ],
        ),
        sentence(
            "cdi_031",
            "partir",
            "Pars, maman.",
            "paʁ mamɑ̃",
            "走吧，妈妈。",
            [
                tok("Pars,", "partir", False, "", "paʁ", "走吧，"),
                tok(" maman.", "maman", True, "👩", "mamɑ̃", "妈妈。"),
            ],
        ),
        sentence(
            "cdi_032",
            "partir",
            "Tu pars, papa?",
            "ty paʁ papa",
            "你走吗，爸爸？",
            [
                tok("Tu", "tu", False, "", "ty", "你"),
                tok(" pars,", "partir", False, "", "paʁ", "走吗，"),
                tok(" papa?", "papa", True, "👨", "papa", "爸爸？"),
            ],
        ),
        sentence(
            "cdi_033",
            "grand",
            "Grand bébé.",
            "gʁɑ̃ bebe",
            "大宝宝。",
            [
                tok("Grand", "grand", False, "", "gʁɑ̃", "大的"),
                tok(" bébé.", "bébé", True, "👶", "bebe", "宝宝。"),
            ],
        ),
        sentence(
            "cdi_034",
            "grand",
            "Le grand chien.",
            "lə gʁɑ̃ ʃjɛ̃",
            "大狗。",
            [
                tok("Le grand", "grand", False, "", "lə gʁɑ̃", "大的"),
                tok(" chien.", "chien", True, "🐶", "ʃjɛ̃", "狗。"),
            ],
        ),
        sentence(
            "cdi_035",
            "petit",
            "Petit chat.",
            "pəti ʃa",
            "小猫。",
            [
                tok("Petit", "petit", False, "", "pəti", "小的"),
                tok(" chat.", "chat", True, "🐱", "ʃa", "猫。"),
            ],
        ),
        sentence(
            "cdi_036",
            "petit",
            "Petit bébé.",
            "pəti bebe",
            "小宝宝。",
            [
                tok("Petit", "petit", False, "", "pəti", "小的"),
                tok(" bébé.", "bébé", True, "👶", "bebe", "宝宝。"),
            ],
        ),
        sentence(
            "cdi_037",
            "chaud",
            "C'est chaud.",
            "sɛ ʃo",
            "很烫。",
            [
                tok("C'est", "être", False, "", "sɛ", "很"),
                tok(" chaud.", "chaud", True, "🔥", "ʃo", "烫。"),
            ],
        ),
        sentence(
            "cdi_038",
            "chaud",
            "Pain chaud.",
            "pɛ̃ ʃo",
            "热面包。",
            [
                tok("Pain", "pain", True, "🍞", "pɛ̃", "面包"),
                tok(" chaud.", "chaud", True, "🔥", "ʃo", "热的。"),
            ],
        ),
        sentence(
            "cdi_039",
            "froid",
            "C'est froid.",
            "sɛ fʁwa",
            "很冷。",
            [
                tok("C'est", "être", False, "", "sɛ", "很"),
                tok(" froid.", "froid", True, "❄️", "fʁwa", "冷。"),
            ],
        ),
        sentence(
            "cdi_040",
            "froid",
            "L'eau froide.",
            "lo fʁwad",
            "冷水。",
            [
                tok("L'eau", "eau", True, "💧", "lo", "水"),
                tok(" froide.", "froid", True, "❄️", "fʁwad", "冷的。"),
            ],
        ),
        sentence(
            "cdi_041",
            "bonjour",
            "Bonjour, maman.",
            "bɔ̃ʒuʁ mamɑ̃",
            "你好，妈妈。",
            [
                tok("Bonjour,", "bonjour", False, "", "bɔ̃ʒuʁ", "你好，"),
                tok(" maman.", "maman", True, "👩", "mamɑ̃", "妈妈。"),
            ],
        ),
        sentence(
            "cdi_042",
            "bonjour",
            "Bonjour, papa.",
            "bɔ̃ʒuʁ papa",
            "你好，爸爸。",
            [
                tok("Bonjour,", "bonjour", False, "", "bɔ̃ʒuʁ", "你好，"),
                tok(" papa.", "papa", True, "👨", "papa", "爸爸。"),
            ],
        ),
        sentence(
            "cdi_043",
            "merci",
            "Merci, maman.",
            "mɛʁsi mamɑ̃",
            "谢谢妈妈。",
            [
                tok("Merci,", "merci", False, "", "mɛʁsi", "谢谢，"),
                tok(" maman.", "maman", True, "👩", "mamɑ̃", "妈妈。"),
            ],
        ),
        sentence(
            "cdi_044",
            "merci",
            "Merci, papa.",
            "mɛʁsi papa",
            "谢谢爸爸。",
            [
                tok("Merci,", "merci", False, "", "mɛʁsi", "谢谢，"),
                tok(" papa.", "papa", True, "👨", "papa", "爸爸。"),
            ],
        ),
        sentence(
            "cdi_045",
            "main",
            "Ma main.",
            "ma mɛ̃",
            "我的手。",
            [
                tok("Ma", "ma", False, "", "ma", "我的"),
                tok(" main.", "main", True, "✋", "mɛ̃", "手。"),
            ],
        ),
        sentence(
            "cdi_046",
            "main",
            "La main.",
            "la mɛ̃",
            "手。",
            [
                tok("La", "la", False, "", "la", "这（阴性）"),
                tok(" main.", "main", True, "✋", "mɛ̃", "手。"),
            ],
        ),
        sentence(
            "cdi_047",
            "pied",
            "Mon pied.",
            "mɔ̃ pje",
            "我的脚。",
            [
                tok("Mon", "mon", False, "", "mɔ̃", "我的"),
                tok(" pied.", "pied", True, "🦶", "pje", "脚。"),
            ],
        ),
        sentence(
            "cdi_048",
            "pied",
            "Le pied.",
            "lə pje",
            "脚。",
            [
                tok("Le", "le", False, "", "lə", "这（阳性）"),
                tok(" pied.", "pied", True, "🦶", "pje", "脚。"),
            ],
        ),
        sentence(
            "cdi_049",
            "oeil",
            "Mon œil.",
            "mɔ̃ nœj",
            "我的眼睛。",
            [
                tok("Mon", "mon", False, "", "mɔ̃", "我的"),
                tok(" œil.", "oeil", True, "👁️", "nœj", "眼睛。"),
            ],
        ),
        sentence(
            "cdi_050",
            "oeil",
            "L'œil.",
            "lœj",
            "眼睛。",
            [
                tok("L'", "le", False, "", "l", "这"),
                tok("œil.", "oeil", True, "👁️", "œj", "眼睛。"),
            ],
        ),
        sentence(
            "cdi_051",
            "bouche",
            "Ma bouche.",
            "ma buʃ",
            "我的嘴。",
            [
                tok("Ma", "ma", False, "", "ma", "我的"),
                tok(" bouche.", "bouche", True, "👄", "buʃ", "嘴。"),
            ],
        ),
        sentence(
            "cdi_052",
            "bouche",
            "La bouche.",
            "la buʃ",
            "嘴。",
            [
                tok("La", "la", False, "", "la", "这（阴性）"),
                tok(" bouche.", "bouche", True, "👄", "buʃ", "嘴。"),
            ],
        ),
        sentence(
            "cdi_053",
            "nez",
            "Mon nez.",
            "mɔ̃ ne",
            "我的鼻子。",
            [
                tok("Mon", "mon", False, "", "mɔ̃", "我的"),
                tok(" nez.", "nez", True, "👃", "ne", "鼻子。"),
            ],
        ),
        sentence(
            "cdi_054",
            "nez",
            "Le nez.",
            "lə ne",
            "鼻子。",
            [
                tok("Le", "le", False, "", "lə", "这（阳性）"),
                tok(" nez.", "nez", True, "👃", "ne", "鼻子。"),
            ],
        ),
        sentence(
            "cdi_055",
            "ventre",
            "Mon ventre.",
            "mɔ̃ vɑ̃tʁ",
            "我的肚子。",
            [
                tok("Mon", "mon", False, "", "mɔ̃", "我的"),
                tok(" ventre.", "ventre", False, "", "vɑ̃tʁ", "肚子。"),
            ],
        ),
        sentence(
            "cdi_056",
            "ventre",
            "Le ventre.",
            "lə vɑ̃tʁ",
            "肚子。",
            [
                tok("Le", "le", False, "", "lə", "这（阳性）"),
                tok(" ventre.", "ventre", False, "", "vɑ̃tʁ", "肚子。"),
            ],
        ),
        sentence(
            "cdi_057",
            "pomme",
            "Une pomme.",
            "yn pɔm",
            "一个苹果。",
            [
                tok("Une", "une", False, "", "yn", "一个"),
                tok(" pomme.", "pomme", True, "🍎", "pɔm", "苹果。"),
            ],
        ),
        sentence(
            "cdi_058",
            "pomme",
            "Pomme et pain.",
            "pɔm e pɛ̃",
            "苹果和面包。",
            [
                tok("Pomme", "pomme", True, "🍎", "pɔm", "苹果"),
                tok(" et pain.", "pain", True, "🍞", "e pɛ̃", "和面包。"),
            ],
        ),
        sentence(
            "cdi_059",
            "banane",
            "Une banane.",
            "yn banan",
            "一根香蕉。",
            [
                tok("Une", "une", False, "", "yn", "一根"),
                tok(" banane.", "banane", True, "🍌", "banan", "香蕉。"),
            ],
        ),
        sentence(
            "cdi_060",
            "banane",
            "Banane et pomme.",
            "banan e pɔm",
            "香蕉和苹果。",
            [
                tok("Banane", "banane", True, "🍌", "banan", "香蕉"),
                tok(" et pomme.", "pomme", True, "🍎", "e pɔm", "和苹果。"),
            ],
        ),
        sentence(
            "cdi_061",
            "voiture",
            "La voiture.",
            "la vwatyʁ",
            "汽车。",
            [
                tok("La", "la", False, "", "la", "这（阴性）"),
                tok(" voiture.", "voiture", True, "🚗", "vwatyʁ", "车。"),
            ],
        ),
        sentence(
            "cdi_062",
            "voiture",
            "Ma voiture.",
            "ma vwatyʁ",
            "我的车。",
            [
                tok("Ma", "ma", False, "", "ma", "我的"),
                tok(" voiture.", "voiture", True, "🚗", "vwatyʁ", "车。"),
            ],
        ),
        sentence(
            "cdi_063",
            "balle",
            "La balle.",
            "la bal",
            "球。",
            [
                tok("La", "la", False, "", "la", "这（阴性）"),
                tok(" balle.", "balle", True, "⚽", "bal", "球。"),
            ],
        ),
        sentence(
            "cdi_064",
            "balle",
            "Une balle.",
            "yn bal",
            "一个球。",
            [
                tok("Une", "une", False, "", "yn", "一个"),
                tok(" balle.", "balle", True, "⚽", "bal", "球。"),
            ],
        ),
        sentence(
            "cdi_065",
            "livre",
            "Un livre.",
            "œ̃ livʁ",
            "一本书。",
            [
                tok("Un", "un", False, "", "œ̃", "一本"),
                tok(" livre.", "livre", True, "📚", "livʁ", "书。"),
            ],
        ),
        sentence(
            "cdi_066",
            "livre",
            "Le livre.",
            "lə livʁ",
            "书。",
            [
                tok("Le", "le", False, "", "lə", "这（阳性）"),
                tok(" livre.", "livre", True, "📚", "livʁ", "书。"),
            ],
        ),
        sentence(
            "cdi_067",
            "chaussure",
            "Une chaussure.",
            "yn ʃosyʁ",
            "一只鞋。",
            [
                tok("Une", "une", False, "", "yn", "一只"),
                tok(" chaussure.", "chaussure", True, "👟", "ʃosyʁ", "鞋。"),
            ],
        ),
        sentence(
            "cdi_068",
            "chaussure",
            "Ma chaussure.",
            "ma ʃosyʁ",
            "我的鞋。",
            [
                tok("Ma", "ma", False, "", "ma", "我的"),
                tok(" chaussure.", "chaussure", True, "👟", "ʃosyʁ", "鞋。"),
            ],
        ),
        sentence(
            "cdi_069",
            "chapeau",
            "Mon chapeau.",
            "mɔ̃ ʃapo",
            "我的帽子。",
            [
                tok("Mon", "mon", False, "", "mɔ̃", "我的"),
                tok(" chapeau.", "chapeau", True, "🎩", "ʃapo", "帽子。"),
            ],
        ),
        sentence(
            "cdi_070",
            "chapeau",
            "Le chapeau.",
            "lə ʃapo",
            "帽子。",
            [
                tok("Le", "le", False, "", "lə", "这（阳性）"),
                tok(" chapeau.", "chapeau", True, "🎩", "ʃapo", "帽子。"),
            ],
        ),
        sentence(
            "cdi_071",
            "rouge",
            "C'est rouge.",
            "sɛ ʁuʒ",
            "是红色的。",
            [
                tok("C'est", "être", False, "", "sɛ", "是"),
                tok(" rouge.", "rouge", True, "🔴", "ʁuʒ", "红色。"),
            ],
        ),
        sentence(
            "cdi_072",
            "rouge",
            "Pomme rouge.",
            "pɔm ʁuʒ",
            "红苹果。",
            [
                tok("Pomme", "pomme", True, "🍎", "pɔm", "苹果"),
                tok(" rouge.", "rouge", True, "🔴", "ʁuʒ", "红的。"),
            ],
        ),
        sentence(
            "cdi_073",
            "bleu",
            "C'est bleu.",
            "sɛ blø",
            "是蓝色的。",
            [
                tok("C'est", "être", False, "", "sɛ", "是"),
                tok(" bleu.", "bleu", True, "🔵", "blø", "蓝色。"),
            ],
        ),
        sentence(
            "cdi_074",
            "bleu",
            "Bleu et rouge.",
            "blø e ʁuʒ",
            "蓝和红。",
            [
                tok("Bleu", "bleu", True, "🔵", "blø", "蓝色"),
                tok(" et rouge.", "rouge", True, "🔴", "e ʁuʒ", "和红色。"),
            ],
        ),
        sentence(
            "cdi_075",
            "jaune",
            "C'est jaune.",
            "sɛ ʒon",
            "是黄色的。",
            [
                tok("C'est", "être", False, "", "sɛ", "是"),
                tok(" jaune.", "jaune", True, "🟡", "ʒon", "黄色。"),
            ],
        ),
        sentence(
            "cdi_076",
            "jaune",
            "Banane jaune.",
            "banan ʒon",
            "黄香蕉。",
            [
                tok("Banane", "banane", True, "🍌", "banan", "香蕉"),
                tok(" jaune.", "jaune", True, "🟡", "ʒon", "黄的。"),
            ],
        ),
        sentence(
            "cdi_077",
            "vert",
            "C'est vert.",
            "sɛ vɛʁ",
            "是绿色的。",
            [
                tok("C'est", "être", False, "", "sɛ", "是"),
                tok(" vert.", "vert", True, "🟢", "vɛʁ", "绿色。"),
            ],
        ),
        sentence(
            "cdi_078",
            "vert",
            "Vert et jaune.",
            "vɛʁ e ʒon",
            "绿和黄。",
            [
                tok("Vert", "vert", True, "🟢", "vɛʁ", "绿色"),
                tok(" et jaune.", "jaune", True, "🟡", "e ʒon", "和黄色。"),
            ],
        ),
        sentence(
            "cdi_079",
            "un",
            "Un chat.",
            "œ̃ ʃa",
            "一只猫。",
            [
                tok("Un", "un", False, "", "œ̃", "一只"),
                tok(" chat.", "chat", True, "🐱", "ʃa", "猫。"),
            ],
        ),
        sentence(
            "cdi_080",
            "un",
            "Un chien.",
            "œ̃ ʃjɛ̃",
            "一只狗。",
            [
                tok("Un", "un", False, "", "œ̃", "一只"),
                tok(" chien.", "chien", True, "🐶", "ʃjɛ̃", "狗。"),
            ],
        ),
        sentence(
            "cdi_081",
            "deux",
            "Deux chats.",
            "dø ʃa",
            "两只猫。",
            [
                tok("Deux", "deux", True, "2️⃣", "dø", "两个"),
                tok(" chats.", "chat", True, "🐱", "ʃa", "猫。"),
            ],
        ),
        sentence(
            "cdi_082",
            "deux",
            "Deux chiens.",
            "dø ʃjɛ̃",
            "两只狗。",
            [
                tok("Deux", "deux", True, "2️⃣", "dø", "两个"),
                tok(" chiens.", "chien", True, "🐶", "ʃjɛ̃", "狗。"),
            ],
        ),
        sentence(
            "cdi_083",
            "trois",
            "Trois pommes.",
            "tʁwa pɔm",
            "三个苹果。",
            [
                tok("Trois", "trois", True, "3️⃣", "tʁwa", "三个"),
                tok(" pommes.", "pomme", True, "🍎", "pɔm", "苹果。"),
            ],
        ),
        sentence(
            "cdi_084",
            "trois",
            "Trois balles.",
            "tʁwa bal",
            "三个球。",
            [
                tok("Trois", "trois", True, "3️⃣", "tʁwa", "三个"),
                tok(" balles.", "balle", True, "⚽", "bal", "球。"),
            ],
        ),
        sentence(
            "cdi_085",
            "lune",
            "La lune.",
            "la lyn",
            "月亮。",
            [
                tok("La", "la", False, "", "la", "这（阴性）"),
                tok(" lune.", "lune", True, "🌙", "lyn", "月亮。"),
            ],
        ),
        sentence(
            "cdi_086",
            "lune",
            "C'est la lune.",
            "sɛ la lyn",
            "这是月亮。",
            [
                tok("C'est la", "être", False, "", "sɛ la", "这是"),
                tok(" lune.", "lune", True, "🌙", "lyn", "月亮。"),
            ],
        ),
        sentence(
            "cdi_087",
            "soleil",
            "Le soleil.",
            "lə sɔlɛj",
            "太阳。",
            [
                tok("Le", "le", False, "", "lə", "这（阳性）"),
                tok(" soleil.", "soleil", True, "☀️", "sɔlɛj", "太阳。"),
            ],
        ),
        sentence(
            "cdi_088",
            "soleil",
            "Soleil et lune.",
            "sɔlɛj e lyn",
            "太阳和月亮。",
            [
                tok("Soleil", "soleil", True, "☀️", "sɔlɛj", "太阳"),
                tok(" et lune.", "lune", True, "🌙", "e lyn", "和月亮。"),
            ],
        ),
        sentence(
            "cdi_089",
            "fleur",
            "Une fleur.",
            "yn flœʁ",
            "一朵花。",
            [
                tok("Une", "une", False, "", "yn", "一朵"),
                tok(" fleur.", "fleur", True, "🌸", "flœʁ", "花。"),
            ],
        ),
        sentence(
            "cdi_090",
            "fleur",
            "Fleur rouge.",
            "flœʁ ʁuʒ",
            "红花。",
            [
                tok("Fleur", "fleur", True, "🌸", "flœʁ", "花"),
                tok(" rouge.", "rouge", True, "🔴", "ʁuʒ", "红色的。"),
            ],
        ),
        sentence(
            "cdi_091",
            "arbre",
            "Un arbre.",
            "œ̃ naʁbʁ",
            "一棵树。",
            [
                tok("Un", "un", False, "", "œ̃", "一棵"),
                tok(" arbre.", "arbre", True, "🌳", "naʁbʁ", "树。"),
            ],
        ),
        sentence(
            "cdi_092",
            "arbre",
            "Arbre et fleur.",
            "aʁbʁ e flœʁ",
            "树和花。",
            [
                tok("Arbre", "arbre", True, "🌳", "aʁbʁ", "树"),
                tok(" et fleur.", "fleur", True, "🌸", "e flœʁ", "和花。"),
            ],
        ),
        sentence(
            "cdi_093",
            "oiseau",
            "Un oiseau.",
            "œ̃ nwazo",
            "一只鸟。",
            [
                tok("Un", "un", False, "", "œ̃", "一只"),
                tok(" oiseau.", "oiseau", True, "🐦", "nwazo", "鸟。"),
            ],
        ),
        sentence(
            "cdi_094",
            "oiseau",
            "L'oiseau.",
            "lwazo",
            "鸟。",
            [
                tok("L'", "le", False, "", "l", "这"),
                tok("oiseau.", "oiseau", True, "🐦", "wazo", "鸟。"),
            ],
        ),
        sentence(
            "cdi_095",
            "poisson",
            "Un poisson.",
            "œ̃ pwasɔ̃",
            "一条鱼。",
            [
                tok("Un", "un", False, "", "œ̃", "一条"),
                tok(" poisson.", "poisson", True, "🐟", "pwasɔ̃", "鱼。"),
            ],
        ),
        sentence(
            "cdi_096",
            "poisson",
            "Poisson et eau.",
            "pwasɔ̃ e o",
            "鱼和水。",
            [
                tok("Poisson", "poisson", True, "🐟", "pwasɔ̃", "鱼"),
                tok(" et eau.", "eau", True, "💧", "e o", "和水。"),
            ],
        ),
        sentence(
            "cdi_097",
            "cheval",
            "Un cheval.",
            "œ̃ ʃəval",
            "一匹马。",
            [
                tok("Un", "un", False, "", "œ̃", "一匹"),
                tok(" cheval.", "cheval", True, "🐴", "ʃəval", "马。"),
            ],
        ),
        sentence(
            "cdi_098",
            "cheval",
            "Cheval et chien.",
            "ʃəval e ʃjɛ̃",
            "马和狗。",
            [
                tok("Cheval", "cheval", True, "🐴", "ʃəval", "马"),
                tok(" et chien.", "chien", True, "🐶", "e ʃjɛ̃", "和狗。"),
            ],
        ),
        sentence(
            "cdi_099",
            "maison",
            "La maison.",
            "la mɛzɔ̃",
            "房子。",
            [
                tok("La", "la", False, "", "la", "这（阴性）"),
                tok(" maison.", "maison", True, "🏠", "mɛzɔ̃", "房子。"),
            ],
        ),
        sentence(
            "cdi_100",
            "maison",
            "Ma maison.",
            "ma mɛzɔ̃",
            "我的房子。",
            [
                tok("Ma", "ma", False, "", "ma", "我的"),
                tok(" maison.", "maison", True, "🏠", "mɛzɔ̃", "房子。"),
            ],
        ),
    ]


def main() -> None:
    ranks = load_ranks()
    new_items = build_new_sentences()
    validate(new_items, ranks)

    for s in new_items:
        rebuilt = "".join(t["text"] for t in s["tokens"])
        if rebuilt != s["text"]:
            raise ValueError(f"{s['id']}: text mismatch:\n  fields: {s['text']!r}\n  tokens:{rebuilt!r}")

    with SENTENCES_PATH.open(encoding="utf-8") as f:
        data = json.load(f)

    existing_ids = {s["id"] for s in data["sentences"]}
    clashes = [s["id"] for s in new_items if s["id"] in existing_ids]
    if clashes:
        raise SystemExit(f"ID clashes with existing sentences: {clashes}")

    before = len(data["sentences"])
    data["sentences"].extend(new_items)
    with SENTENCES_PATH.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    added = len(data["sentences"]) - before
    print(f"Appended {added} sentences to {SENTENCES_PATH.relative_to(ROOT)} (total now {len(data['sentences'])})")


if __name__ == "__main__":
    main()
