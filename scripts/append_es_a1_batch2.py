#!/usr/bin/env python3
"""Append es_a1_021..es_a1_100 to sentences_es.json. Run from repo root."""
import json
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "LearnLanguageLikeABaby" / "Resources" / "sentences_es.json"

# Common surface forms (after norm) that should count toward the keyword (lemma family / agreement).
EXTRA_FORMS: dict[str, list[str]] = {
    "mucho": ["mucha", "muchas", "muchos"],
    "poco": ["poca", "poquito"],
    "bien": ["bueno", "buena", "buenos", "buenas"],
    "mal": ["mala", "malo"],
    "cansado": ["cansada"],
    "contento": ["contenta"],
    "enfermo": ["enferma"],
    "caro": ["cara"],
    "barato": ["barata"],
    "rápido": ["rápida"],
    "cuánto": ["cuanta", "cuantas"],
    "tengo": ["tiene", "tienes", "tienen"],
    "quiero": ["quieres", "quiere", "quieren"],
    "puedo": ["puede", "puedes", "pueden"],
    "necesito": ["necesita", "necesitas"],
}


# Core lemmas to appear >= 3 times across the full A1 Spanish list (match normalized text + EXTRA_FORMS)
KEYWORDS = [
    "dónde", "cuánto", "cómo", "qué", "quién",
    "hambre", "sed", "cansado", "contento", "enfermo",
    "izquierda", "derecha", "recto", "cerca", "lejos",
    "precio", "caro", "barato", "mercado", "tienda",
    "hoy", "mañana", "ahora", "tarde", "pronto",
    "quiero", "necesito", "tengo", "puedo", "hay",
    "mucho", "poco", "bien", "mal", "rápido",
]


def norm(s: str) -> str:
    s = s.lower()
    s = "".join(c for c in unicodedata.normalize("NFD", s) if unicodedata.category(c) != "Mn")
    return s


def T(text, lemma, emoji, ipa, tr, has_img=None):
    hi = has_img if has_img is not None else bool(emoji)
    return {
        "text": text,
        "lemma": lemma,
        "hasImage": hi,
        "emoji": emoji or "",
        "ipa": ipa,
        "translation": tr,
    }


