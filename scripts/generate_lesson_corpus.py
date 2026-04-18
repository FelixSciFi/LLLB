#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build sentences.json (200+ sentences) and exampleSentences.json (5+ examples per lemma)."""

import copy
import importlib.util
import json
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_S = ROOT / "LearnLanguageLikeABaby" / "Resources" / "sentences.json"
OUT_E = ROOT / "LearnLanguageLikeABaby" / "Resources" / "exampleSentences.json"


def T(text, lemma=None, has_image=False, emoji="", ipa="", zh=""):
    d = {
        "text": text,
        "lemma": lemma,
        "hasImage": bool(has_image),
        "emoji": emoji or "",
        "ipa": ipa if ipa else "",
        "translation": zh if zh else "",
    }
    return d


def S(sid, text, ipa, zh, parts):
    tokens = [T(*p) if isinstance(p, tuple) and len(p) == 6 else T(**p) for p in parts]
    joined = "".join(t["text"] for t in tokens)
    assert joined == text, (sid, repr(joined), repr(text))
    return {"id": str(sid), "text": text, "ipa": ipa, "translation": zh, "tokens": tokens}


# Each tuple: (id, text, ipa, zh, list of 6-tuples (text, lemma, has_img, emoji, ipa, zh_trans))
RAW: list[tuple] = []

