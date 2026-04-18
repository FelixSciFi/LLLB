#!/usr/bin/env python3
"""Expand word_table_fr.json to ~300–500 A1 lemmas; keep ranks 1–50; add pos; new from 51."""

from __future__ import annotations

import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "LearnLanguageLikeABaby" / "Resources" / "word_table_fr.json"

N = lambda lem, zh, em="": (lem, zh, em, "noun")
V = lambda lem, zh, em="": (lem, zh, em, "verb")
A = lambda lem, zh, em="": (lem, zh, em, "adj")
D = lambda lem, zh, em="": (lem, zh, em, "adv")
F = lambda lem, zh: (lem, zh, "", "function")
NUM = lambda lem, zh, em="": (lem, zh, em, "numeral")
I = lambda lem, zh: (lem, zh, "", "interjection")
PH = lambda lem, zh: (lem, zh, "", "phrase")  # fixed expression


BASE_POS: dict[str, str] = {
    "maman": "noun",
    "papa": "noun",
    "non": "adv",
    "oui": "adv",
    "encore": "adv",
    "bébé": "noun",
    "chien": "noun",
    "chat": "noun",
    "eau": "noun",
    "pain": "noun",
    "lait": "noun",
    "manger": "verb",
    "boire": "verb",
    "dormir": "verb",
    "venir": "verb",
    "partir": "verb",
    "grand": "adj",
    "petit": "adj",
    "chaud": "adj",
    "froid": "adj",
    "bonjour": "interjection",
    "merci": "interjection",
    "main": "noun",
    "pied": "noun",
    "oeil": "noun",
    "bouche": "noun",
    "nez": "noun",
    "ventre": "noun",
    "pomme": "noun",
    "banane": "noun",
    "voiture": "noun",
    "balle": "noun",
    "livre": "noun",
    "chaussure": "noun",
    "chapeau": "noun",
    "rouge": "adj",
    "bleu": "adj",
    "jaune": "adj",
    "vert": "adj",
    "un": "numeral",
    "deux": "numeral",
    "trois": "numeral",
    "lune": "noun",
    "soleil": "noun",
    "fleur": "noun",
    "arbre": "noun",
    "oiseau": "noun",
    "poisson": "noun",
    "cheval": "noun",
    "maison": "noun",
}