# 80 items: (text, translation, list of token dicts from T(...))
RAW: list[tuple[str, str, list[dict]]] = [
    ("¿Dónde está el baño?", "洗手间在哪？", [
        T("¿Dónde está", "dónde", "", "ˈdonde esˈta", "在哪"),
        T(" el baño?", None, "🚻", "el ˈbaɲo", "洗手间？"),
    ]),
    ("¿Cuánto cuesta esto?", "这个多少钱？", [
        T("¿Cuánto cuesta", "cuánto", "", "ˈkwanto ˈkwesta", "多少钱"),
        T(" esto?", None, "", "ˈesto", "这个？"),
    ]),
    ("¿Cómo llego al centro?", "我怎么到市中心？", [
        T("¿Cómo llego", "cómo", "", "ˈkomo ˈʎeɣo", "我怎么到"),
        T(" al centro?", None, "", "al ˈθentɾo", "市中心？"),
    ]),
    ("¿Qué hora es?", "几点了？", [
        T("¿Qué hora", "qué", "", "ke ˈoɾa", "几点"),
        T(" es?", None, "", "es", "了？"),
    ]),
    ("¿Quién puede ayudarme?", "谁能帮我？", [
        T("¿Quién puede", "quién", "", "ˈkjen ˈpweðe", "谁能"),
        T(" ayudarme?", None, "", "aʝuˈðaɾme", "帮我？"),
    ]),
    ("Tengo mucha hambre.", "我很饿。", [
        T("Tengo", "tengo", "", "ˈteŋɡo", "我"),
        T(" mucha hambre.", "hambre", "", "ˈmutʃa ˈambɾe", "很饿。"),
    ]),
    ("Tengo mucha sed.", "我很渴。", [
        T("Tengo", "tengo", "", "ˈteŋɡo", "我"),
        T(" mucha sed.", "sed", "", "ˈmutʃa seð", "很渴。"),
    ]),
    ("Estoy muy cansado.", "我很累。", [
        T("Estoy", None, "", "esˈtoi", "我"),
        T(" muy cansado.", "cansado", "", "mui kanˈsaðo", "很累。"),
    ]),
    ("Estoy contento.", "我很开心。", [
        T("Estoy", None, "", "esˈtoi", "我"),
        T(" contento.", "contento", "", "konˈtento", "很开心。"),
    ]),
    ("Me siento enfermo.", "我不舒服。", [
        T("Me siento", None, "", "me ˈsjento", "我感觉"),
        T(" enfermo.", "enfermo", "", "emˈfeɾmo", "不舒服。"),
    ]),
    ("A la izquierda, por favor.", "请往左。", [
        T("A la izquierda,", "izquierda", "", "a la iθˈkjerða", "左边，"),
        T(" por favor.", None, "", "poɾ faˈβoɾ", "请。"),
    ]),
    ("A la derecha.", "往右。", [
        T("A la", None, "", "a la", "往"),
        T(" derecha.", "derecha", "➡️", "ðeˈɾetʃa", "右。"),
    ]),
    ("Todo recto, por favor.", "请一直往前走。", [
        T("Todo recto,", "recto", "", "ˈtoðo ˈɾekto", "直直走，"),
        T(" por favor.", None, "", "poɾ faˈβoɾ", "请。"),
    ]),
    ("Está muy cerca.", "很近。", [
        T("Está", None, "", "esˈta", "很"),
        T(" muy cerca.", "cerca", "", "mui ˈθeɾka", "近。"),
    ]),
    ("Un poco lejos.", "有点远。", [
        T("Un poco", "poco", "", "uŋ ˈpoko", "有点"),
        T(" lejos.", "lejos", "", "ˈlexos", "远。"),
    ]),
    ("¿Cuál es el precio?", "价钱是多少？", [
        T("¿Cuál es", None, "", "ˈkwal es", "哪个是"),
        T(" el precio?", "precio", "💶", "el ˈpɾeθjo", "价钱？"),
    ]),
    ("Es muy caro.", "很贵。", [
        T("Es", None, "", "es", "很"),
        T(" muy caro.", "caro", "", "mui ˈkaɾo", "贵。"),
    ]),
    ("Muy barato, gracias.", "很便宜，谢谢。", [
        T("Muy barato,", "barato", "", "mui baˈɾato", "很便宜，"),
        T(" gracias.", None, "", "ˈɡɾaθjas", "谢谢。"),
    ]),
    ("Voy al mercado.", "我去市场。", [
        T("Voy", "voy", "", "ˈboi", "我去"),
        T(" al mercado.", "mercado", "🏪", "al meɾˈkaðo", "市场。"),
    ]),
    ("¿Dónde hay una tienda?", "哪有商店？", [
        T("¿Dónde hay", "dónde", "", "ˈdonde ˈai", "哪有"),
        T(" una tienda?", "tienda", "🏪", "ˈuna ˈtjenda", "商店？"),
    ]),
    ("Hoy no puedo.", "今天不行。", [
        T("Hoy", "hoy", "📅", "ˈoi", "今天"),
        T(" no puedo.", "puedo", "", "no ˈpweðo", "我不能。"),
    ]),
    ("Mañana, sin falta.", "明天一定。", [
        T("Mañana,", "mañana", "", "maˈɲana", "明天，"),
        T(" sin falta.", None, "", "siɱ ˈfalta", "一定。"),
    ]),
    ("Ahora mismo.", "马上。", [
        T("Ahora", "ahora", "", "aˈoɾa", "现在"),
        T(" mismo.", None, "", "ˈmismo", "就。"),
    ]),
    ("Buenas tardes.", "下午好。", [
        T("Buenas", None, "", "ˈbwenas", "下午"),
        T(" tardes.", "tarde", "🌤️", "ˈtaɾðes", "好。"),
    ]),
    ("¡Hasta pronto!", "一会儿见！", [
        T("¡Hasta", None, "", "ˈasta", "回头"),
        T(" pronto!", "pronto", "", "ˈpɾonto", "见！"),
    ]),
    ("Quiero agua, por favor.", "请给我水。", [
        T("Quiero", "quiero", "", "ˈkjeɾo", "我要"),
        T(" agua,", "agua", "💧", "ˈaɣwa", "水，"),
        T(" por favor.", None, "", "poɾ faˈβoɾ", "请。"),
    ]),
    ("Necesito ayuda.", "我需要帮助。", [
        T("Necesito", "necesito", "", "neˈθesito", "我需要"),
        T(" ayuda.", None, "", "aˈʝuða", "帮助。"),
    ]),
    ("El museo a la derecha.", "博物馆在右边。", [
        T("El museo", None, "🏛️", "el muˈseo", "博物馆"),
        T(" a la derecha.", "derecha", "", "a la ðeˈɾetʃa", "在右边。"),
    ]),
    ("¿Puedo pagar en efectivo?", "可以付现金吗？", [
        T("¿Puedo pagar", "puedo", "", "ˈpweðo paˈɣaɾ", "我能付"),
        T(" en efectivo?", None, "", "en efekˈtiβo", "现金吗？"),
    ]),
    ("¿Hay autobús aquí?", "这儿有公交车吗？", [
        T("¿Hay", "hay", "", "ˈai", "有"),
        T(" autobús", None, "🚌", "awtoˈβus", "公交车"),
        T(" aquí?", None, "", "aˈki", "这儿？"),
    ]),
    ("Abro la tienda.", "我开店。", [
        T("Abro", None, "", "ˈabɾo", "我开"),
        T(" la tienda.", "tienda", "", "la ˈtjenda", "店。"),
    ]),
    ("Pescado en el mercado.", "在市场买鱼。", [
        T("Pescado", None, "🐟", "pesˈkaðo", "鱼"),
        T(" en el mercado.", "mercado", "", "en el meɾˈkaðo", "在市场。"),
    ]),
    ("Muy bien, gracias.", "很好，谢谢。", [
        T("Muy bien,", "bien", "", "mui ˈbjɛn", "很好，"),
        T(" gracias.", None, "", "ˈɡɾaɾθjas", "谢谢。"),
    ]),
    ("Me siento mal.", "我不舒服。", [
        T("Me siento", None, "", "me ˈsjento", "我感觉"),
        T(" mal.", "mal", "", "mal", "不好。"),
    ]),
    ("Más rápido, por favor.", "请快一点。", [
        T("Más rápido,", "rápido", "", "mas ˈrapiðo", "快一点，"),
        T(" por favor.", None, "", "poɾ faˈβoɾ", "请。"),
    ]),
    ("¿Cuánto es en total?", "一共多少钱？", [
        T("¿Cuánto es", "cuánto", "", "ˈkwanto es", "一共"),
        T(" en total?", None, "", "en toˈtal", "多少？"),
    ]),
    ("¿Dónde queda el metro?", "地铁在哪？", [
        T("¿Dónde queda", "dónde", "", "ˈdonde ˈkeða", "在哪"),
        T(" el metro?", None, "🚇", "el ˈmetɾo", "地铁？"),
    ]),
    ("Hoy estoy enfermo.", "今天不舒服。", [
        T("Hoy estoy", None, "", "ˈoj esˈtoi", "今天我"),
        T(" enfermo.", "enfermo", "", "emˈfeɾmo", "不舒服。"),
    ]),
    ("Otra vez cansado.", "又累了。", [
        T("Otra vez", None, "", "ˈotɾa βes", "又一次"),
        T(" cansado.", "cansado", "", "kanˈsaðo", "累了。"),
    ]),
    ("Siempre contento.", "总是很开心。", [
        T("Siempre", None, "", "ˈsjempre", "总是"),
        T(" contento.", "contento", "", "konˈtento", "开心。"),
    ]),
    ("Muero de hambre.", "饿死了。", [
        T("Muero de", None, "", "ˈmweɾo ðe", "快饿死"),
        T(" hambre.", "hambre", "", "ˈambɾe", "了。"),
    ]),
    ("Un vaso de agua, tengo sed.", "一杯水，我渴了。", [
        T("Un vaso de agua,", None, "💧", "uŋ ˈbaso ðe ˈaɣwa", "一杯水，"),
        T(" tengo sed.", "sed", "", "ˈteŋɡo seð", "我渴了。"),
    ]),
    ("Muy cansado, necesito descansar.", "好累，我要歇一下。", [
        T("Muy cansado,", "cansado", "", "mui kanˈsaðo", "好累，"),
        T(" necesito descansar.", "necesito", "", "neˈθesito deskanˈsaɾ", "我要歇一下。"),
    ]),
    ("¡Qué contento estoy!", "好开心！", [
        T("¡Qué contento", "contento", "", "ke konˈtento", "多开心"),
        T(" estoy!", None, "", "esˈtoi", "我啊！"),
    ]),
    ("Mi hijo está enfermo.", "我孩子不舒服。", [
        T("Mi hijo", None, "", "mi ˈixo", "我孩子"),
        T(" está enfermo.", "enfermo", "", "esˈta emˈfeɾmo", "不舒服。"),
    ]),
    ("Gira a la izquierda.", "左转。", [
        T("Gira", None, "", "ˈxiɾa", "转"),
        T(" a la izquierda.", "izquierda", "⬅️", "a la iθˈkjerða", "左边。"),
    ]),
    ("La farmacia a la derecha.", "药店在右边。", [
        T("La farmacia", None, "💊", "la faɾˈmaθja", "药店"),
        T(" a la derecha.", "derecha", "", "a la ðeˈɾetʃa", "在右边。"),
    ]),
    ("Sigue todo recto.", "一直往前走。", [
        T("Sigue", None, "", "ˈsiɣe", "沿着"),
        T(" todo recto.", "recto", "", "ˈtoðo ˈɾekto", "直走。"),
    ]),
    ("¿Queda lejos?", "远吗？", [
        T("¿Queda", None, "", "ˈkeða", "在"),
        T(" lejos?", "lejos", "", "ˈlexos", "远吗？"),
    ]),
    ("El hotel cerca del mar.", "酒店靠海很近。", [
        T("El hotel", None, "🏨", "el oˈtel", "酒店"),
        T(" cerca del mar.", "cerca", "", "ˈθeɾka ðel ˈmaɾ", "离海很近。"),
    ]),
    ("Barato y bueno.", "又便宜又好。", [
        T("Barato", "barato", "", "baˈɾato", "便宜"),
        T(" y bueno.", "bien", "", "i ˈbweno", "又好。"),
    ]),
    ("Caro, no compro.", "太贵，我不买。", [
        T("Caro,", "caro", "", "ˈkaɾo", "贵，"),
        T(" no compro.", None, "", "no ˈkompɾo", "不买。"),
    ]),
    ("En el mercado hay fruta.", "市场里有水果。", [
        T("En el mercado", "mercado", "", "en el meɾˈkaðo", "市场里"),
        T(" hay fruta.", "hay", "", "ˈai ˈfɾuta", "有水果。"),
    ]),
    ("La tienda cierra ahora.", "店现在要关门了。", [
        T("La tienda", "tienda", "", "la ˈtjenda", "店"),
        T(" cierra ahora.", "ahora", "", "ˈθjera aˈoɾa", "现在关。"),
    ]),
    ("Mañana vuelvo.", "我明天回来。", [
        T("Mañana", "mañana", "", "maˈɲana", "明天"),
        T(" vuelvo.", None, "", "ˈβwelβo", "我回。"),
    ]),
    ("Necesito una bolsa.", "我要个袋子。", [
        T("Necesito", "necesito", "", "neˈθesito", "我要"),
        T(" una bolsa.", None, "🛍️", "ˈuna ˈbolsa", "个袋子。"),
    ]),
    ("Poco a poco.", "慢慢来。", [
        T("Poco a", "poco", "", "ˈpoko a", "慢慢"),
        T(" poco.", "poco", "", "ˈpoko", "来。"),
    ]),
    ("Está muy barata.", "很便宜。", [
        T("Está muy", None, "", "esˈta mui", "很"),
        T(" barata.", "barato", "", "baˈɾata", "便宜。"),
    ]),
    ("El banco está lejos.", "银行很远。", [
        T("El banco", None, "🏦", "el ˈbaŋko", "银行"),
        T(" está lejos.", "lejos", "", "esˈta ˈlexos", "很远。"),
    ]),
    ("Todo muy rápido.", "一切都很快。", [
        T("Todo", None, "", "ˈtoðo", "一切"),
        T(" muy rápido.", "rápido", "", "mui ˈrapiðo", "很快。"),
    ]),
    ("Te veo pronto.", "回头见。", [
        T("Te veo", None, "", "te ˈβe.o", "见你"),
        T(" pronto.", "pronto", "", "ˈpɾonto", "马上。"),
    ]),
    ("¿Quién falta?", "谁没来？", [
        T("¿Quién", "quién", "", "ˈkjen", "谁"),
        T(" falta?", None, "", "ˈfalta", "没来？"),
    ]),
    ("Llego tarde, lo siento.", "对不起我迟到了。", [
        T("Llego tarde,", "tarde", "", "ˈʎeɣo ˈtaɾðe", "迟到了，"),
        T(" lo siento.", None, "", "lo ˈsjento", "抱歉。"),
    ]),
    ("Vuelvo pronto.", "马上回来。", [
        T("Vuelvo", None, "", "ˈβwelβo", "我回"),
        T(" pronto.", "pronto", "", "ˈpɾonto", "马上。"),
    ]),
    ("Muchas gracias, hasta mañana.", "谢谢，明天见。", [
        T("Muchas gracias,", "mucho", "🙏", "ˈmutʃas ˈɡɾaθjas", "多谢，"),
        T(" hasta mañana.", "mañana", "", "ˈasta maˈɲana", "明天见。"),
    ]),
    ("Quiero la cuenta.", "我要结账。", [
        T("Quiero", "quiero", "", "ˈkjeɾo", "我要"),
        T(" la cuenta.", None, "🧾", "la ˈkwenta", "账单。"),
    ]),
    ("Tengo frío.", "我冷。", [
        T("Tengo", "tengo", "", "ˈteŋɡo", "我"),
        T(" frío.", None, "🥶", "ˈfɾio", "冷。"),
    ]),
    ("¿Cómo te llamas? ¿Rápido?", "你叫什么？快说。", [
        T("¿Cómo te llamas?", "cómo", "", "ˈkomo te ˈʎamas", "你叫什么？"),
        T(" ¿Rápido?", "rápido", "", "ˈrapiðo", "快点？"),
    ]),
    ("¿Quién es el dueño?", "老板是谁？", [
        T("¿Quién es", "quién", "", "ˈkjen es", "谁是"),
        T(" el dueño?", None, "", "el ˈdweɲo", "老板？"),
    ]),
    ("¿Dónde puedo comprar billetes?", "在哪买票？", [
        T("¿Dónde puedo", "dónde", "", "ˈdonde ˈpweðo", "在哪能"),
        T(" comprar billetes?", None, "🎫", "komˈpɾaɾ biˈʎetes", "买票？"),
    ]),
    ("¿Cuánto demora?", "要多久？", [
        T("¿Cuánto", "cuánto", "", "ˈkwanto", "多少"),
        T(" demora?", None, "", "deˈmoɾa", "要等？"),
    ]),
    ("La salida a la izquierda.", "出口在左边。", [
        T("La salida", None, "🚪", "la saˈliða", "出口"),
        T(" a la izquierda.", "izquierda", "", "a la iθˈkjerða", "在左边。"),
    ]),
    ("Mira el precio, por favor.", "请看价格。", [
        T("Mira el precio,", None, "💶", "ˈmiɾa el ˈpɾeθjo", "看价格，"),
        T(" por favor.", None, "", "poɾ faˈβoɾ", "请。"),
    ]),
    ("Salud, tengo sed.", "干杯，我渴了（打趣）。", [
        T("Salud,", None, "🥂", "saˈluð", "干杯，"),
        T(" tengo sed.", "sed", "", "ˈteŋɡo seð", "我渴了。"),
    ]),
    ("No tengo hambre.", "我不饿。", [
        T("No tengo", "tengo", "", "no ˈteŋɡo", "我不"),
        T(" hambre.", "hambre", "", "ˈambɾe", "饿。"),
    ]),
    ("Por aquí, muy cerca.", "从这儿，很近。", [
        T("Por aquí,", None, "", "poɾ aˈki", "从这儿，"),
        T(" muy cerca.", "cerca", "", "mui ˈθeɾka", "很近。"),
    ]),
    ("Recto hasta el semáforo.", "直行到红绿灯。", [
        T("Recto hasta", "recto", "", "ˈɾekto ˈasta", "直到"),
        T(" el semáforo.", None, "🚦", "el seˈmafoɾo", "红绿灯。"),
    ]),
    ("Precio fijo, sin regateo.", "标价不二价。", [
        T("Precio fijo,", "precio", "", "ˈpɾeθjo ˈfixo", "定价，"),
        T(" sin regateo.", None, "", "siɱ reɣaˈteo", "不砍价。"),
    ]),
    ("Un poco más caro.", "贵了一点。", [
        T("Un poco", "poco", "", "uŋ ˈpoko", "一点"),
        T(" más caro.", "caro", "", "ˈmas ˈkaɾo", "更贵。"),
    ]),
    ("Ahora no, más tarde.", "现在不行，晚点。", [
        T("Ahora no,", "ahora", "", "aˈoɾa no", "现在不，"),
        T(" más tarde.", "tarde", "", "ˈmas ˈtaɾðe", "晚点。"),
    ]),
]