# --- 1. Supermarché (20) ---
RAW += [
    ("sm01", "Je voudrais du pain, s'il vous plaît.", "ʒə vudʁɛ dy pɛ̃ sil vu plɛ", "我想要一些面包，谢谢。", [
        ("Je voudrais ", "vouloir", 0, "", "ʒə vudʁɛ ", "我想要"),
        ("du pain", "pain", 1, "🍞", "dy pɛ̃", "面包"),
        (", s'il vous plaît.", None, 0, "", ", sil vu plɛ.", "请"),
    ]),
    ("sm02", "Où se trouve le rayon des fruits ?", "u sə tʁuv lə ʁɛjɔ̃ de fʁɥi", "水果区在哪里？", [
        ("Où se trouve ", "trouver", 0, "", "u sə tʁuv ", "在哪里"),
        ("le rayon ", "rayon", 0, "", "lə ʁɛjɔ̃ ", "货架"),
        ("des fruits", "fruit", 1, "🍎", "de fʁɥi", "水果"),
        (" ?", None, 0, "", " ?", ""),
    ]),
    ("sm03", "Je prends un kilo de pommes.", "ʒə pʁɑ̃ ɛ̃ kilo də pɔm", "我买一公斤苹果。", [
        ("Je prends ", "prendre", 0, "", "ʒə pʁɑ̃ ", "我买"),
        ("un kilo ", "kilo", 0, "", "ɛ̃ kilo ", "一公斤"),
        ("de pommes", "pomme", 1, "🍎", "də pɔm", "苹果"),
        (".", None, 0, "", "", ""),
    ]),
    ("sm04", "Le lait est en promotion aujourd'hui.", "lə lɛ ɛt ɑ̃ pʁomɔsjɔ̃ oʒuʁdɥi", "牛奶今天促销。", [
        ("Le lait ", "lait", 1, "🥛", "lə lɛ ", "牛奶"),
        ("est en promotion ", "promotion", 0, "", "ɛt ɑ̃ pʁomɔsjɔ̃ ", "促销"),
        ("aujourd'hui", None, 0, "", "oʒuʁdɥi", "今天"),
        (".", None, 0, "", "", ""),
    ]),
    ("sm05", "Passez devant la caisse trois, s'il vous plaît.", "pase dəvɑ̃ la sɛs tʁwa sil vu plɛ", "请到三号收银台。", [
        ("Passez devant ", "passer", 0, "", "pase dəvɑ̃ ", "请到前面"),
        ("la caisse ", "caisse", 1, "🧾", "la sɛs ", "收银台"),
        ("trois", None, 0, "3️⃣", "tʁwa", "三"),
        (", s'il vous plaît.", None, 0, "", ", sil vu plɛ.", "请"),
    ]),
    ("sm06", "Je cherche le fromage râpé.", "ʒə ʃɛʁʃ lə fʁɔmaʒ ʁape", "我找擦碎的奶酪。", [
        ("Je cherche ", "chercher", 0, "", "ʒə ʃɛʁʃ ", "我找"),
        ("le fromage ", "fromage", 1, "🧀", "lə fʁɔmaʒ ", "奶酪"),
        ("râpé", None, 0, "", "ʁape", "擦碎"),
        (".", None, 0, "", "", ""),
    ]),
    ("sm07", "Les légumes frais sont là-bas.", "le leʒym fʁɛ sɔ̃ la ba", "新鲜蔬菜在那边。", [
        ("Les légumes ", "légume", 1, "🥬", "le leʒym ", "蔬菜"),
        ("frais ", None, 0, "", "fʁɛ ", "新鲜"),
        ("sont là-bas", "être", 0, "", "sɔ̃ la ba", "在那边"),
        (".", None, 0, "", "", ""),
    ]),
    ("sm08", "Un sac réutilisable, c'est combien ?", "œ̃ sak ʁeytilizabl sɛ kɔ̃bjɛ̃", "环保袋多少钱？", [
        ("Un sac ", "sac", 1, "🛍️", "œ̃ sak ", "袋子"),
        ("réutilisable", None, 0, "", "ʁeytilizabl", "可重复使用"),
        (", c'est combien", "combien", 0, "", ", sɛ kɔ̃bjɛ̃", "多少钱"),
        (" ?", None, 0, "", " ?", ""),
    ]),
    ("sm09", "Je vais à la boucherie pour de la viande.", "ʒə vɛ a la buʃʁi puʁ də la vjɑ̃d", "我去肉铺买肉。", [
        ("Je vais ", "aller", 0, "", "ʒə vɛ ", "我去"),
        ("à la boucherie ", "boucherie", 1, "🥩", "a la buʃʁi ", "肉铺"),
        ("pour de la viande", "viande", 0, "", "puʁ də la vjɑ̃d", "买肉"),
        (".", None, 0, "", "", ""),
    ]),
    ("sm10", "Avez-vous du poisson congelé ?", "ave vu dy pwasɔ̃ kɔ̃ʒele", "有冷冻鱼吗？", [
        ("Avez-vous ", "avoir", 0, "", "ave vu ", "您有"),
        ("du poisson ", "poisson", 1, "🐟", "dy pwasɔ̃ ", "鱼"),
        ("congelé", None, 0, "", "kɔ̃ʒele", "冷冻"),
        (" ?", None, 0, "", " ?", ""),
    ]),
    ("sm11", "Le chariot est près de l'entrée.", "lə ʃaʁjo ɛ pʁɛ də lɑ̃tʁe", "手推车在入口旁。", [
        ("Le chariot ", "chariot", 1, "🛒", "lə ʃaʁjo ", "手推车"),
        ("est près de ", "près", 0, "", "ɛ pʁɛ də ", "在附近"),
        ("l'entrée", "entrée", 0, "", "lɑ̃tʁe", "入口"),
        (".", None, 0, "", "", ""),
    ]),
    ("sm12", "Combien coûte cette bouteille d'eau ?", "kɔ̃bjɛ̃ kut sɛt butɛj do", "这瓶水多少钱？", [
        ("Combien coûte ", "coûter", 0, "", "kɔ̃bjɛ̃ kut ", "多少钱"),
        ("cette bouteille ", "bouteille", 1, "🧴", "sɛt butɛj ", "这瓶"),
        ("d'eau", "eau", 1, "💧", "do", "水"),
        (" ?", None, 0, "", " ?", ""),
    ]),
    ("sm13", "Je dois acheter du riz et des pâtes.", "ʒə dwa aʃte dy ʁi e de pɑt", "我要买米和意面。", [
        ("Je dois ", "devoir", 0, "", "ʒə dwa ", "我要"),
        ("acheter ", "acheter", 0, "", "aʃte ", "买"),
        ("du riz ", "riz", 1, "🍚", "dy ʁi ", "米"),
        ("et des pâtes", "pâte", 1, "🍝", "e de pɑt", "和意面"),
        (".", None, 0, "", "", ""),
    ]),
    ("sm14", "La liste de courses est sur mon téléphone.", "la list də kuʁs ɛ syʁ mɔ̃ telefɔn", "购物清单在手机上。", [
        ("La liste ", "liste", 1, "📝", "la list ", "清单"),
        ("de courses ", "course", 0, "", "də kuʁs ", "购物"),
        ("est sur mon téléphone", "téléphone", 1, "📱", "ɛ syʁ mɔ̃ telefɔn", "在手机上"),
        (".", None, 0, "", "", ""),
    ]),
    ("sm15", "Merci, gardez la monnaie.", "mɛʁsi gaʁde la mɔnɛ", "谢谢，不用找零。", [
        ("Merci", None, 0, "", "mɛʁsi", "谢谢"),
        (", gardez la monnaie", "monnaie", 0, "", ", gaʁde la mɔnɛ", "留着零钱"),
        (".", None, 0, "", "", ""),
    ]),
    ("sm16", "Où est le rayon surgelés ?", "u ɛ lə ʁɛjɔ̃ syʁʒele", "冷冻区在哪？", [
        ("Où est ", "être", 0, "", "u ɛ ", "在哪"),
        ("le rayon ", "rayon", 0, "", "lə ʁɛjɔ̃ ", "区域"),
        ("surgelés", "surgelé", 1, "🧊", "syʁʒele", "冷冻食品"),
        (" ?", None, 0, "", " ?", ""),
    ]),
    ("sm17", "Je préfère les yaourts nature.", "ʒə pʁefɛʁ le jauʁ natyʁ", "我更喜欢原味酸奶。", [
        ("Je préfère ", "préférer", 0, "", "ʒə pʁefɛʁ ", "我更喜欢"),
        ("les yaourts ", "yaourt", 1, "🥛", "le jauʁ ", "酸奶"),
        ("nature", None, 0, "", "natyʁ", "原味"),
        (".", None, 0, "", "", ""),
    ]),
    ("sm18", "Puis-je payer par carte ?", "pɥiʒə peje pa kaʁt", "可以刷卡吗？", [
        ("Puis-je payer ", "payer", 0, "", "pɥiʒə peje ", "我能付"),
        ("par carte", "carte", 1, "💳", "pa kaʁt", "用卡"),
        (" ?", None, 0, "", " ?", ""),
    ]),
    ("sm19", "Le supermarché ferme à vingt heures.", "lə sypeʁmaʁʃe fɛʁm a vɛ̃t œʁ", "超市八点关门。", [
        ("Le supermarché ", "supermarché", 1, "🏪", "lə sypeʁmaʁʃe ", "超市"),
        ("ferme ", "fermer", 0, "", "fɛʁm ", "关门"),
        ("à vingt heures", None, 0, "", "a vɛ̃t œʁ", "二十点"),
        (".", None, 0, "", "", ""),
    ]),
    ("sm20", "J'ai oublié ma liste sur la table.", "ʒe ublije ma list syʁ la tabl", "我把清单忘在桌上了。", [
        ("J'ai oublié ", "oublier", 0, "", "ʒe ublije ", "我忘了"),
        ("ma liste ", "liste", 1, "📝", "ma list ", "我的清单"),
        ("sur la table", "table", 1, "🪑", "syʁ la tabl", "在桌上"),
        (".", None, 0, "", "", ""),
    ]),
    ("sm21", "La queue est longue à la caisse.", "la kø ɛ lɔ̃ɡ a la sɛs", "收银台排队很长。", [
        ("La queue ", "queue", 1, "🧍", "la kø ", "队伍"),
        ("est longue ", "long", 0, "", "ɛ lɔ̃ɡ ", "很长"),
        ("à la caisse", "caisse", 1, "🧾", "a la sɛs", "在收银台"),
        (".", None, 0, "", "", ""),
    ]),
]