def build_new_rows() -> list[tuple[str, str, str, str]]:
    r: list[tuple[str, str, str, str]] = []

    # CDI continuation — people & identity
    r += [
        N("frère", "兄弟", "👦"),
        N("sœur", "姐妹", "👧"),
        N("mère", "母亲"),
        N("père", "父亲"),
        N("famille", "家庭"),
        N("ami", "朋友"),
        N("amie", "女性朋友"),
        N("fille", "女孩"),
        N("garçon", "男孩"),
        N("homme", "男人"),
        N("femme", "女人"),
        N("enfant", "孩子"),
        N("grand-mère", "祖母", "👵"),
        N("grand-père", "祖父", "👴"),
        N("tante", "姑妈/姨妈"),
        N("oncle", "伯父/舅舅"),
        N("cousin", "堂表兄弟"),
        N("cousine", "堂表姐妹"),
        N("voisin", "男邻居"),
        N("voisine", "女邻居"),
        N("nom", "姓氏"),
        N("prénom", "名字"),
        N("âge", "年龄"),
        N("adresse", "地址"),
    ]

    # Body
    r += [
        N("tête", "头"),
        N("bras", "手臂"),
        N("jambe", "腿"),
        N("doigt", "手指"),
        N("oreille", "耳朵", "👂"),
        N("cheveu", "头发"),
        N("dent", "牙齿"),
        N("langue", "舌头"),
        N("cou", "脖子"),
        N("dos", "背"),
        N("genou", "膝盖"),
        N("épaule", "肩膀"),
        N("peau", "皮肤"),
        N("cœur", "心脏", "❤️"),
    ]

    # Clothing
    r += [
        N("vêtement", "衣服"),
        N("robe", "连衣裙", "👗"),
        N("pantalon", "裤子", "👖"),
        N("pull", "毛衣"),
        N("manteau", "大衣", "🧥"),
        N("jupe", "裙子"),
        N("casquette", "鸭舌帽", "🧢"),
        N("chaussette", "袜子"),
        N("ceinture", "皮带"),
        N("écharpe", "围巾"),
        N("gant", "手套", "🧤"),
        N("botte", "靴子", "👢"),
    ]

    # Food & drink
    r += [
        N("riz", "米饭", "🍚"),
        N("pâte", "面团/面食", "🍝"),
        N("viande", "肉", "🥩"),
        N("œuf", "蛋", "🥚"),
        N("fromage", "奶酪", "🧀"),
        N("beurre", "黄油"),
        N("sucre", "糖"),
        N("sel", "盐"),
        N("gâteau", "蛋糕", "🎂"),
        N("bonbon", "糖果", "🍬"),
        N("soupe", "汤"),
        N("salade", "沙拉", "🥗"),
        N("tomate", "西红柿", "🍅"),
        N("carotte", "胡萝卜", "🥕"),
        N("pomme de terre", "土豆", "🥔"),
        N("citron", "柠檬", "🍋"),
        N("orange", "橙子", "🍊"),
        N("fraise", "草莓", "🍓"),
        N("raisin", "葡萄", "🍇"),
        N("café", "咖啡", "☕"),
        N("thé", "茶", "🍵"),
        N("jus", "果汁", "🧃"),
        N("chocolat", "巧克力", "🍫"),
        N("glace", "冰淇淋", "🍨"),
        N("sandwich", "三明治", "🥪"),
        N("boisson", "饮料"),
    ]

    # Home & rooms
    r += [
        N("porte", "门", "🚪"),
        N("fenêtre", "窗"),
        N("table", "桌子"),
        N("chaise", "椅子", "🪑"),
        N("lit", "床", "🛏️"),
        N("coussin", "靠垫"),
        N("couverture", "被子"),
        N("lampe", "灯", "💡"),
        N("miroir", "镜子"),
        N("clé", "钥匙", "🔑"),
        N("étagère", "架子"),
        N("jardin", "花园"),
        N("escalier", "楼梯"),
        N("cuisine", "厨房"),
        N("toilettes", "厕所", "🚻"),
        N("salon", "客厅"),
        N("immeuble", "楼房"),
        N("pièce", "房间"),
        N("sol", "地板"),
        N("plafond", "天花板"),
    ]

    # School & office
    r += [
        N("école", "学校", "🏫"),
        N("classe", "班级"),
        N("professeur", "老师", "👨‍🏫"),
        N("élève", "学生"),
        N("cahier", "练习本", "📓"),
        N("crayon", "铅笔", "✏️"),
        N("stylo", "钢笔", "🖊️"),
        N("gomme", "橡皮"),
        N("règle", "尺子", "📏"),
        N("cartable", "书包", "🎒"),
        N("ordinateur", "电脑", "💻"),
        N("téléphone", "手机", "📱"),
        N("télévision", "电视", "📺"),
    ]

    # City & travel
    r += [
        N("rue", "街道"),
        N("route", "公路"),
        N("ville", "城市"),
        N("magasin", "商店"),
        N("marché", "市场"),
        N("hôpital", "医院", "🏥"),
        N("pharmacie", "药店"),
        N("parc", "公园"),
        N("gare", "火车站", "🚉"),
        N("bus", "公共汽车", "🚌"),
        N("train", "火车", "🚆"),
        N("avion", "飞机", "✈️"),
        N("vélo", "自行车", "🚲"),
        N("métro", "地铁"),
        N("bateau", "船", "⛵"),
        N("poste", "邮局"),
        N("banque", "银行"),
        N("hôtel", "旅馆"),
        N("restaurant", "餐馆", "🍽️"),
        N("café_bar", "咖啡馆", "☕"),
    ]
    # fix lemma: café_bar invalid — French "café" already used; use "bar"
    r[-1] = N("bar", "酒吧", "🍺")

    # Animals & nature
    r += [
        N("vache", "奶牛", "🐄"),
        N("cochon", "猪", "🐷"),
        N("mouton", "绵羊", "🐑"),
        N("poule", "母鸡", "🐔"),
        N("lapin", "兔子", "🐰"),
        N("souris", "老鼠", "🐭"),
        N("lion", "狮子", "🦁"),
        N("ours", "熊", "🐻"),
        N("loup", "狼", "🐺"),
        N("canard", "鸭子", "🦆"),
        N("abeille", "蜜蜂", "🐝"),
        N("papillon", "蝴蝶", "🦋"),
        N("serpent", "蛇", "🐍"),
        N("grenouille", "青蛙", "🐸"),
        N("herbe", "草"),
        N("montagne", "山", "⛰️"),
        N("mer", "海", "🌊"),
        N("rivière", "河"),
        N("lac", "湖"),
    ]

    r += [
        N("feu", "火", "🔥"),
        N("nuage", "云", "☁️"),
        N("pluie", "雨", "🌧️"),
        N("neige", "雪", "❄️"),
        N("vent", "风", "💨"),
        N("étoile", "星星", "⭐"),
    ]

    # Time & calendar
    r += [
        N("jour", "白天/日"),
        N("nuit", "夜", "🌙"),
        N("matin", "早晨", "🌅"),
        N("soir", "晚上"),
        N("heure", "小时"),
        N("minute", "分钟"),
        N("semaine", "星期"),
        N("mois", "月"),
        N("année", "年"),
        N("aujourd'hui", "今天"),
        N("demain", "明天"),
        N("hier", "昨天"),
        D("maintenant", "现在"),
        D("après", "之后", "⏭️"),
        D("avant", "之前", "⏮️"),
    ]
    for lem, zh in [
        ("lundi", "星期一"),
        ("mardi", "星期二"),
        ("mercredi", "星期三"),
        ("jeudi", "星期四"),
        ("vendredi", "星期五"),
        ("samedi", "星期六"),
        ("dimanche", "星期日"),
    ]:
        r.append(N(lem, zh))
    for lem, zh in [
        ("janvier", "一月"),
        ("février", "二月"),
        ("mars", "三月"),
        ("avril", "四月"),
        ("mai", "五月"),
        ("juin", "六月"),
        ("juillet", "七月"),
        ("août", "八月"),
        ("septembre", "九月"),
        ("octobre", "十月"),
        ("novembre", "十一月"),
        ("décembre", "十二月"),
    ]:
        r.append(N(lem, zh))

    # Numerals (A1)
    for lem, zh, em in [
        ("zéro", "零", "0️⃣"),
        ("quatre", "四", "4️⃣"),
        ("cinq", "五", "5️⃣"),
        ("six", "六", "6️⃣"),
        ("sept", "七", "7️⃣"),
        ("huit", "八", "8️⃣"),
        ("neuf", "九", "9️⃣"),
        ("dix", "十", "🔟"),
        ("onze", "十一", ""),
        ("douze", "十二", ""),
        ("treize", "十三", ""),
        ("quatorze", "十四", ""),
        ("quinze", "十五", ""),
        ("seize", "十六", ""),
        ("vingt", "二十", ""),
        ("trente", "三十", ""),
        ("quarante", "四十", ""),
        ("cinquante", "五十", ""),
        ("soixante", "六十", ""),
        ("cent", "一百", ""),
        ("mille", "一千", ""),
    ]:
        r.append(NUM(lem, zh, em))

    # Core verbs A1 (Français fondamental / DELF)
    r += [
        V("aller", "去"),
        V("être", "是"),
        V("avoir", "有"),
        V("faire", "做"),
        V("dire", "说"),
        V("voir", "看见"),
        V("savoir", "知道"),
        V("pouvoir", "能够"),
        V("vouloir", "想要"),
        V("devoir", "应该"),
        V("prendre", "拿/乘"),
        V("mettre", "放"),
        V("donner", "给"),
        V("parler", "说话"),
        V("travailler", "工作"),
        V("habiter", "居住"),
        V("aimer", "喜欢"),
        V("préférer", "更喜欢"),
        V("demander", "问"),
        V("répondre", "回答"),
        V("acheter", "买"),
        V("payer", "付款"),
        V("vendre", "卖"),
        V("chercher", "寻找"),
        V("trouver", "找到"),
        V("porter", "穿/搬"),
        V("ouvrir", "打开"),
        V("fermer", "关"),
        V("commencer", "开始"),
        V("finir", "结束"),
        V("rester", "停留"),
        V("tomber", "掉落/跌倒"),
        V("marcher", "走"),
        V("courir", "跑"),
        V("jouer", "玩"),
        V("écouter", "听"),
        V("regarder", "看"),
        V("lire", "读"),
        V("écrire", "写"),
        V("apprendre", "学习"),
        V("comprendre", "理解"),
        V("attendre", "等待"),
        V("arrêter", "停"),
        V("continuer", "继续"),
        V("rentrer", "回家"),
        V("sortir", "外出"),
        V("monter", "上"),
        V("descendre", "下"),
        V("sembler", "显得"),
        V("rendre", "归还"),
        V("asseoir", "坐"),
        V("lever", "举起/起床"),
    ]

    # Adjectives
    r += [
        A("bon", "好"),
        A("mauvais", "坏"),
        A("beau", "美"),
        A("laid", "丑"),
        A("jeune", "年轻"),
        A("vieux", "老/旧"),
        A("nouveau", "新"),
        A("ancien", "古老的"),
        A("facile", "容易"),
        A("difficile", "难"),
        A("propre", "干净"),
        A("sale", "脏"),
        A("plein", "满"),
        A("vide", "空"),
        A("heureux", "快乐"),
        A("triste", "悲伤"),
        A("fatigué", "累"),
        A("malade", "生病"),
        A("pareil", "一样"),
        A("dernier", "最后的"),
        A("premier", "第一的"),
        A("deuxième", "第二的"),
        A("vrai", "真"),
        A("faux", "假"),
        A("meilleur", "更好"),
        A("noir", "黑", "⚫"),
        A("blanc", "白", "⚪"),
        A("rose", "粉色", "🌸"),
        A("gris", "灰色"),
        A("marron", "棕色"),
    ]

    # Adverbs & particles
    r += [
        D("bien", "好地"),
        D("mal", "差地"),
        D("très", "很"),
        D("trop", "太"),
        D("assez", "够"),
        D("peu", "少"),
        D("beaucoup", "很多"),
        D("toujours", "总是"),
        D("jamais", "从不"),
        D("souvent", "经常"),
        D("parfois", "有时"),
        D("vite", "快"),
        D("lentement", "慢"),
        D("là", "那里"),
        D("ici", "这里"),
        D("dedans", "里面"),
        D("dehors", "外面"),
        D("ensemble", "一起"),
        D("seulement", "只"),
    ]

    # Fixed phrases A1
    r += [
        PH("s'il vous plaît", "请"),
        PH("excusez-moi", "对不起"),
        PH("pardon", "抱歉"),
        PH("au revoir", "再见"),
        PH("à bientôt", "回头见"),
        I("salut", "你好/再见"),
        I("bonsoir", "晚上好"),
        I("aïe", "哎哟"),
    ]

    # Function words (articles, pronouns, prepositions, conjunctions)
    r += [
        F("le", "定冠词(阳性)"),
        F("la", "定冠词(阴性)"),
        F("les", "定冠词(复数)"),
        F("un", "不定冠词(阳性)"),
        F("une", "不定冠词(阴性)"),
        F("des", "不定冠词(复数)"),
        F("du", "部分冠词(m.)"),
        F("de", "的/从"),
        F("l'", "省音冠词"),
        F("à", "在/向"),
        F("au", "à+le"),
        F("aux", "à+les"),
        F("de la", "部分阴性"),
        F("chez", "在…家"),
        F("dans", "在…里"),
        F("sur", "在…上"),
        F("sous", "在…下"),
        F("pour", "为了"),
        F("avec", "和…一起"),
        F("sans", "没有"),
        F("entre", "在…之间"),
        F("par", "经/被"),
        F("vers", "朝向"),
        F("pendant", "在…期间"),
        F("et", "和"),
        F("ou", "或"),
        F("mais", "但是"),
        F("donc", "所以"),
        F("car", "因为"),
        F("si", "如果/是否"),
        F("que", "连词/代词"),
        F("qui", "谁"),
        F("quoi", "什么"),
        F("où", "哪里"),
        F("comment", "怎样"),
        F("quand", "何时"),
        F("pourquoi", "为什么"),
        F("combien", "多少"),
        F("ne", "否定(虚词)"),
        F("pas", "不"),
        F("plus", "再/更"),
        F("rien", "什么也没有"),
        F("personne", "没有人"),
        F("quelque", "某些"),
        F("tout", "全部"),
        F("tous", "全部(阳复)"),
        F("toute", "整个(阴性)"),
        F("chaque", "每个"),
        F("autre", "别的"),
        F("même", "甚至/相同"),
        F("je", "我"),
        F("tu", "你"),
        F("il", "他/它"),
        F("elle", "她"),
        F("nous", "我们"),
        F("vous", "您/你们"),
        F("ils", "他们"),
        F("elles", "她们"),
        F("on", "人们/我们"),
        F("me", "我(宾)"),
        F("te", "你(宾)"),
        F("se", "自己"),
        F("lui", "他/她(宾)"),
        F("leur", "他们(的)/他们(宾)"),
        F("y", "那儿"),
        F("en", "一些/从中"),
        F("mon", "我的(阳性)"),
        F("ma", "我的(阴性)"),
        F("mes", "我的(复数)"),
        F("ton", "你的(阳性)"),
        F("ta", "你的(阴性)"),
        F("tes", "你的(复数)"),
        F("son", "他/她的(阳性)"),
        F("sa", "他/她的(阴性)"),
        F("ses", "他/她的(复数)"),
        F("notre", "我们的"),
        F("nos", "我们的(复数)"),
        F("votre", "您的"),
        F("vos", "您的(复数)"),
        F("leurs", "他们的(复数)"),
        F("ce", "这"),
        F("cet", "这(阳性)"),
        F("cette", "这(阴性)"),
        F("ces", "这些"),
        F("cela", "那"),
        F("ça", "这/那"),
    ]

    # Nouns misc A1
    r += [
        N("temps", "时间/天气"),
        N("plage", "海滩"),
        N("vacances", "假期"),
        N("fête", "节日", "🎉"),
        N("photo", "照片", "📷"),
        N("musique", "音乐", "🎵"),
        N("film", "电影", "🎬"),
        N("sport", "运动", "⚽"),
        N("jeu", "游戏", "🎮"),
        N("jouet", "玩具", "🧸"),
        N("cadeau", "礼物", "🎁"),
        N("argent", "钱", "💶"),
        N("euro", "欧元", "💶"),
        N("prix", "价格"),
        N("ticket", "票"),
        N("carte", "地图/卡片", "🗺️"),
        N("pays", "国家"),
        N("couleur", "颜色"),
        N("forme", "形状"),
        N("taille", "尺寸"),
        N("poids", "重量"),
        N("travail", "工作"),
        N("métier", "职业"),
        N("santé", "健康"),
        N("médecin", "医生", "👨‍⚕️"),
        N("infirmier", "护士", "🧑‍⚕️"),
        N("policier", "警察", "👮"),
        N("pompier", "消防员", "🧑‍🚒"),
        N("boulanger", "面包师", "🥖"),
    ]

    return r