assert len(RAW) == 80, len(RAW)


def sentence_ipa(segments: list[dict]) -> str:
    parts = [(t.get("ipa") or "").strip() for t in segments]
    return " ".join(p for p in parts if p)


def build_sentence(idx: int, text: str, translation: str, tokens: list[dict]) -> dict:
    return {
        "id": f"es_a1_{idx:03d}",
        "text": text,
        "ipa": sentence_ipa(tokens),
        "translation": translation,
        "library": "A1",
        "tokens": tokens,
    }


def main():
    data = json.loads(PATH.read_text(encoding="utf-8"))
    existing = data["sentences"]
    assert len(existing) == 20

    start = 21
    new_sents = [
        build_sentence(start + i, text, tr, toks)
        for i, (text, tr, toks) in enumerate(RAW)
    ]

    joined = existing + new_sents
    assert len(joined) == 100

    # 核心词在「整份西语 A1」中各至少 3 次（含原有 20 条 + 新增 80 条）
    blob = " ".join(s["text"] for s in joined)
    nb = norm(blob)
    def keyword_hits(blob_norm: str, kw: str) -> int:
        kwn = norm(kw)
        n = blob_norm.count(kwn)
        for alt in EXTRA_FORMS.get(kw, []):
            n += blob_norm.count(norm(alt))
        return n

    bad = []
    for kw in KEYWORDS:
        hits = keyword_hits(nb, kw)
        if hits < 3:
            bad.append((kw, hits))
    if bad:
        raise SystemExit(f"Keyword count fail: {bad}")

    for s in new_sents:
        ntok = len(s["tokens"])
        assert 2 <= ntok <= 4, (s["id"], ntok)

    PATH.write_text(json.dumps({"sentences": joined}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("OK: 100 sentences, keyword mins satisfied.")


if __name__ == "__main__":
    main()