# --- 2. Café (20) ---
RAW += [
    ("cf01", "Un café au lait, s'il vous plaît.", "œ̃ kafe o lɛ sil vu plɛ", "请来一杯拿铁咖啡。", [
        ("Un café ", "café", 1, "☕", "œ̃ kafe ", "咖啡"),
        ("au lait", "lait", 1, "🥛", "o lɛ", "加奶"),
        (", s'il vous plaît.", None, 0, "", ", sil vu plɛ.", "请"),
    ]),
    ("cf02", "Je voudrais un croissant et un jus d'orange.", "ʒə vudʁɛ œ̃ kʁwasɑ̃ e œ̃ ʒy dɔʁɑ̃ʒ", "我想要一个可颂和一杯橙汁。", [
        ("Je voudrais ", "vouloir", 0, "", "ʒə vudʁɛ ", "我想要"),
        ("un croissant ", "croissant", 1, "🥐", "œ̃ kʁwasɑ̃ ", "可颂"),
        ("et un jus d'orange", "orange", 1, "🍊", "e œ̃ ʒy dɔʁɑ̃ʒ", "和橙汁"),
        (".", None, 0, "", "", ""),
    ]),
    ("cf03", "C'est combien le sandwich au jambon ?", "sɛ kɔ̃bjɛ̃ lə sɑ̃dwit o ʒɑ̃bɔ̃", "火腿三明治多少钱？", [
        ("C'est combien ", "combien", 0, "", "sɛ kɔ̃bjɛ̃ ", "多少钱"),
        ("le sandwich ", "sandwich", 1, "🥪", "lə sɑ̃dwit ", "三明治"),
        ("au jambon", "jambon", 1, "🥓", "o ʒɑ̃bɔ̃", "火腿"),
        (" ?", None, 0, "", " ?", ""),
    ]),
    ("cf04", "Je prends un thé vert sans sucre.", "ʒə pʁɑ̃ œ̃ te vɛʁ sɑ̃ sykʁ", "我要一杯无糖绿茶。", [
        ("Je prends ", "prendre", 0, "", "ʒə pʁɑ̃ ", "我要"),
        ("un thé vert ", "thé", 1, "🍵", "œ̃ te vɛʁ ", "绿茶"),
        ("sans sucre", "sucre", 0, "", "sɑ̃ sykʁ", "无糖"),
        (".", None, 0, "", "", ""),
    ]),
    ("cf05", "Vous avez des places en terrasse ?", "vu zave de plas ɑ̃ tɛʁas", "露台还有位子吗？", [
        ("Vous avez ", "avoir", 0, "", "vu zave ", "您有"),
        ("des places ", "place", 0, "", "de plas ", "座位"),
        ("en terrasse", "terrasse", 1, "☀️", "ɑ̃ tɛʁas", "在露台"),
        (" ?", None, 0, "", " ?", ""),
    ]),
    ("cf06", "L'addition, s'il vous plaît.", "ladisjɔ̃ sil vu plɛ", "请结账。", [
        ("L'addition", "addition", 1, "🧾", "ladisjɔ̃", "账单"),
        (", s'il vous plaît.", None, 0, "", ", sil vu plɛ.", "请"),
    ]),
    ("cf07", "Un chocolat chaud avec de la crème.", "œ̃ ʃɔkɔla ʃo avɛk də la kʁɛm", "一杯加奶油的热巧克力。", [
        ("Un chocolat chaud ", "chocolat", 1, "🍫", "œ̃ ʃɔkɔla ʃo ", "热巧克力"),
        ("avec ", None, 0, "", "avɛk ", "加"),
        ("de la crème", "crème", 1, "🥛", "də la kʁɛm", "奶油"),
        (".", None, 0, "", "", ""),
    ]),
    ("cf08", "Je suis allergique aux noix.", "ʒə sɥi zaʁʒik o nwa", "我对坚果过敏。", [
        ("Je suis ", "être", 0, "", "ʒə sɥi ", "我"),
        ("allergique ", "allergie", 0, "", "zaʁʒik ", "过敏"),
        ("aux noix", "noix", 1, "🌰", "o nwa", "对坚果"),
        (".", None, 0, "", "", ""),
    ]),
    ("cf09", "Pour emporter, s'il vous plaît.", "puʁ ɑ̃pɔʁte sil vu plɛ", "请打包带走。", [
        ("Pour emporter", "emporter", 1, "📦", "puʁ ɑ̃pɔʁte", "外带"),
        (", s'il vous plaît.", None, 0, "", ", sil vu plɛ.", "请"),
    ]),
    ("cf10", "Un verre d'eau avec glaçons, merci.", "œ̃ vɛʁ do avɛk glasɔ̃ mɛʁsi", "一杯加冰的水，谢谢。", [
        ("Un verre d'eau ", "eau", 1, "💧", "œ̃ vɛʁ do ", "一杯水"),
        ("avec glaçons", "glaçon", 1, "🧊", "avɛk glasɔ̃", "加冰块"),
        (", merci.", None, 0, "", ", mɛʁsi.", "谢谢"),
    ]),
    ("cf11", "Le wifi fonctionne ici ?", "lə wifi fɔ̃ksjɔn isi", "这里有Wi‑Fi吗？", [
        ("Le wifi ", None, 0, "📶", "lə wifi ", "Wi‑Fi"),
        ("fonctionne ", "fonctionner", 0, "", "fɔ̃ksjɔn ", "能用"),
        ("ici", None, 0, "", "isi", "这里"),
        (" ?", None, 0, "", " ?", ""),
    ]),
    ("cf12", "Je voudrais une part de tarte aux pommes.", "ʒə vudʁɛ yn paʁ də taʁt o pɔm", "我想要一块苹果派。", [
        ("Je voudrais ", "vouloir", 0, "", "ʒə vudʁɛ ", "我想要"),
        ("une part de tarte ", "tarte", 1, "🥧", "yn paʁ də taʁt ", "一块派"),
        ("aux pommes", "pomme", 1, "🍎", "o pɔm", "苹果"),
        (".", None, 0, "", "", ""),
    ]),
    ("cf13", "À quelle heure vous fermez ?", "a kɛl œʁ vu fɛʁme", "你们几点关门？", [
        ("À quelle heure ", None, 0, "", "a kɛl œʁ ", "几点"),
        ("vous fermez", "fermer", 0, "", "vu fɛʁme", "你们关"),
        (" ?", None, 0, "", " ?", ""),
    ]),
    ("cf14", "Un espresso serré, sans sucre.", "œ̃ ɛspʁɛso seʁe sɑ̃ sykʁ", "一杯浓缩，不加糖。", [
        ("Un espresso ", "café", 1, "☕", "œ̃ ɛspʁɛso ", "浓缩咖啡"),
        ("serré", None, 0, "", "seʁe", "特浓"),
        (", sans sucre.", "sucre", 0, "", ", sɑ̃ sykʁ.", "无糖"),
    ]),
    ("cf15", "C'est mon anniversaire aujourd'hui.", "sɛ mɔ̃ anivɛʁsɛʁ oʒuʁdɥi", "今天是我生日。", [
        ("C'est ", "être", 0, "", "sɛ ", "这是"),
        ("mon anniversaire ", "anniversaire", 1, "🎂", "mɔ̃ anivɛʁsɛʁ ", "我的生日"),
        ("aujourd'hui", None, 0, "", "oʒuʁdɥi", "今天"),
        (".", None, 0, "", "", ""),
    ]),
    ("cf16", "Vous servez le petit-déjeuner jusqu'à midi ?", "vu sɛʁve lə pəti deʒœne ʒyska midi", "早餐供应到中午吗？", [
        ("Vous servez ", "servir", 0, "", "vu sɛʁve ", "你们供应"),
        ("le petit-déjeuner ", "déjeuner", 1, "🍳", "lə pəti deʒœne ", "早餐"),
        ("jusqu'à midi", None, 0, "", "ʒyska midi", "到中午"),
        (" ?", None, 0, "", " ?", ""),
    ]),
    ("cf17", "Un cappuccino avec du lait d'avoine.", "œ̃ kapytʃino avɛk dy lɛ davwan", "一杯燕麦奶卡布奇诺。", [
        ("Un cappuccino ", "café", 1, "☕", "œ̃ kapytʃino ", "卡布奇诺"),
        ("avec du lait d'avoine", "avoine", 1, "🌾", "avɛk dy lɛ davwan", "加燕麦奶"),
        (".", None, 0, "", "", ""),
    ]),
    ("cf18", "Je m'appelle Marie pour la réservation.", "ʒə mapɛl maʁi puʁ la ʁezɛʁvasjɔ̃", "预订的名字是玛丽。", [
        ("Je m'appelle ", "appeler", 0, "", "ʒə mapɛl ", "我叫"),
        ("Marie ", None, 0, "", "maʁi ", "玛丽"),
        ("pour la réservation", "réserver", 1, "📅", "puʁ la ʁezɛʁvasjɔ̃", "预订"),
        (".", None, 0, "", "", ""),
    ]),
    ("cf19", "Ce gâteau est délicieux !", "sə gato ɛ delisjø", "这蛋糕太好吃了！", [
        ("Ce gâteau ", "gâteau", 1, "🍰", "sə gato ", "这蛋糕"),
        ("est délicieux", "délicieux", 0, "", "ɛ delisjø", "很好吃"),
        (" !", None, 0, "", " !", ""),
    ]),
    ("cf20", "Gardez la monnaie, ce n'est pas grave.", "gaʁde la mɔnɛ sə nɛ pa gʁav", "零钱不用找了，没关系。", [
        ("Gardez la monnaie", "monnaie", 0, "", "gaʁde la mɔnɛ", "留着零钱"),
        (", ce n'est pas grave", "grave", 0, "", ", sə nɛ pa gʁav", "没关系"),
        (".", None, 0, "", "", ""),
    ]),
]

