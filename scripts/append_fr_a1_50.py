#!/usr/bin/env python3
"""One-shot: append 50 hand-crafted FR A1 rows to sentences_fr.json. Run from repo root."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LearnLanguageLikeABaby" / "Resources" / "sentences_fr.json"


def T(text, lemma, emoji, ipa, zh, has_img=None):
    hi = has_img if has_img is not None else bool(emoji)
    return {
        "text": text,
        "lemma": lemma,
        "hasImage": hi,
        "emoji": emoji or "",
        "ipa": ipa,
        "translation": zh,
    }


# id a1_001 … a1_050 — 2–4 tokens, concrete nouns, no banned templates
NEW = [
    {
        "id": "a1_001",
        "text": "Deux pommes rouges.",
        "ipa": "dø pɔm ʁuʒ",
        "translation": "两个红苹果。",
        "library": "A1",
        "tokens": [
            T("Deux ", "deux", "2️⃣", "dø", "两"),
            T("pommes rouges.", "pomme", "🍎", "pɔm ʁuʒ", "红苹果。"),
        ],
    },
    {
        "id": "a1_002",
        "text": "Une banane bien mûre.",
        "ipa": "yn banan bjɛ̃ myʁ",
        "translation": "一根熟香蕉。",
        "library": "A1",
        "tokens": [
            T("Une banane", "banane", "🍌", "yn banan", "一根香蕉"),
            T(" bien mûre.", "mûr", "", "bjɛ̃ myʁ", "很熟。"),
        ],
    },
    {
        "id": "a1_003",
        "text": "Trois chats noirs.",
        "ipa": "tʁwa ʃa nwaʁ",
        "translation": "三只黑猫。",
        "library": "A1",
        "tokens": [
            T("Trois ", "trois", "3️⃣", "tʁwa", "三"),
            T("chats noirs.", "chat", "🐈‍⬛", "ʃa nwaʁ", "黑猫。"),
        ],
    },
    {
        "id": "a1_004",
        "text": "J'aime le chocolat.",
        "ipa": "ʒɛm lə ʃɔkɔla",
        "translation": "我喜欢巧克力。",
        "library": "A1",
        "tokens": [
            T("J'aime", "aimer", "❤️", "ʒɛm", "我喜欢"),
            T(" le chocolat.", "chocolat", "🍫", "lə ʃɔkɔla", "巧克力。"),
        ],
    },
    {
        "id": "a1_005",
        "text": "Ma tête me fait mal.",
        "ipa": "ma tɛt mə fɛ mal",
        "translation": "我头疼。",
        "library": "A1",
        "tokens": [
            T("Ma tête", "tête", "🧠", "ma tɛt", "我的头"),
            T(" me fait mal.", "faire", "", "mə fɛ mal", "疼。"),
        ],
    },
    {
        "id": "a1_006",
        "text": "Mes yeux sont bleus.",
        "ipa": "me zø sɔ̃ blø",
        "translation": "我的眼睛是蓝色的。",
        "library": "A1",
        "tokens": [
            T("Mes yeux", "œil", "👀", "me zø", "我的眼睛"),
            T(" sont bleus.", "bleu", "", "sɔ̃ blø", "是蓝的。"),
        ],
    },
    {
        "id": "a1_007",
        "text": "Un mouton dans le pré.",
        "ipa": "ɛ̃ mutɔ̃ dɑ̃ lə pʁe",
        "translation": "草地上的一只绵羊。",
        "library": "A1",
        "tokens": [
            T("Un mouton", "mouton", "🐑", "ɛ̃ mutɔ̃", "一只绵羊"),
            T(" dans le pré.", "pré", "🌾", "dɑ̃ lə pʁe", "在草地上。"),
        ],
    },
    {
        "id": "a1_008",
        "text": "Cinq carottes râpées.",
        "ipa": "sɛ̃k kaʁɔt ʁape",
        "translation": "五根擦碎的胡萝卜。",
        "library": "A1",
        "tokens": [
            T("Cinq ", "cinq", "5️⃣", "sɛ̃k", "五"),
            T("carottes râpées.", "carotte", "🥕", "kaʁɔt ʁape", "胡萝卜丝。"),
        ],
    },
    {
        "id": "a1_009",
        "text": "Le pied gauche.",
        "ipa": "lə pje goʃ",
        "translation": "左脚。",
        "library": "A1",
        "tokens": [
            T("Le pied", "pied", "🦶", "lə pje", "脚"),
            T(" gauche.", "gauche", "", "goʃ", "左。"),
        ],
    },
    {
        "id": "a1_010",
        "text": "Une glace à la fraise.",
        "ipa": "yn ɡlas a la fʁɛz",
        "translation": "草莓冰淇淋。",
        "library": "A1",
        "tokens": [
            T("Une glace", "glace", "🍨", "yn ɡlas", "冰淇淋"),
            T(" à la fraise.", "fraise", "🍓", "a la fʁɛz", "草莓味。"),
        ],
    },
    {
        "id": "a1_011",
        "text": "Neuf oranges pressées.",
        "ipa": "nœf ɔʁɑ̃ʒ pʁese",
        "translation": "九个鲜榨。",
        "library": "A1",
        "tokens": [
            T("Neuf ", "neuf", "9️⃣", "nœf", "九"),
            T("oranges pressées.", "orange", "🍊", "ɔʁɑ̃ʒ pʁese", "橙子（榨汁）。"),
        ],
    },
    {
        "id": "a1_012",
        "text": "La fenêtre est ouverte.",
        "ipa": "la fənɛtʁ ɛt uvɛʁt",
        "translation": "窗户开着。",
        "library": "A1",
        "tokens": [
            T("La fenêtre", "fenêtre", "🪟", "la fənɛtʁ", "窗户"),
            T(" est ouverte.", "être", "", "ɛt uvɛʁt", "开着。"),
        ],
    },
    {
        "id": "a1_013",
        "text": "Un téléphone sur le lit.",
        "ipa": "ɛ̃ telefɔn syʁ lə li",
        "translation": "床上的手机。",
        "library": "A1",
        "tokens": [
            T("Un téléphone", "téléphone", "📱", "ɛ̃ telefɔn", "一部手机"),
            T(" sur le lit.", "lit", "🛏️", "syʁ lə li", "在床上。"),
        ],
    },
    {
        "id": "a1_014",
        "text": "J'ai froid aux mains.",
        "ipa": "ʒe fʁwa o mɛ̃",
        "translation": "我手冷。",
        "library": "A1",
        "tokens": [
            T("J'ai froid", "froid", "🥶", "ʒe fʁwa", "我冷"),
            T(" aux mains.", "main", "🤲", "o mɛ̃", "手上。"),
        ],
    },
    {
        "id": "a1_015",
        "text": "Douze fraises sucrées.",
        "ipa": "duz fʁɛz sykʁe",
        "translation": "十二颗甜草莓。",
        "library": "A1",
        "tokens": [
            T("Douze ", "douze", "🔟", "duz", "十二"),
            T("fraises sucrées.", "fraise", "🍓", "fʁɛz sykʁe", "甜草莓。"),
        ],
    },
    {
        "id": "a1_016",
        "text": "Un lion et deux lionnes.",
        "ipa": "ɛ̃ ljɔ̃ e dø ljɔn",
        "translation": "一只雄狮和两只母狮。",
        "library": "A1",
        "tokens": [
            T("Un lion", "lion", "🦁", "ɛ̃ ljɔ̃", "雄狮"),
            T(" et deux lionnes.", "lionne", "", "e dø ljɔn", "和两只母狮。"),
        ],
    },
    {
        "id": "a1_017",
        "text": "Une petite souris grise.",
        "ipa": "yn pətit suʁi ɡʁiz",
        "translation": "一只小灰老鼠。",
        "library": "A1",
        "tokens": [
            T("Une petite souris", "souris", "🐭", "yn pətit suʁi", "小老鼠"),
            T(" grise.", "gris", "", "ɡʁiz", "灰色的。"),
        ],
    },
    {
        "id": "a1_018",
        "text": "Quatre œufs durs.",
        "ipa": "katʁ ø dyʁ",
        "translation": "四个煮鸡蛋。",
        "library": "A1",
        "tokens": [
            T("Quatre ", "quatre", "4️⃣", "katʁ", "四"),
            T("œufs durs.", "œuf", "🥚", "ø dyʁ", "煮蛋。"),
        ],
    },
    {
        "id": "a1_019",
        "text": "Du pain et du beurre.",
        "ipa": "dy pɛ̃ e dy bœʁ",
        "translation": "面包和黄油。",
        "library": "A1",
        "tokens": [
            T("Du pain", "pain", "🍞", "dy pɛ̃", "面包"),
            T(" et du beurre.", "beurre", "🧈", "e dy bœʁ", "和黄油。"),
        ],
    },
    {
        "id": "a1_020",
        "text": "Les dents, ça compte !",
        "ipa": "le dɑ̃ sa kɔ̃t",
        "translation": "牙齿很重要！",
        "library": "A1",
        "tokens": [
            T("Les dents", "dent", "🦷", "le dɑ̃", "牙齿"),
            T(", ça compte !", "compter", "", "sa kɔ̃t", "很重要！"),
        ],
    },
    {
        "id": "a1_021",
        "text": "Une tasse de thé chaud.",
        "ipa": "yn tas də te ʃo",
        "translation": "一杯热茶。",
        "library": "A1",
        "tokens": [
            T("Une tasse", "tasse", "☕", "yn tas", "一杯"),
            T(" de thé chaud.", "thé", "🫖", "də te ʃo", "热茶。"),
        ],
    },
    {
        "id": "a1_022",
        "text": "Sept billes de couleurs.",
        "ipa": "sɛt bil də kulœʁ",
        "translation": "七颗彩色弹珠。",
        "library": "A1",
        "tokens": [
            T("Sept ", "sept", "7️⃣", "sɛt", "七"),
            T("billes de couleurs.", "bille", "🔴", "bil də kulœʁ", "彩色弹珠。"),
        ],
    },
    {
        "id": "a1_023",
        "text": "Le loup hurle la nuit.",
        "ipa": "lə lu yʁl la nɥi",
        "translation": "狼在夜里嚎叫。",
        "library": "A1",
        "tokens": [
            T("Le loup", "loup", "🐺", "lə lu", "狼"),
            T(" hurle la nuit.", "hurler", "🌙", "yʁl la nɥi", "夜里叫。"),
        ],
    },
    {
        "id": "a1_024",
        "text": "Mes oreilles bourdonnent.",
        "ipa": "me zɔʁɛj buʁdɔn",
        "translation": "我耳鸣。",
        "library": "A1",
        "tokens": [
            T("Mes oreilles", "oreille", "👂", "me zɔʁɛj", "我的耳朵"),
            T(" bourdonnent.", "bourdonner", "", "buʁdɔn", "嗡嗡响。"),
        ],
    },
    {
        "id": "a1_025",
        "text": "Une cuillère en bois.",
        "ipa": "yn kɥijɛʁ ɑ̃ bwa",
        "translation": "一把木勺。",
        "library": "A1",
        "tokens": [
            T("Une cuillère", "cuillère", "🥄", "yn kɥijɛʁ", "勺子"),
            T(" en bois.", "bois", "🪵", "ɑ̃ bwa", "木头的。"),
        ],
    },
    {
        "id": "a1_026",
        "text": "Huit bouteilles vides.",
        "ipa": "ɥit butɛj vid",
        "translation": "八个空瓶子。",
        "library": "A1",
        "tokens": [
            T("Huit ", "huit", "8️⃣", "ɥit", "八"),
            T("bouteilles vides.", "bouteille", "🍼", "butɛj vid", "空瓶。"),
        ],
    },
    {
        "id": "a1_027",
        "text": "La peau très douce.",
        "ipa": "la po tʁɛ dus",
        "translation": "皮肤很嫩。",
        "library": "A1",
        "tokens": [
            T("La peau", "peau", "✋", "la po", "皮肤"),
            T(" très douce.", "doux", "", "tʁɛ dus", "很柔软。"),
        ],
    },
    {
        "id": "a1_028",
        "text": "Un canard jaune.",
        "ipa": "ɛ̃ kanaʁ ʒon",
        "translation": "一只黄鸭子。",
        "library": "A1",
        "tokens": [
            T("Un canard", "canard", "🦆", "ɛ̃ kanaʁ", "鸭子"),
            T(" jaune.", "jaune", "", "ʒon", "黄色的。"),
        ],
    },
    {
        "id": "a1_029",
        "text": "Deux cents grammes de riz.",
        "ipa": "dø sɑ̃ ɡʁam də ʁi",
        "translation": "两百克米。",
        "library": "A1",
        "tokens": [
            T("Deux cents grammes", "gramme", "⚖️", "dø sɑ̃ ɡʁam", "两百克"),
            T(" de riz.", "riz", "🍚", "də ʁi", "米。"),
        ],
    },
    {
        "id": "a1_030",
        "text": "Aïe ! Le doigt brûle !",
        "ipa": "aj lə dwa bʁyl",
        "translation": "哎哟！手指烫到了！",
        "library": "A1",
        "tokens": [
            T("Aïe !", "aïe", "", "aj", "哎哟！"),
            T(" Le doigt brûle !", "doigt", "🤌", "lə dwa bʁyl", "手指烫！"),
        ],
    },
    {
        "id": "a1_031",
        "text": "Le coude droit.",
        "ipa": "lə kud dʁwa",
        "translation": "右肘。",
        "library": "A1",
        "tokens": [
            T("Le coude", "coude", "🦾", "lə kud", "肘"),
            T(" droit.", "droit", "", "dʁwa", "右。"),
        ],
    },
    {
        "id": "a1_032",
        "text": "Le ventre qui gargouille.",
        "ipa": "lə vɑ̃tʁ ki ɡaʁɡuj",
        "translation": "肚子咕咕叫。",
        "library": "A1",
        "tokens": [
            T("Le ventre", "ventre", "🫃", "lə vɑ̃tʁ", "肚子"),
            T(" qui gargouille.", "gargouiller", "", "ki ɡaʁɡuj", "在咕咕叫。"),
        ],
    },
    {
        "id": "a1_033",
        "text": "Un grand verre d'eau.",
        "ipa": "ɛ̃ ɡʁɑ̃ vɛʁ do",
        "translation": "一大杯水。",
        "library": "A1",
        "tokens": [
            T("Un grand verre", "verre", "🥤", "ɛ̃ ɡʁɑ̃ vɛʁ", "一大杯"),
            T(" d'eau.", "eau", "💧", "do", "水。"),
        ],
    },
    {
        "id": "a1_034",
        "text": "Des cerises noires.",
        "ipa": "de səʁiz nwaʁ",
        "translation": "黑樱桃。",
        "library": "A1",
        "tokens": [
            T("Des cerises", "cerise", "🍒", "de səʁiz", "樱桃"),
            T(" noires.", "noir", "", "nwaʁ", "黑的。"),
        ],
    },
    {
        "id": "a1_035",
        "text": "Le premier jour d'école.",
        "ipa": "lə pʁəmje ʒuʁ dekol",
        "translation": "开学第一天。",
        "library": "A1",
        "tokens": [
            T("Le premier jour", "jour", "1️⃣", "lə pʁəmje ʒuʁ", "第一天"),
            T(" d'école.", "école", "🏫", "dekol", "上学。"),
        ],
    },
    {
        "id": "a1_036",
        "text": "Mille fois merci !",
        "ipa": "mil fwa mɛʁsi",
        "translation": "万分感谢！",
        "library": "A1",
        "tokens": [
            T("Mille fois", "mille", "🙏", "mil fwa", "千遍"),
            T(" merci !", "merci", "", "mɛʁsi", "谢谢！"),
        ],
    },
    {
        "id": "a1_037",
        "text": "Une écharpe rouge vif.",
        "ipa": "yn eʃaʁp ʁuʒ vif",
        "translation": "一条鲜红色围巾。",
        "library": "A1",
        "tokens": [
            T("Une écharpe", "écharpe", "🧣", "yn eʃaʁp", "围巾"),
            T(" rouge vif.", "rouge", "", "ʁuʒ vif", "鲜红。"),
        ],
    },
    {
        "id": "a1_038",
        "text": "Au deuxième étage.",
        "ipa": "o døzjɛm etaʒ",
        "translation": "在二楼（欧式计数第二层）。",
        "library": "A1",
        "tokens": [
            T("Au", "à", "", "o", "在"),
            T(" deuxième étage.", "étage", "🪜", "døzjɛm etaʒ", "二楼/三层。"),
        ],
    },
    {
        "id": "a1_039",
        "text": "J'ai mal au genou.",
        "ipa": "ʒe mal o ʒənu",
        "translation": "我膝盖疼。",
        "library": "A1",
        "tokens": [
            T("J'ai mal", "mal", "", "ʒe mal", "我疼"),
            T(" au genou.", "genou", "🦵", "o ʒənu", "膝盖。"),
        ],
    },
    {
        "id": "a1_040",
        "text": "Un hibou sur la branche.",
        "ipa": "ɛ̃ ibu syʁ la bʁɑ̃ʃ",
        "translation": "树枝上的猫头鹰。",
        "library": "A1",
        "tokens": [
            T("Un hibou", "hibou", "🦉", "ɛ̃ ibu", "猫头鹰"),
            T(" sur la branche.", "branche", "🌳", "syʁ la bʁɑ̃ʃ", "在树枝上。"),
        ],
    },
    {
        "id": "a1_041",
        "text": "Sa couleur préférée : le vert.",
        "ipa": "sa kulœʁ pʁefeʁe lə vɛʁ",
        "translation": "他/她最喜欢的颜色：绿色。",
        "library": "A1",
        "tokens": [
            T("Sa couleur préférée :", "couleur", "🎨", "sa kulœʁ pʁefeʁe", "最喜欢的颜色："),
            T(" le vert.", "vert", "💚", "lə vɛʁ", "绿色。"),
        ],
    },
    {
        "id": "a1_042",
        "text": "Le four est chaud.",
        "ipa": "lə fuʁ ɛ ʃo",
        "translation": "烤箱很烫。",
        "library": "A1",
        "tokens": [
            T("Le four", "four", "🔥", "lə fuʁ", "烤箱"),
            T(" est chaud.", "être", "", "ɛ ʃo", "很烫。"),
        ],
    },
    {
        "id": "a1_043",
        "text": "Un pull bleu marine.",
        "ipa": "ɛ̃ pyl blø maʁin",
        "translation": "一件海军蓝毛衣。",
        "library": "A1",
        "tokens": [
            T("Un pull", "pull", "🧥", "ɛ̃ pyl", "毛衣"),
            T(" bleu marine.", "bleu", "", "blø maʁin", "藏青色。"),
        ],
    },
    {
        "id": "a1_044",
        "text": "Les pieds dans le sable.",
        "ipa": "le pje dɑ̃ lə sabl",
        "translation": "脚踩在沙子里。",
        "library": "A1",
        "tokens": [
            T("Les pieds", "pied", "🦶", "le pje", "脚"),
            T(" dans le sable.", "sable", "🏖️", "dɑ̃ lə sabl", "在沙里。"),
        ],
    },
    {
        "id": "a1_045",
        "text": "Ouvre la bouche.",
        "ipa": "uvʁ la buʃ",
        "translation": "张开嘴。",
        "library": "A1",
        "tokens": [
            T("Ouvre", "ouvrir", "", "uvʁ", "张开"),
            T(" la bouche.", "bouche", "👄", "la buʃ", "嘴。"),
        ],
    },
    {
        "id": "a1_046",
        "text": "Zéro sucre ce matin.",
        "ipa": "zeʁo sykʁ sə matɛ̃",
        "translation": "今天早上零糖。",
        "library": "A1",
        "tokens": [
            T("Zéro sucre", "sucre", "🚫", "zeʁo sykʁ", "零糖"),
            T(" ce matin.", "matin", "🌅", "sə matɛ̃", "今早。"),
        ],
    },
    {
        "id": "a1_047",
        "text": "Une clé dans la poche.",
        "ipa": "yn kle dɑ̃ la pɔʃ",
        "translation": "口袋里的钥匙。",
        "library": "A1",
        "tokens": [
            T("Une clé", "clé", "🔑", "yn kle", "一把钥匙"),
            T(" dans la poche.", "poche", "👖", "dɑ̃ la pɔʃ", "在口袋里。"),
        ],
    },
    {
        "id": "a1_048",
        "text": "Vingt et un avril.",
        "ipa": "vɛ̃te œ̃ navʁil",
        "translation": "四月二十一日。",
        "library": "A1",
        "tokens": [
            T("Vingt et un", "vingt", "📅", "vɛ̃te œ̃", "二十一"),
            T(" avril.", "avril", "", "navʁil", "四月。"),
        ],
    },
    {
        "id": "a1_049",
        "text": "L'agneau et la brebis.",
        "ipa": "laɲo e la bʁəbis",
        "translation": "羊羔和母羊。",
        "library": "A1",
        "tokens": [
            T("L'agneau", "agneau", "🐑", "laɲo", "小羊"),
            T(" et la brebis.", "brebis", "🐏", "e la bʁəbis", "和母羊。"),
        ],
    },
    {
        "id": "a1_050",
        "text": "Mon sac à dos lourd.",
        "ipa": "mɔ̃ sak a do luʁ",
        "translation": "我沉重的双肩包。",
        "library": "A1",
        "tokens": [
            T("Mon sac à dos", "sac", "🎒", "mɔ̃ sak a do", "我的书包"),
            T(" lourd.", "lourd", "", "luʁ", "很沉。"),
        ],
    },
]


def ordered_row(s: dict) -> dict:
    """与现有 sm 条目一致：id, text, ipa, translation, tokens, library"""
    return {
        "id": s["id"],
        "text": s["text"],
        "ipa": s["ipa"],
        "translation": s["translation"],
        "tokens": s["tokens"],
        "library": s["library"],
    }


def main():
    assert len(NEW) == 50
    data = json.loads(PATH.read_text(encoding="utf-8"))
    existing = data["sentences"]
    have = {s["id"] for s in existing}
    rows = [ordered_row(s) for s in NEW]
    for s in rows:
        assert s["id"] not in have, s["id"]
        ntok = len(s["tokens"])
        assert 2 <= ntok <= 4, (s["id"], ntok)
    data["sentences"] = existing + rows
    PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"OK: 原有 {len(existing)} 句，追加 {len(NEW)} 句 → 共 {len(data['sentences'])} 句 → {PATH}")


if __name__ == "__main__":
    main()
