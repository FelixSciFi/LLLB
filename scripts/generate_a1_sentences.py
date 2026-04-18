#!/usr/bin/env python3
import json
import re
from pathlib import Path
from typing import Optional


WORD_IPA = {
    "un": "œ̃", "deux": "dø", "trois": "tʁwa", "quatre": "katʁ", "cinq": "sɛ̃k", "dix": "dis", "vingt": "vɛ̃", "cent": "sɑ̃",
    "rouge": "ʁuʒ", "bleu": "blø", "vert": "vɛʁ", "jaune": "ʒon", "blanc": "blɑ̃", "noir": "nwaʁ", "rose": "ʁoz", "orange": "ɔʁɑ̃ʒ",
    "pain": "pɛ̃", "eau": "o", "lait": "lɛ", "café": "kafe", "pomme": "pɔm", "banane": "banan", "riz": "ʁi", "poulet": "pulɛ", "poisson": "pwasɔ̃",
    "chat": "ʃa", "chien": "ʃjɛ̃", "oiseau": "wazo", "cheval": "ʃəval", "vache": "vaʃ",
    "tête": "tɛt", "main": "mɛ̃", "pied": "pje", "œil": "œj", "bouche": "buʃ", "bras": "bʁa", "jambe": "ʒɑ̃b",
    "maman": "mamɑ̃", "papa": "papa", "frère": "fʁɛʁ", "sœur": "sœʁ", "bébé": "bebe", "famille": "famij",
    "livre": "livʁ", "stylo": "stilo", "table": "tabl", "chaise": "ʃɛz", "sac": "sak", "téléphone": "telefɔn", "clé": "kle", "porte": "pɔʁt",
    "je": "ʒə", "j'aime": "ʒɛm", "mange": "mɑ̃ʒ", "bois": "bwa", "dors": "dɔʁ", "marche": "maʁʃ", "parle": "paʁl", "veux": "vø", "suis": "sɥi",
    "grand": "gʁɑ̃", "petit": "pəti", "chaud": "ʃo", "froid": "fʁwa", "bon": "bɔ̃", "mauvais": "movɛ", "beau": "bo", "nouveau": "nuvo",
    "une": "yn", "le": "lə", "la": "la", "les": "le", "est": "ɛ", "sont": "sɔ̃", "sur": "syʁ", "dans": "dɑ̃", "avec": "avɛk",
    "mon": "mɔ̃", "ma": "ma", "ton": "tɔ̃", "ta": "ta", "de": "də", "du": "dy", "et": "e", "très": "tʁɛ", "ici": "isi", "voici": "vwasi",
}

WORD_TRANSLATION = {
    "un": "一", "deux": "二", "trois": "三", "quatre": "四", "cinq": "五", "dix": "十", "vingt": "二十", "cent": "一百",
    "rouge": "红色", "bleu": "蓝色", "vert": "绿色", "jaune": "黄色", "blanc": "白色", "noir": "黑色", "rose": "粉色", "orange": "橙色",
    "pain": "面包", "eau": "水", "lait": "牛奶", "café": "咖啡", "pomme": "苹果", "banane": "香蕉", "riz": "米饭", "poulet": "鸡肉", "poisson": "鱼",
    "chat": "猫", "chien": "狗", "oiseau": "鸟", "cheval": "马", "vache": "奶牛",
    "tête": "头", "main": "手", "pied": "脚", "œil": "眼睛", "bouche": "嘴", "bras": "手臂", "jambe": "腿",
    "maman": "妈妈", "papa": "爸爸", "frère": "哥哥/弟弟", "sœur": "姐姐/妹妹", "bébé": "宝宝", "famille": "家庭",
    "livre": "书", "stylo": "笔", "table": "桌子", "chaise": "椅子", "sac": "包", "téléphone": "手机", "clé": "钥匙", "porte": "门",
    "grand": "大的", "petit": "小的", "chaud": "热的", "froid": "冷的", "bon": "好的", "mauvais": "不好的", "beau": "漂亮的", "nouveau": "新的",
}

NOUN_EMOJI = {
    "pain": "🍞", "eau": "💧", "lait": "🥛", "café": "☕", "pomme": "🍎", "orange": "🍊", "banane": "🍌",
    "riz": "🍚", "poulet": "🍗", "poisson": "🐟", "chat": "🐱", "chien": "🐶", "oiseau": "🐦", "cheval": "🐴", "vache": "🐮",
    "tête": "🧠", "main": "✋", "pied": "🦶", "œil": "👁️", "bouche": "👄", "bras": "💪", "jambe": "🦵",
    "maman": "👩", "papa": "👨", "frère": "👦", "sœur": "👧", "bébé": "👶", "famille": "👨‍👩‍👧‍👦",
    "livre": "📘", "stylo": "🖊️", "table": "🪑", "chaise": "🪑", "sac": "👜", "téléphone": "📱", "clé": "🔑", "porte": "🚪",
}


def words(text: str) -> list[str]:
    return re.findall(r"[A-Za-zÀ-ÿœŒ']+", text.lower())


def ipa_for_text(text: str) -> str:
    out = []
    for w in words(text):
        out.append(WORD_IPA.get(w, w))
    return " ".join(out)