_p2_path = Path(__file__).parent / "generate_lesson_corpus_part2.py"
_spec = importlib.util.spec_from_file_location("lesson_corpus_p2", _p2_path)
_mod = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(_mod)
RAW += _mod.RAW_MORE

sentences = [S(*row) for row in RAW]
assert len(sentences) >= 200, len(sentences)


def ipa_hint_for_lemma(lem: str) -> str:
    for s in sentences:
        for t in s["tokens"]:
            if t.get("lemma") != lem:
                continue
            ip = (t.get("ipa") or "").strip()
            if not ip:
                continue
            if t["text"].strip().lower() == lem.lower():
                return ip
    for s in sentences:
        for t in s["tokens"]:
            if t.get("lemma") == lem:
                ip = (t.get("ipa") or "").strip()
                if ip:
                    return ip
    return lem


def synth_raw_row(lem: str, variant: int, ip: str) -> tuple:
    """One synthetic example; lemma appears as cited form, 8 rotating frames for distinct French."""
    l, i = lem, ip
    frames: list[tuple[str, str, str, list]] = [
        (
            f"Je note « {l} ».",
            f"ʒə nɔt « {i} ».",
            f"我记下「{l}」。",
            [
                ("Je note « ", "noter", False, "", "ʒə nɔt « ", "我记下"),
                (l, lem, False, "", i, l),
                (" ».", None, False, "", " ».", ""),
            ],
        ),
        (
            f"Tu entends « {l} » ?",
            f"ty ɑ̃tɑ̃ « {i} » ?",
            f"你听到「{l}」了吗？",
            [
                ("Tu entends « ", "entendre", False, "", "ty ɑ̃tɑ̃ « ", "你听到"),
                (l, lem, False, "", i, l),
                (" » ?", None, False, "", " » ?", ""),
            ],
        ),
        (
            f"C'est écrit : « {l} ».",
            f"sɛtekʁi : « {i} ».",
            f"写着：「{l}」。",
            [
                ("C'est écrit : « ", "écrire", False, "", "sɛtekʁi : « ", "写着"),
                (l, lem, False, "", i, l),
                (" ».", None, False, "", " ».", ""),
            ],
        ),
        (
            f"Réponse courte : « {l} ».",
            f"ʁepɔ̃s kuʁt : « {i} ».",
            f"简短回答：「{l}」。",
            [
                ("Réponse courte : « ", "réponse", False, "", "ʁepɔ̃s kuʁt : « ", "简短回答"),
                (l, lem, False, "", i, l),
                (" ».", None, False, "", " ».", ""),
            ],
        ),
        (
            f"Exemple simple : « {l} ».",
            f"ɛɡzɑ̃pl sɛ̃pl : « {i} ».",
            f"简单例子：「{l}」。",
            [
                ("Exemple simple : « ", "exemple", False, "", "ɛɡzɑ̃pl sɛ̃pl : « ", "简单例子"),
                (l, lem, False, "", i, l),
                (" ».", None, False, "", " ».", ""),
            ],
        ),
        (
            f"On dit souvent « {l} ».",
            f"ɔ̃ di suvɑ̃ « {i} ».",
            f"人们常说「{l}」。",
            [
                ("On dit souvent « ", "dire", False, "", "ɔ̃ di suvɑ̃ « ", "常说"),
                (l, lem, False, "", i, l),
                (" ».", None, False, "", " ».", ""),
            ],
        ),
        (
            f"Mot vu en classe : « {l} ».",
            f"mo vy ɑ̃ klas : « {i} ».",
            f"课上见过的词：「{l}」。",
            [
                ("Mot vu en classe : « ", "mot", False, "", "mo vy ɑ̃ klas : « ", "课上的词"),
                (l, lem, False, "", i, l),
                (" ».", None, False, "", " ».", ""),
            ],
        ),
        (
            f"Répétez après moi : « {l} ».",
            f"ʁepete apʁɛ mwa : « {i} ».",
            f"跟我重复：「{l}」。",
            [
                ("Répétez après moi : « ", "répéter", False, "", "ʁepete apʁɛ mwa : « ", "跟我重复"),
                (l, lem, False, "", i, l),
                (" ».", None, False, "", " ».", ""),
            ],
        ),
    ]
    return frames[variant % len(frames)]