def dedupe_preserve_order(rows: list[tuple[str, str, str, str]]) -> list[tuple[str, str, str, str]]:
    seen: set[str] = set()
    out: list[tuple[str, str, str, str]] = []
    for row in rows:
        lem = row[0]
        if lem in seen:
            continue
        seen.add(lem)
        out.append(row)
    return out


def main() -> None:
    data = json.loads(OUT.read_text(encoding="utf-8"))
    words: list[dict] = data["words"]
    first50 = sorted([w for w in words if w.get("rank", 0) <= 50], key=lambda x: x["rank"])
    if len(first50) != 50:
        raise SystemExit(f"Expected exactly 50 entries with rank 1–50, got {len(first50)}")
    for w in first50:
        lem = w["lemma"]
        if lem not in BASE_POS:
            raise SystemExit(f"Missing BASE_POS for {lem!r}")
        w["pos"] = BASE_POS[lem]
        w["cefr"] = "A1"

    seen50 = {w["lemma"] for w in first50}
    new_raw = build_new_rows()
    new_rows = dedupe_preserve_order(new_raw)

    merged50 = {w["lemma"] for w in first50}
    additions: list[dict] = []
    rank = 51
    for lem, zh, em, pos in new_rows:
        if lem in merged50:
            continue
        merged50.add(lem)
        additions.append(
            {
                "rank": rank,
                "lemma": lem,
                "translation": zh,
                "emoji": em,
                "cefr": "A1",
                "pos": pos,
            }
        )
        rank += 1

    out_words = first50 + additions
    OUT.write_text(json.dumps({"words": out_words}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    total = len(out_words)
    by_pos = Counter(w["pos"] for w in out_words)
    # Rank buckets
    buckets = Counter()
    for w in out_words:
        rk = w["rank"]
        b = (rk - 1) // 50
        buckets[f"rank_{b*50+1}-{min((b+1)*50, total)}"] += 1

    # Simpler bucket labels
    bc = Counter()
    for w in out_words:
        r = w["rank"]
        if r <= 50:
            bc["1–50 (CDI core)"] += 1
        elif r <= 150:
            bc["51–150"] += 1
        elif r <= 250:
            bc["151–250"] += 1
        elif r <= 350:
            bc["251–350"] += 1
        else:
            bc["351+"] += 1

    print("--- word_table_fr.json ---")
    print(f"total lemmas: {total}")
    print("by pos:", dict(sorted(by_pos.items(), key=lambda x: (-x[1], x[0]))))
    print("by rank segment:", dict(bc))


if __name__ == "__main__":
    main()