def lemma_for_chunk(chunk: str) -> Optional[str]:
    ws = words(chunk)
    for w in reversed(ws):
        if w in WORD_TRANSLATION or w in NOUN_EMOJI:
            return w
    return ws[-1] if ws else None


def token_translation(chunk: str) -> str:
    ws = words(chunk)
    for w in reversed(ws):
        if w in WORD_TRANSLATION:
            return WORD_TRANSLATION[w]
    return ""


def token_emoji(chunk: str) -> tuple[bool, str]:
    ws = words(chunk)
    for w in reversed(ws):
        if w in NOUN_EMOJI:
            return True, NOUN_EMOJI[w]
    return False, ""


def make_tokens(chunks: list[str]) -> list[dict]:
    toks = []
    for c in chunks:
        has_img, emoji = token_emoji(c)
        toks.append(
            {
                "text": c,
                "lemma": lemma_for_chunk(c),
                "hasImage": has_img,
                "emoji": emoji,
                "ipa": ipa_for_text(c),
                "translation": token_translation(c),
            }
        )
    return toks


def make_sentence(idx: int, text: str, translation: str, chunks: list[str]) -> dict:
    return {
        "id": f"a1_{idx:03d}",
        "library": "A1",
        "text": text,
        "ipa": ipa_for_text(text),
        "translation": translation,
        "tokens": make_tokens(chunks),
    }