def fill_empty_token_ipa(obj: dict) -> None:
    """Punctuation / gaps: mirror surface so IPA toggle never shows blank."""
    for t in obj.get("tokens", []):
        if (t.get("ipa") or "").strip():
            continue
        tx = t.get("text", "")
        t["ipa"] = tx if tx else "."


# Lemmas + example bank: unique source sentences first, then distinct synthetics (no clones)
lemmas_in_corpus: set[str] = set()
for s in sentences:
    for t in s["tokens"]:
        if t.get("lemma"):
            lemmas_in_corpus.add(t["lemma"])

examples_by_lemma: dict[str, list] = {lem: [] for lem in lemmas_in_corpus}
ex_counters: defaultdict[str, int] = defaultdict(int)


def clone_with_id(s: dict, new_id: str) -> dict:
    c = copy.deepcopy(s)
    c["id"] = new_id
    return c


for lem in sorted(lemmas_in_corpus):
    seen_texts: set[str] = set()
    picked: list[dict] = []
    for s in sentences:
        if not any(tok.get("lemma") == lem for tok in s["tokens"]):
            continue
        if s["text"] in seen_texts:
            continue
        seen_texts.add(s["text"])
        ex_counters[lem] += 1
        picked.append(clone_with_id(s, f"ex-{lem}-{ex_counters[lem]}"))
        if len(picked) >= 5:
            break
    v = 0
    while len(picked) < 5:
        ip = ipa_hint_for_lemma(lem)
        while True:
            row = synth_raw_row(lem, v, ip)
            sid = f"ex-{lem}-s{v}"
            cand = S(sid, row[0], row[1], row[2], row[3])
            v += 1
            if cand["text"] not in seen_texts:
                seen_texts.add(cand["text"])
                picked.append(cand)
                break
            if v > 80:
                raise RuntimeError(f"Could not diversify examples for lemma {lem!r}")
    examples_by_lemma[lem] = picked[:5]

for s in sentences:
    fill_empty_token_ipa(s)
for arr in examples_by_lemma.values():
    for s in arr:
        fill_empty_token_ipa(s)

OUT_S.parent.mkdir(parents=True, exist_ok=True)
OUT_S.write_text(json.dumps({"sentences": sentences}, ensure_ascii=False, indent=2), encoding="utf-8")
OUT_E.write_text(json.dumps({"examples_by_lemma": examples_by_lemma}, ensure_ascii=False, indent=2), encoding="utf-8")
print("sentences:", len(sentences), "lemma keys:", len(examples_by_lemma))
