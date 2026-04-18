#!/usr/bin/env python3
"""Generate sentences_es.json and exampleSentences_es.json for the app bundle."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "LearnLanguageLikeABaby" / "Resources"


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


SENTENCES = [
    {
        "id": "es_a1_001",
        "text": "Quiero un café, por favor.",
        "ipa": "ˈkjeɾo uŋ kaˈfe poɾ faˈβoɾ",
        "translation": "我想要一杯咖啡，请。",
        "library": "A1",
        "tokens": [
            T("Quiero", "quiero", "", "ˈkjeɾo", "我想要"),
            T(" un café,", "café", "☕", "uŋ kaˈfe", "一杯咖啡，"),
            T(" por favor.", None, "", "poɾ faˈβoɾ", "请。"),
        ],
    },
    {
        "id": "es_a1_002",
        "text": "Bebo agua fría.",
        "ipa": "ˈbeβo ˈaɣwa ˈfɾi.a",
        "translation": "我喝冷水。",
        "library": "A1",
        "tokens": [
            T("Bebo", "bebo", "", "ˈbeβo", "我喝"),
            T(" agua", "agua", "💧", "ˈaɣwa", "水"),
            T(" fría.", "frío", "", "ˈfɾi.a", "冷的。"),
        ],
    },
    {
        "id": "es_a1_003",
        "text": "Tengo pan y leche.",
        "ipa": "ˈteŋɡo paɲ i ˈlet͡ʃe",
        "translation": "我有面包和牛奶。",
        "library": "A1",
        "tokens": [
            T("Tengo", "tengo", "", "ˈteŋɡo", "我有"),
            T(" pan", "pan", "🍞", "paɲ", "面包"),
            T(" y leche.", "leche", "🥛", "i ˈlet͡ʃe", "和牛奶。"),
        ],
    },
    {
        "id": "es_a1_004",
        "text": "Como una manzana roja.",
        "ipa": "ˈkomo ˈuna manˈθana ˈrox.a",
        "translation": "我吃一个红苹果。",
        "library": "A1",
        "tokens": [
            T("Como", "como", "", "ˈkomo", "我吃"),
            T(" una manzana", "manzana", "🍎", "ˈuna manˈθana", "一个苹果"),
            T(" roja.", "rojo", "", "ˈrox.a", "红色的。"),
        ],
    },
    {
        "id": "es_a1_005",
        "text": "El gato es pequeño.",
        "ipa": "el ˈɡato es peˈkeɲo",
        "translation": "猫很小。",
        "library": "A1",
        "tokens": [
            T("El gato", "gato", "🐱", "el ˈɡato", "猫"),
            T(" es", None, "", "es", "是"),
            T(" pequeño.", "pequeño", "", "peˈkeɲo", "小的。"),
        ],
    },
    {
        "id": "es_a1_006",
        "text": "El perro es grande.",
        "ipa": "el ˈpero es ˈɡɾande",
        "translation": "狗很大。",
        "library": "A1",
        "tokens": [
            T("El perro", "perro", "🐶", "el ˈpero", "狗"),
            T(" es", None, "", "es", "是"),
            T(" grande.", "grande", "", "ˈɡɾande", "大的。"),
        ],
    },
    {
        "id": "es_a1_007",
        "text": "Veo un pájaro en el árbol.",
        "ipa": "ˈbeo uŋ paˈxaɾo en el ˈaɾβol",
        "translation": "我看见树上一只鸟。",
        "library": "A1",
        "tokens": [
            T("Veo", None, "", "ˈbeo", "我看见"),
            T(" un pájaro", "pájaro", "🐦", "uŋ paˈxaɾo", "一只鸟"),
            T(" en el árbol.", None, "", "en el ˈaɾβol", "在树上。"),
        ],
    },
    {
        "id": "es_a1_008",
        "text": "Mamá cocina el pescado.",
        "ipa": "maˈma koˈθina el pesˈkaðo",
        "translation": "妈妈在做鱼。",
        "library": "A1",
        "tokens": [
            T("Mamá", "mamá", "👩", "maˈma", "妈妈"),
            T(" cocina", None, "", "koˈθina", "做饭"),
            T(" el pescado.", "pescado", "🐟", "el pesˈkaðo", "鱼。"),
        ],
    },
    {
        "id": "es_a1_009",
        "text": "Papá lee un libro.",
        "ipa": "ˈpapa ˈlee uŋ ˈliβɾo",
        "translation": "爸爸在读一本书。",
        "library": "A1",
        "tokens": [
            T("Papá", "papá", "👨", "ˈpapa", "爸爸"),
            T(" lee", None, "", "ˈlee", "读"),
            T(" un libro.", None, "", "uŋ ˈliβɾo", "一本书。"),
        ],
    },
    {
        "id": "es_a1_010",
        "text": "Uno, dos, tres — ya está.",
        "ipa": "ˈuno dos tɾes ja esˈta",
        "translation": "一，二，三——好了。",
        "library": "A1",
        "tokens": [
            T("Uno, dos, tres —", "uno", "", "ˈuno dos tɾes", "一，二，三——"),
            T(" ya está.", None, "", "ja esˈta", "好了。"),
        ],
    },
    {
        "id": "es_a1_011",
        "text": "Voy a casa con mamá.",
        "ipa": "ˈboi a ˈkasa kɔn maˈma",
        "translation": "我和妈妈回家。",
        "library": "A1",
        "tokens": [
            T("Voy", "voy", "", "ˈboi", "我去"),
            T(" a casa", None, "", "a ˈkasa", "回家"),
            T(" con mamá.", "mamá", "👩", "kɔn maˈma", "和妈妈。"),
        ],
    },
    {
        "id": "es_a1_012",
        "text": "El café está caliente.",
        "ipa": "el kaˈfe esˈta kaˈljente",
        "translation": "咖啡很烫。",
        "library": "A1",
        "tokens": [
            T("El café", "café", "☕", "el kaˈfe", "咖啡"),
            T(" está", None, "", "esˈta", "很"),
            T(" caliente.", "caliente", "", "kaˈljente", "烫的。"),
        ],
    },
    {
        "id": "es_a1_013",
        "text": "La sopa está mala.",
        "ipa": "la ˈsopa esˈta ˈmala",
        "translation": "汤不好喝。",
        "library": "A1",
        "tokens": [
            T("La sopa", None, "", "la ˈsopa", "汤"),
            T(" está", None, "", "esˈta", "很"),
            T(" mala.", "malo", "", "ˈmala", "不好的。"),
        ],
    },
    {
        "id": "es_a1_014",
        "text": "Este pan está bueno.",
        "ipa": "ˈeste paɲ esˈta ˈbweno",
        "translation": "这个面包很好吃。",
        "library": "A1",
        "tokens": [
            T("Este pan", "pan", "🍞", "ˈeste paɲ", "这个面包"),
            T(" está", None, "", "esˈta", "很"),
            T(" bueno.", "bueno", "", "ˈbweno", "好吃的。"),
        ],
    },
    {
        "id": "es_a1_015",
        "text": "Tengo dos perros.",
        "ipa": "ˈteŋɡo dos ˈperos",
        "translation": "我有两只狗。",
        "library": "A1",
        "tokens": [
            T("Tengo", "tengo", "", "ˈteŋɡo", "我有"),
            T(" dos", "dos", "", "dos", "两"),
            T(" perros.", "perro", "🐶", "ˈperos", "只狗。"),
        ],
    },
    {
        "id": "es_a1_016",
        "text": "Quiero tres manzanas.",
        "ipa": "ˈkjeɾo tɾes manˈθanas",
        "translation": "我想要三个苹果。",
        "library": "A1",
        "tokens": [
            T("Quiero", "quiero", "", "ˈkjeɾo", "我想要"),
            T(" tres", "tres", "", "tɾes", "三"),
            T(" manzanas.", "manzana", "🍎", "manˈθanas", "个苹果。"),
        ],
    },
    {
        "id": "es_a1_017",
        "text": "Mi mamá bebe leche.",
        "ipa": "mi maˈma ˈbeβe ˈlet͡ʃe",
        "translation": "我妈妈喝牛奶。",
        "library": "A1",
        "tokens": [
            T("Mi mamá", "mamá", "👩", "mi maˈma", "我妈妈"),
            T(" bebe", None, "", "ˈbeβe", "喝"),
            T(" leche.", "leche", "🥛", "ˈlet͡ʃe", "牛奶。"),
        ],
    },
    {
        "id": "es_a1_018",
        "text": "Papá tiene un gato negro.",
        "ipa": "ˈpapa ˈtjene uŋ ˈɡato ˈneɣɾo",
        "translation": "爸爸有一只黑猫。",
        "library": "A1",
        "tokens": [
            T("Papá", "papá", "👨", "ˈpapa", "爸爸"),
            T(" tiene", "tengo", "", "ˈtjene", "有"),
            T(" un gato negro.", "gato", "🐱", "uŋ ˈɡato ˈneɣɾo", "一只黑猫。"),
        ],
    },
    {
        "id": "es_a1_019",
        "text": "Hoy hace calor y bebo agua.",
        "ipa": "ˈoi ˈaθe kaˈloɾ i ˈbeβo ˈaɣwa",
        "translation": "今天很热，我喝水。",
        "library": "A1",
        "tokens": [
            T("Hoy hace calor", None, "", "ˈoj ˈaθe kaˈloɾ", "今天很热，"),
            T(" y bebo", "bebo", "", "i ˈbeβo", "我喝"),
            T(" agua.", "agua", "💧", "ˈaɣwa", "水。"),
        ],
    },
    {
        "id": "es_a1_020",
        "text": "Voy al parque con papá.",
        "ipa": "ˈboi al ˈpaɾke kɔn ˈpapa",
        "translation": "我和爸爸去公园。",
        "library": "A1",
        "tokens": [
            T("Voy", "voy", "", "ˈboi", "我去"),
            T(" al parque", None, "", "al ˈpaɾke", "公园"),
            T(" con papá.", "papá", "👨", "kɔn ˈpapa", "和爸爸。"),
        ],
    },
]

EXAMPLES = {
    "agua": [
        {
            "id": "es-ex-agua-1",
            "text": "Quiero un vaso de agua.",
            "ipa": "ˈkjeɾo uŋ ˈbaso ðe ˈaɣwa",
            "translation": "我想要一杯水。",
            "tokens": [
                T("Quiero", "quiero", "", "ˈkjeɾo", "我想要"),
                T(" un vaso de agua.", "agua", "💧", "uŋ ˈbaso ðe ˈaɣwa", "一杯水。"),
            ],
        },
        {
            "id": "es-ex-agua-2",
            "text": "El agua está muy fría.",
            "ipa": "el ˈaɣwa esˈta mwi ˈfɾi.a",
            "translation": "水很凉。",
            "tokens": [
                T("El agua", "agua", "💧", "el ˈaɣwa", "水"),
                T(" está muy", None, "", "esˈta mwi", "很"),
                T(" fría.", "frío", "", "ˈfɾi.a", "凉的。"),
            ],
        },
    ],
    "pan": [
        {
            "id": "es-ex-pan-1",
            "text": "Compramos pan fresco.",
            "ipa": "kɔmˈpɾamos paɲ ˈfɾesko",
            "translation": "我们买新鲜面包。",
            "tokens": [
                T("Compramos", None, "", "kɔmˈpɾamos", "我们买"),
                T(" pan", "pan", "🍞", "paɲ", "面包"),
                T(" fresco.", None, "", "ˈfɾesko", "新鲜的。"),
            ],
        },
        {
            "id": "es-ex-pan-2",
            "text": "El pan huele bien.",
            "ipa": "el paɲ ˈwele ˈbjɛn",
            "translation": "面包闻起来很香。",
            "tokens": [
                T("El pan", "pan", "🍞", "el paɲ", "面包"),
                T(" huele", None, "", "ˈwele", "闻起来"),
                T(" bien", "bueno", "", "ˈbjɛn", "很好。"),
            ],
        },
    ],
    "leche": [
        {
            "id": "es-ex-leche-1",
            "text": "Los niños beben leche.",
            "ipa": "los ˈniɲos ˈbeβen ˈlet͡ʃe",
            "translation": "孩子们喝牛奶。",
            "tokens": [
                T("Los niños", None, "", "los ˈniɲos", "孩子们"),
                T(" beben", "bebo", "", "ˈbeβen", "喝"),
                T(" leche.", "leche", "🥛", "ˈlet͡ʃe", "牛奶。"),
            ],
        },
        {
            "id": "es-ex-leche-2",
            "text": "La leche está en la nevera.",
            "ipa": "la ˈlet͡ʃe esˈta en la neˈβeɾa",
            "translation": "牛奶在冰箱里。",
            "tokens": [
                T("La leche", "leche", "🥛", "la ˈlet͡ʃe", "牛奶"),
                T(" está en", None, "", "esˈta en", "在"),
                T(" la nevera.", None, "", "la neˈβeɾa", "冰箱里。"),
            ],
        },
    ],
    "café": [
        {
            "id": "es-ex-cafe-1",
            "text": "Tomamos café por la mañana.",
            "ipa": "toˈmamos kaˈfe poɾ la maˈɲana",
            "translation": "我们早上喝咖啡。",
            "tokens": [
                T("Tomamos", None, "", "toˈmamos", "我们喝"),
                T(" café", "café", "☕", "kaˈfe", "咖啡"),
                T(" por la mañana.", None, "", "poɾ la maˈɲana", "在早上。"),
            ],
        },
        {
            "id": "es-ex-cafe-2",
            "text": "Este café es muy fuerte.",
            "ipa": "ˈeste kaˈfe es mwi ˈfweɾte",
            "translation": "这咖啡很浓。",
            "tokens": [
                T("Este café", "café", "☕", "ˈeste kaˈfe", "这咖啡"),
                T(" es muy", None, "", "es mwi", "很"),
                T(" fuerte.", None, "", "ˈfweɾte", "浓。"),
            ],
        },
    ],
    "manzana": [
        {
            "id": "es-ex-manzana-1",
            "text": "Hay manzanas en la cesta.",
            "ipa": "ˈai manˈθanas en la ˈθesta",
            "translation": "篮子里有苹果。",
            "tokens": [
                T("Hay", None, "", "ˈai", "有"),
                T(" manzanas", "manzana", "🍎", "manˈθanas", "苹果"),
                T(" en la cesta.", None, "", "en la ˈθesta", "在篮子里。"),
            ],
        },
        {
            "id": "es-ex-manzana-2",
            "text": "Corta la manzana en dos.",
            "ipa": "ˈkoɾta la manˈθana en dos",
            "translation": "把苹果切成两半。",
            "tokens": [
                T("Corta", None, "", "ˈkoɾta", "切"),
                T(" la manzana", "manzana", "🍎", "la manˈθana", "苹果"),
                T(" en dos.", "dos", "", "en dos", "成两半。"),
            ],
        },
    ],
    "gato": [
        {
            "id": "es-ex-gato-1",
            "text": "Mi gato duerme en el sofá.",
            "ipa": "mi ˈɡato ˈdweɾme en el soˈfa",
            "translation": "我的猫在沙发上睡觉。",
            "tokens": [
                T("Mi gato", "gato", "🐱", "mi ˈɡato", "我的猫"),
                T(" duerme", None, "", "ˈdweɾme", "睡觉"),
                T(" en el sofá.", None, "", "en el soˈfa", "在沙发上。"),
            ],
        },
        {
            "id": "es-ex-gato-2",
            "text": "El gato persigue un ratón.",
            "ipa": "el ˈɡato peɾˈsiɣe uŋ raˈton",
            "translation": "猫在追老鼠。",
            "tokens": [
                T("El gato", "gato", "🐱", "el ˈɡato", "猫"),
                T(" persigue", None, "", "peɾˈsiɣe", "追"),
                T(" un ratón.", None, "", "uŋ raˈton", "一只老鼠。"),
            ],
        },
    ],
    "perro": [
        {
            "id": "es-ex-perro-1",
            "text": "El perro ladra al cartero.",
            "ipa": "el ˈpero ˈlaðɾa al kaɾˈteɾo",
            "translation": "狗对邮递员叫。",
            "tokens": [
                T("El perro", "perro", "🐶", "el ˈpero", "狗"),
                T(" ladra", None, "", "ˈlaðɾa", "叫"),
                T(" al cartero.", None, "", "al kaɾˈteɾo", "邮递员。"),
            ],
        },
        {
            "id": "es-ex-perro-2",
            "text": "Paseo con mi perro.",
            "ipa": "paˈseo kɔn mi ˈpero",
            "translation": "我遛我的狗。",
            "tokens": [
                T("Paseo", None, "", "paˈseo", "散步"),
                T(" con mi perro.", "perro", "🐶", "kɔn mi ˈpero", "和我的狗。"),
            ],
        },
    ],
    "pájaro": [
        {
            "id": "es-ex-pajaro-1",
            "text": "Los pájaros cantan al amanecer.",
            "ipa": "los paˈxaɾos ˈkantan al amaneˈθeɾ",
            "translation": "鸟儿清晨歌唱。",
            "tokens": [
                T("Los pájaros", "pájaro", "🐦", "los paˈxaɾos", "鸟"),
                T(" cantan", None, "", "ˈkantan", "唱"),
                T(" al amanecer.", None, "", "al amaneˈθeɾ", "在黎明。"),
            ],
        },
        {
            "id": "es-ex-pajaro-2",
            "text": "Un pájaro vuela bajo el puente.",
            "ipa": "uŋ paˈxaɾo ˈbwela ˈbaxo el ˈpwente",
            "translation": "一只鸟从桥下飞过。",
            "tokens": [
                T("Un pájaro", "pájaro", "🐦", "uŋ paˈxaɾo", "一只鸟"),
                T(" vuela", None, "", "ˈbwela", "飞"),
                T(" bajo el puente.", None, "", "ˈbaxo el ˈpwente", "在桥下。"),
            ],
        },
    ],
    "quiero": [
        {
            "id": "es-ex-quiero-1",
            "text": "Quiero ir al cine.",
            "ipa": "ˈkjeɾo iɾ al ˈθine",
            "translation": "我想去电影院。",
            "tokens": [
                T("Quiero", "quiero", "", "ˈkjeɾo", "我想"),
                T(" ir", None, "", "iɾ", "去"),
                T(" al cine.", None, "", "al ˈθine", "电影院。"),
            ],
        },
        {
            "id": "es-ex-quiero-2",
            "text": "Quiero dormir temprano.",
            "ipa": "ˈkjeɾo ðoɾˈmiɾ temˈpɾano",
            "translation": "我想早点睡。",
            "tokens": [
                T("Quiero", "quiero", "", "ˈkjeɾo", "我想"),
                T(" dormir", None, "", "ðoɾˈmiɾ", "睡觉"),
                T(" temprano.", None, "", "temˈpɾano", "早。"),
            ],
        },
    ],
    "tengo": [
        {
            "id": "es-ex-tengo-1",
            "text": "Tengo hambre ahora.",
            "ipa": "ˈteŋɡo ˈambɾe aˈoɾa",
            "translation": "我现在饿了。",
            "tokens": [
                T("Tengo", "tengo", "", "ˈteŋɡo", "我有"),
                T(" hambre", None, "", "ˈambɾe", "饿"),
                T(" ahora.", None, "", "aˈoɾa", "现在。"),
            ],
        },
        {
            "id": "es-ex-tengo-2",
            "text": "Tengo miedo de la tormenta.",
            "ipa": "ˈteŋɡo ˈmjedo ðe la toɾˈmenta",
            "translation": "我害怕暴风雨。",
            "tokens": [
                T("Tengo", "tengo", "", "ˈteŋɡo", "我有"),
                T(" miedo", None, "", "ˈmjedo", "害怕"),
                T(" de la tormenta.", None, "", "ðe la toɾˈmenta", "暴风雨。"),
            ],
        },
    ],
    "voy": [
        {
            "id": "es-ex-voy-1",
            "text": "Voy a la escuela.",
            "ipa": "ˈboj a la esˈkwela",
            "translation": "我去学校。",
            "tokens": [
                T("Voy", "voy", "", "ˈboj", "我去"),
                T(" a la escuela.", None, "", "a la esˈkʷela", "学校。"),
            ],
        },
        {
            "id": "es-ex-voy-2",
            "text": "Voy de compras el sábado.",
            "ipa": "ˈboj de ˈkɔmpɾas el ˈsaβaðo",
            "translation": "我周六去购物。",
            "tokens": [
                T("Voy", "voy", "", "ˈboj", "我去"),
                T(" de compras", None, "", "de ˈkɔmpɾas", "购物"),
                T(" el sábado.", None, "", "el ˈsaβaðo", "周六。"),
            ],
        },
    ],
    "como": [
        {
            "id": "es-ex-como-1",
            "text": "Como arroz todos los días.",
            "ipa": "ˈkomo aˈroθ ˈtosos los ˈdi.as",
            "translation": "我每天吃米饭。",
            "tokens": [
                T("Como", "como", "", "ˈkomo", "我吃"),
                T(" arroz", None, "", "aˈroθ", "米饭"),
                T(" todos los días.", None, "", "ˈtosos los ˈdi.as", "每天。"),
            ],
        },
        {
            "id": "es-ex-como-2",
            "text": "Como poco por la noche.",
            "ipa": "ˈkomo ˈpoko poɾ la ˈnot͡ʃe",
            "translation": "我晚上吃得少。",
            "tokens": [
                T("Como", "como", "", "ˈkomo", "我吃"),
                T(" poco", None, "", "ˈpoko", "少"),
                T(" por la noche.", None, "", "poɾ la ˈnot͡ʃe", "晚上。"),
            ],
        },
    ],
    "bebo": [
        {
            "id": "es-ex-bebo-1",
            "text": "Bebo zumo de naranja.",
            "ipa": "ˈbeβo ˈsumo ðe naˈɾaŋxa",
            "translation": "我喝橙汁。",
            "tokens": [
                T("Bebo", "bebo", "", "ˈbeβo", "我喝"),
                T(" zumo", None, "", "ˈsumo", "果汁de"),
                T(" de naranja.", None, "", "ðe naˈɾaŋxa", "橙子。"),
            ],
        },
        {
            "id": "es-ex-bebo-2",
            "text": "Bebo té cuando llueve.",
            "ipa": "ˈbeβo ˈte ˈkwando ˈʎweβe",
            "translation": "下雨的时候我喝茶。",
            "tokens": [
                T("Bebo", "bebo", "", "ˈbeβo", "我喝"),
                T(" té", None, "", "ˈte", "茶"),
                T(" cuando llueve.", None, "", "ˈkwando ˈʎweβe", "当下雨时。"),
            ],
        },
    ],
    "grande": [
        {
            "id": "es-ex-grande-1",
            "text": "La casa es grande.",
            "ipa": "la ˈkasa es ˈɡɾande",
            "translation": "房子很大。",
            "tokens": [
                T("La casa", None, "", "la ˈkasa", "房子"),
                T(" es", None, "", "es", "是"),
                T(" grande.", "grande", "", "ˈɡɾande", "大的。"),
            ],
        },
        {
            "id": "es-ex-grande-2",
            "text": "Necesito una bolsa grande.",
            "ipa": "neˈθesito ˈuna ˈbolsa ˈɡɾande",
            "translation": "我需要一个大袋子。",
            "tokens": [
                T("Necesito", None, "", "neˈθesito", "我需要"),
                T(" una bolsa", None, "", "ˈuna ˈbolsa", "一个袋子"),
                T(" grande.", "grande", "", "ˈɡɾande", "大的。"),
            ],
        },
    ],
    "pequeño": [
        {
            "id": "es-ex-pequeno-1",
            "text": "El bebé es muy pequeño.",
            "ipa": "el beˈβe es mwi peˈkeɲo",
            "translation": "宝宝很小。",
            "tokens": [
                T("El bebé", None, "", "el beˈβe", "宝宝"),
                T(" es muy", None, "", "es mwi", "很"),
                T(" pequeño.", "pequeño", "", "peˈkeɲo", "小。"),
            ],
        },
        {
            "id": "es-ex-pequeno-2",
            "text": "Prefiero un coche pequeño.",
            "ipa": "pɾeˈfjeɾo uŋ ˈkot͡ʃe peˈkeɲo",
            "translation": "我更喜欢小车。",
            "tokens": [
                T("Prefiero", None, "", "pɾeˈfjeɾo", "我更喜欢"),
                T(" un coche", None, "", "uŋ ˈkot͡ʃe", "一辆车"),
                T(" pequeño.", "pequeño", "", "peˈkeɲo", "小的。"),
            ],
        },
    ],
    "bueno": [
        {
            "id": "es-ex-bueno-1",
            "text": "Es un día bueno.",
            "ipa": "es uŋ ˈdi.a ˈbweno",
            "translation": "今天天气不错。",
            "tokens": [
                T("Es", None, "", "es", "是"),
                T(" un día", None, "", "uŋ ˈdi.a", "一天"),
                T(" bueno.", "bueno", "", "ˈbweno", "好的。"),
            ],
        },
        {
            "id": "es-ex-bueno-2",
            "text": "Eres bueno conmigo.",
            "ipa": "ˈeɾes ˈbweno kɔnˈmiɣo",
            "translation": "你对我很好。",
            "tokens": [
                T("Eres", None, "", "ˈeɾes", "你是"),
                T(" bueno", "bueno", "", "ˈbweno", "好"),
                T(" conmigo.", None, "", "kɔnˈmiɣo", "对我。"),
            ],
        },
    ],
    "malo": [
        {
            "id": "es-ex-malo-1",
            "text": "Este vino está malo.",
            "ipa": "ˈeste ˈβino esˈta ˈmalo",
            "translation": "这酒坏了。",
            "tokens": [
                T("Este vino", None, "", "ˈeste ˈβino", "这酒"),
                T(" está", None, "", "esˈta", "很"),
                T(" malo.", "malo", "", "ˈmalo", "坏的。"),
            ],
        },
        {
            "id": "es-ex-malo-2",
            "text": "No seas malo con tu hermana.",
            "ipa": "ˈno seˈas ˈmalo kɔn tw eɾˈmana",
            "translation": "别对你妹妹不好。",
            "tokens": [
                T("No seas", None, "", "ˈno seˈas", "不要"),
                T(" malo", "malo", "", "ˈmalo", "坏"),
                T(" con tu hermana.", None, "", "kɔn tw eɾˈmana", "对妹妹。"),
            ],
        },
    ],
    "caliente": [
        {
            "id": "es-ex-caliente-1",
            "text": "La sopa está caliente.",
            "ipa": "la ˈsopa esˈta kaˈljente",
            "translation": "汤很烫。",
            "tokens": [
                T("La sopa", None, "", "la ˈsopa", "汤"),
                T(" está", None, "", "esˈta", "很"),
                T(" caliente.", "caliente", "", "kaˈljente", "烫的。"),
            ],
        },
        {
            "id": "es-ex-caliente-2",
            "text": "Ten cuidado, está caliente.",
            "ipa": "teŋ kuˈiðaðo esˈta kaˈljente",
            "translation": "小心，很烫。",
            "tokens": [
                T("Ten cuidado,", None, "", "teŋ kuˈiðaðo", "小心，"),
                T(" está", None, "", "esˈta", "很"),
                T(" caliente.", "caliente", "", "kaˈljente", "烫。"),
            ],
        },
    ],
    "frío": [
        {
            "id": "es-ex-frio-1",
            "text": "Hace frío en invierno.",
            "ipa": "ˈaθe ˈfɾjo en imˈbjɛɾno",
            "translation": "冬天很冷。",
            "tokens": [
                T("Hace frío", "frío", "", "ˈaθe ˈfɾjo", "很冷"),
                T(" en invierno.", None, "", "en imˈbjɛɾno", "在冬天。"),
            ],
        },
        {
            "id": "es-ex-frio-2",
            "text": "Prefiero el clima frío.",
            "ipa": "pɾeˈfjeɾo el ˈklima ˈfɾjo",
            "translation": "我更喜欢冷天气。",
            "tokens": [
                T("Prefiero", None, "", "pɾeˈfjeɾo", "我更喜欢"),
                T(" el clima", None, "", "el ˈklima", "天气"),
                T(" frío.", "frío", "", "ˈfɾjo", "冷的。"),
            ],
        },
    ],
    "uno": [
        {
            "id": "es-ex-uno-1",
            "text": "Solo quiero uno.",
            "ipa": "ˈsolo ˈkjeɾo ˈuno",
            "translation": "我只要一个。",
            "tokens": [
                T("Solo", None, "", "ˈsolo", "只"),
                T(" quiero", "quiero", "", "ˈkjeɾo", "想要"),
                T(" uno.", "uno", "", "ˈuno", "一个。"),
            ],
        },
        {
            "id": "es-ex-uno-2",
            "text": "Uno más uno son dos.",
            "ipa": "ˈuno mas ˈuno son dos",
            "translation": "一加一等于二。",
            "tokens": [
                T("Uno más uno", "uno", "", "ˈuno mas ˈuno", "一加一"),
                T(" son", None, "", "son", "是"),
                T(" dos.", "dos", "", "dos", "二。"),
            ],
        },
    ],
    "dos": [
        {
            "id": "es-ex-dos-1",
            "text": "Necesito dos huevos.",
            "ipa": "neˈθesito ˈdos ˈweβos",
            "translation": "我需要两个鸡蛋。",
            "tokens": [
                T("Necesito", None, "", "neˈθesito", "我需要"),
                T(" dos", "dos", "", "ˈdos", "两个"),
                T(" huevos.", None, "", "ˈweβos", "鸡蛋。"),
            ],
        },
        {
            "id": "es-ex-dos-2",
            "text": "A las dos salimos.",
            "ipa": "a las ˈdos saˈlimos",
            "translation": "我们两点出发。",
            "tokens": [
                T("A las dos", "dos", "", "a las ˈdos", "在两点"),
                T(" salimos.", None, "", "saˈlimos", "我们走。"),
            ],
        },
    ],
    "tres": [
        {
            "id": "es-ex-tres-1",
            "text": "Cuenta hasta tres.",
            "ipa": "ˈkwenta ˈasta tɾes",
            "translation": "数到三。",
            "tokens": [
                T("Cuenta", None, "", "ˈkwenta", "数"),
                T(" hasta", None, "", "ˈasta", "到"),
                T(" tres.", "tres", "", "tɾes", "三。"),
            ],
        },
        {
            "id": "es-ex-tres-2",
            "text": "Tres coches pasan ahora.",
            "ipa": "tɾes ˈkot͡ʃes ˈpasan aˈoɾa",
            "translation": "现在有三辆车经过。",
            "tokens": [
                T("Tres", "tres", "", "tɾes", "三"),
                T(" coches", None, "", "ˈkot͡ʃes", "辆车"),
                T(" pasan ahora.", None, "", "ˈpasan aˈoɾa", "现在经过。"),
            ],
        },
    ],
    "mamá": [
        {
            "id": "es-ex-mama-1",
            "text": "Mamá abraza al bebé.",
            "ipa": "maˈma aˈβɾaθa al beˈβe",
            "translation": "妈妈抱宝宝。",
            "tokens": [
                T("Mamá", "mamá", "👩", "maˈma", "妈妈"),
                T(" abraza", None, "", "aˈβɾaθa", "抱"),
                T(" al bebé.", None, "", "al beˈβe", "宝宝。"),
            ],
        },
        {
            "id": "es-ex-mama-2",
            "text": "Hablo con mamá por teléfono.",
            "ipa": "ˈablo kɔn maˈma poɾ teˈlefono",
            "translation": "我和妈妈打电话。",
            "tokens": [
                T("Hablo", None, "", "ˈablo", "我说"),
                T(" con mamá", "mamá", "👩", "kɔn maˈma", "和妈妈"),
                T(" por teléfono.", None, "", "poɾ teˈlefono", "通过电话。"),
            ],
        },
    ],
    "papá": [
        {
            "id": "es-ex-papa-1",
            "text": "Papá trabaja mucho.",
            "ipa": "ˈpapa tɾaˈβaxa ˈmut͡ʃo",
            "translation": "爸爸工作很忙。",
            "tokens": [
                T("Papá", "papá", "👨", "ˈpapa", "爸爸"),
                T(" trabaja", None, "", "tɾaˈβaxa", "工作"),
                T(" mucho.", None, "", "ˈmut͡ʃo", "很多。"),
            ],
        },
        {
            "id": "es-ex-papa-2",
            "text": "Papá cocina los domingos.",
            "ipa": "ˈpapa ˈθina los ðoˈmiŋɡos",
            "translation": "爸爸周日做饭。",
            "tokens": [
                T("Papá", "papá", "👨", "ˈpapa", "爸爸"),
                T(" cocina", None, "", "ˈθina", "做饭"),
                T(" los domingos.", None, "", "los ðoˈmiŋɡos", "在周日。"),
            ],
        },
    ],
}

def main():
    (RES / "sentences_es.json").write_text(
        json.dumps({"sentences": SENTENCES}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (RES / "exampleSentences_es.json").write_text(
        json.dumps({"examples_by_lemma": EXAMPLES}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {len(SENTENCES)} Spanish sentences and {len(EXAMPLES)} lemma buckets.")


if __name__ == "__main__":
    main()