def build_sentences() -> list[dict]:
    s: list[dict] = []
    i = 1

    numbers = [("un", "一"), ("deux", "二"), ("trois", "三"), ("quatre", "四"), ("cinq", "五"), ("dix", "十"), ("vingt", "二十"), ("cent", "一百")]
    colors = [("rouge", "红色"), ("bleu", "蓝色"), ("vert", "绿色"), ("jaune", "黄色"), ("blanc", "白色"), ("noir", "黑色"), ("rose", "粉色"), ("orange", "橙色")]
    foods = [("pain", "面包"), ("eau", "水"), ("lait", "牛奶"), ("café", "咖啡"), ("pomme", "苹果"), ("orange", "橙子"), ("banane", "香蕉"), ("riz", "米饭"), ("poulet", "鸡肉"), ("poisson", "鱼")]
    animals = [("chat", "猫"), ("chien", "狗"), ("oiseau", "鸟"), ("poisson", "鱼"), ("cheval", "马"), ("vache", "奶牛")]
    body = [("tête", "头"), ("main", "手"), ("pied", "脚"), ("œil", "眼睛"), ("bouche", "嘴"), ("bras", "手臂"), ("jambe", "腿")]
    family = [("maman", "妈妈"), ("papa", "爸爸"), ("frère", "兄弟"), ("sœur", "姐妹"), ("bébé", "宝宝"), ("famille", "家庭")]
    objects = [("livre", "书"), ("stylo", "笔"), ("table", "桌子"), ("chaise", "椅子"), ("sac", "包"), ("téléphone", "手机"), ("clé", "钥匙"), ("porte", "门")]
    verbs = [("je mange", "我吃"), ("je bois", "我喝"), ("je dors", "我睡觉"), ("je marche", "我走路"), ("je parle", "我说话"), ("j'aime", "我喜欢"), ("je veux", "我想要")]
    adjs = [("grand", "大的"), ("petit", "小的"), ("chaud", "热的"), ("froid", "冷的"), ("bon", "好的"), ("mauvais", "不好的"), ("beau", "漂亮的"), ("nouveau", "新的")]
    color_nouns = [("un chat noir", "一只黑猫"), ("une robe rouge", "一条红裙子"), ("un sac bleu", "一个蓝色包")]

    for fr, zh in numbers:
        s.append(make_sentence(i, f"Je vois {fr}.", f"我看到{zh}。", ["Je vois", fr])); i += 1
        s.append(make_sentence(i, f"C'est {fr}.", f"这是{zh}。", ["C'est", fr])); i += 1
        s.append(make_sentence(i, f"J'ai {fr} livres.", f"我有{zh}本书。", ["J'ai", f"{fr} livres"])); i += 1

    for fr, zh in colors:
        s.append(make_sentence(i, f"C'est {fr}.", f"这是{zh}。", ["C'est", fr])); i += 1
        s.append(make_sentence(i, f"Le sac est {fr}.", f"包是{zh}的。", ["Le sac", "est", fr])); i += 1
        s.append(make_sentence(i, f"J'aime le {fr}.", f"我喜欢{zh}。", ["J'aime", f"le {fr}"])); i += 1

    for fr, zh in foods:
        s.append(make_sentence(i, f"Je mange du {fr}.", f"我吃{zh}。", ["Je mange", f"du {fr}"])); i += 1
        s.append(make_sentence(i, f"Voici le {fr}.", f"这是{zh}。", ["Voici", f"le {fr}"])); i += 1
        s.append(make_sentence(i, f"Le {fr} est bon.", f"{zh}很好。", [f"Le {fr}", "est bon"])); i += 1

    for fr, zh in animals:
        s.append(make_sentence(i, f"Le {fr} est ici.", f"{zh}在这里。", [f"Le {fr}", "est ici"])); i += 1
        s.append(make_sentence(i, f"J'aime le {fr}.", f"我喜欢{zh}。", ["J'aime", f"le {fr}"])); i += 1
        s.append(make_sentence(i, f"Un {fr} marche.", f"一只{zh}在走。", [f"Un {fr}", "marche"])); i += 1

    for fr, zh in body:
        s.append(make_sentence(i, f"Ma {fr} va bien.", f"我的{zh}很好。", [f"Ma {fr}", "va bien"])); i += 1
        s.append(make_sentence(i, f"J'ai mal à la {fr}.", f"我{zh}疼。", ["J'ai mal", f"à la {fr}"])); i += 1
        s.append(make_sentence(i, f"Je lave ma {fr}.", f"我洗我的{zh}。", ["Je lave", f"ma {fr}"])); i += 1

    for fr, zh in family:
        s.append(make_sentence(i, f"Ma {fr} est là.", f"我的{zh}在那儿。", [f"Ma {fr}", "est là"])); i += 1
        s.append(make_sentence(i, f"Je parle à mon {fr}.", f"我和我的{zh}说话。", ["Je parle", f"à mon {fr}"])); i += 1
        s.append(make_sentence(i, f"J'aime ma {fr}.", f"我爱我的{zh}。", ["J'aime", f"ma {fr}"])); i += 1

    for fr, zh in objects:
        s.append(make_sentence(i, f"Le {fr} est sur la table.", f"{zh}在桌子上。", [f"Le {fr}", "est sur", "la table"])); i += 1
        s.append(make_sentence(i, f"Je prends le {fr}.", f"我拿{zh}。", ["Je prends", f"le {fr}"])); i += 1
        s.append(make_sentence(i, f"Mon {fr} est nouveau.", f"我的{zh}是新的。", [f"Mon {fr}", "est nouveau"])); i += 1

    for fr, zh in verbs:
        s.append(make_sentence(i, f"{fr} ici.", f"{zh}在这里。", [fr, "ici"])); i += 1
        s.append(make_sentence(i, f"{fr} avec papa.", f"{zh}和爸爸一起。", [fr, "avec papa"])); i += 1
        s.append(make_sentence(i, f"Aujourd'hui, {fr}.", f"今天，{zh}。", ["Aujourd'hui", fr])); i += 1

    for fr, zh in adjs:
        s.append(make_sentence(i, f"Le sac est {fr}.", f"包是{zh}的。", ["Le sac", "est", fr])); i += 1
        s.append(make_sentence(i, f"Ce livre est {fr}.", f"这本书{zh}。", ["Ce livre", "est", fr])); i += 1
        s.append(make_sentence(i, f"Le chien est très {fr}.", f"这只狗很{zh}。", ["Le chien", "est très", fr])); i += 1

    for fr, zh in color_nouns:
        s.append(make_sentence(i, f"{fr} est beau.", f"{zh}很漂亮。", [fr, "est beau"])); i += 1
        s.append(make_sentence(i, f"Je vois {fr}.", f"我看见{zh}。", ["Je vois", fr])); i += 1
        s.append(make_sentence(i, f"J'aime {fr}.", f"我喜欢{zh}。", ["J'aime", fr])); i += 1

    extra = [
        ("Il y a un chat et un chien.", "有一只猫和一只狗。", ["Il y a", "un chat", "et un chien"]),
        ("Je veux un café chaud.", "我想要一杯热咖啡。", ["Je veux", "un café", "chaud"]),
        ("Je bois de l'eau froide.", "我喝冷水。", ["Je bois", "de l'eau", "froide"]),
        ("Le bébé dort sur la chaise.", "宝宝在椅子上睡觉。", ["Le bébé", "dort sur", "la chaise"]),
        ("Ma famille mange du riz.", "我家人吃米饭。", ["Ma famille", "mange", "du riz"]),
        ("Le téléphone est sur la table.", "手机在桌子上。", ["Le téléphone", "est sur", "la table"]),
        ("Je prends la clé de la porte.", "我拿门钥匙。", ["Je prends", "la clé", "de la porte"]),
        ("Le poulet est bon aujourd'hui.", "今天鸡肉很好。", ["Le poulet", "est bon", "aujourd'hui"]),
        ("Le poisson est dans le sac.", "鱼在包里。", ["Le poisson", "est dans", "le sac"]),
        ("J'aime le lait et le pain.", "我喜欢牛奶和面包。", ["J'aime", "le lait", "et le pain"]),
    ]
    while len(s) < 150:
        t = extra[(len(s) - 1) % len(extra)]
        s.append(make_sentence(i, t[0], t[1], t[2]))
        i += 1

    return s[:150]


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    path = root / "LearnLanguageLikeABaby" / "Resources" / "sentences_fr.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    sentences = data.get("sentences", [])

    sentences = [s for s in sentences if not str(s.get("id", "")).startswith("a1_")]
    a1 = build_sentences()
    data["sentences"] = sentences + a1

    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Added {len(a1)} A1 sentences. Total now: {len(data['sentences'])}")


if __name__ == "__main__":
    main()
