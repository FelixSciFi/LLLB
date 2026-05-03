import json

out = [
    # 1. "Heure" — single bare noun, ambiguous (heure = hour/time), no learning context
    {
        "id": "000f8027-e681-4858-a579-fdf180e4c810",
        "verdict": "delete",
        "delete_reason": "Bare isolated noun with no context; ambiguous (hour vs time), no pedagogical value as standalone.",
        "ipa": "œʁ",
        "translation": {"zh": "小时", "en": "hour"},
        "tokens": [
            {"text": "Heure", "lemma": "heure", "ipa": "œʁ", "emoji": "⏰", "translation": {"zh": "小时", "en": "hour"}}
        ]
    },
    # 2. "J'ai de nouveaux amis." — natural, useful A1
    {
        "id": "00180679-2d8e-4198-be56-92d6f5906623",
        "verdict": "keep",
        "ipa": "ʒe də nuvo zami",
        "translation": {"zh": "我有一些新朋友。", "en": "I have new friends."},
        "tokens": [
            {"text": "J'ai", "lemma": "avoir", "ipa": "ʒe", "emoji": "", "emoji_reason": "auxiliary/possession verb, abstract", "translation": {"zh": "我有", "en": "I have"}},
            {"text": "de nouveaux", "lemma": "nouveau", "ipa": "də nuvo", "emoji": "✨", "translation": {"zh": "新的", "en": "new"}},
            {"text": "amis", "lemma": "ami", "ipa": "ami", "emoji": "👬", "translation": {"zh": "朋友们", "en": "friends"}}
        ]
    },
    # 3. "Déconnexion" — UI label, technical, low pedagogical value as standalone
    {
        "id": "001aa7f9-5053-40a7-add6-93d1c6797158",
        "verdict": "delete",
        "delete_reason": "Bare UI/technical label with no context; not useful for spoken French learning at A2.",
        "ipa": "dekɔnɛksjɔ̃",
        "translation": {"zh": "登出/断开连接", "en": "logout/disconnection"},
        "tokens": [
            {"text": "Déconnexion", "lemma": "déconnexion", "ipa": "dekɔnɛksjɔ̃", "emoji": "🔌", "translation": {"zh": "登出", "en": "logout"}}
        ]
    },
    # 4. "Penser" — bare infinitive, ambiguous (think? think about?), no context
    {
        "id": "0021d6f4-77a0-45f8-96e8-88faf34ac324",
        "verdict": "delete",
        "delete_reason": "Bare infinitive with no context; abstract verb taught best in a sentence.",
        "ipa": "pɑ̃se",
        "translation": {"zh": "想，思考", "en": "to think"},
        "tokens": [
            {"text": "Penser", "lemma": "penser", "ipa": "pɑ̃se", "emoji": "🤔", "translation": {"zh": "思考", "en": "to think"}}
        ]
    },
    # 5. "des écouteurs Bluetooth" — useful concrete phrase
    {
        "id": "003fe377-b528-41c6-b0cb-079e23f0b5a7",
        "verdict": "keep",
        "ipa": "de zekutœʁ blutus",
        "translation": {"zh": "蓝牙耳机", "en": "Bluetooth earphones"},
        "tokens": [
            {"text": "des écouteurs", "lemma": "écouteur", "ipa": "de zekutœʁ", "emoji": "🎧", "translation": {"zh": "耳机", "en": "earphones"}},
            {"text": "Bluetooth", "lemma": "Bluetooth", "ipa": "blutus", "emoji": "📶", "translation": {"zh": "蓝牙", "en": "Bluetooth"}}
        ]
    },
    # 6. "dix-sept" — number, useful
    {
        "id": "0083c583-64a7-4960-860d-37270dc00c7c",
        "verdict": "keep",
        "ipa": "dis(s)ɛt",
        "translation": {"zh": "十七", "en": "seventeen"},
        "tokens": [
            {"text": "dix-sept", "lemma": "dix-sept", "ipa": "dissɛt", "emoji": "1️⃣7️⃣", "translation": {"zh": "十七", "en": "seventeen"}}
        ]
    },
    # 7. "Le soleil, la lune et les étoiles sont dans le ciel."
    {
        "id": "00d67769-aec8-422c-a950-58ca69c46024",
        "verdict": "keep",
        "ipa": "lə sɔlɛj la lyn e le zetwal sɔ̃ dɑ̃ lə sjɛl",
        "translation": {"zh": "太阳、月亮和星星在天空中。", "en": "The sun, the moon and the stars are in the sky."},
        "tokens": [
            {"text": "Le soleil", "lemma": "soleil", "ipa": "lə sɔlɛj", "emoji": "☀️", "translation": {"zh": "太阳", "en": "the sun"}},
            {"text": "la lune", "lemma": "lune", "ipa": "la lyn", "emoji": "🌙", "translation": {"zh": "月亮", "en": "the moon"}},
            {"text": "et", "lemma": None, "ipa": "e", "emoji": "", "emoji_reason": "conjunction", "translation": {"zh": "和", "en": "and"}},
            {"text": "les étoiles", "lemma": "étoile", "ipa": "le zetwal", "emoji": "⭐", "translation": {"zh": "星星", "en": "the stars"}},
            {"text": "sont", "lemma": "être", "ipa": "sɔ̃", "emoji": "", "emoji_reason": "copula", "translation": {"zh": "是/在", "en": "are"}},
            {"text": "dans le ciel", "lemma": "ciel", "ipa": "dɑ̃ lə sjɛl", "emoji": "🌌", "translation": {"zh": "在天空中", "en": "in the sky"}}
        ]
    },
    # 8. "un camion de pompiers" — concrete useful noun phrase
    {
        "id": "010354f4-d25a-469a-a3d7-1faee5194632",
        "verdict": "keep",
        "ipa": "œ̃ kamjɔ̃ də pɔ̃pje",
        "translation": {"zh": "一辆消防车", "en": "a fire truck"},
        "tokens": [
            {"text": "un camion", "lemma": "camion", "ipa": "œ̃ kamjɔ̃", "emoji": "🚚", "translation": {"zh": "卡车", "en": "a truck"}},
            {"text": "de pompiers", "lemma": "pompier", "ipa": "də pɔ̃pje", "emoji": "🧑‍🚒", "translation": {"zh": "消防员的", "en": "of firefighters"}}
        ]
    },
    # 9. "Lever" — bare infinitive, ambiguous (lift vs get up reflexive)
    {
        "id": "01539f13-6e1d-4470-b91c-b58e7ed77f4e",
        "verdict": "delete",
        "delete_reason": "Bare infinitive 'Lever' is ambiguous (to lift / to raise / se lever to get up); no useful context.",
        "ipa": "ləve",
        "translation": {"zh": "举起；起床", "en": "to lift / to get up"},
        "tokens": [
            {"text": "Lever", "lemma": "lever", "ipa": "ləve", "emoji": "⬆️", "translation": {"zh": "举起", "en": "to lift"}}
        ]
    },
    # 10. "La grande fille" — fragment, but A1 useful descriptor phrase
    {
        "id": "01957728-dc45-4b78-aa2a-ce1f7ac939a1",
        "verdict": "keep",
        "ipa": "la ɡʁɑ̃d fij",
        "translation": {"zh": "高大的女孩", "en": "the tall girl"},
        "tokens": [
            {"text": "La grande", "lemma": "grand", "ipa": "la ɡʁɑ̃d", "emoji": "📏", "translation": {"zh": "高大的", "en": "the tall"}},
            {"text": "fille", "lemma": "fille", "ipa": "fij", "emoji": "👧", "translation": {"zh": "女孩", "en": "girl"}}
        ],
        "notes": "Descriptor fragment; could pair with another sentence."
    },
    # 11. "aller en cours" — common useful phrase (go to class)
    {
        "id": "01abc6a9-a2f6-4217-9271-6147b352ce31",
        "verdict": "keep",
        "ipa": "ale ɑ̃ kuʁ",
        "translation": {"zh": "去上课", "en": "to go to class"},
        "tokens": [
            {"text": "aller", "lemma": "aller", "ipa": "ale", "emoji": "🚶", "translation": {"zh": "去", "en": "to go"}},
            {"text": "en cours", "lemma": "cours", "ipa": "ɑ̃ kuʁ", "emoji": "🏫", "translation": {"zh": "上课", "en": "to class"}}
        ]
    },
    # 12. "Haut" — bare adjective, ambiguous and unhelpful alone
    {
        "id": "01efeffc-bff9-4b08-aabb-4c016c7da912",
        "verdict": "delete",
        "delete_reason": "Bare adjective with no context; not useful as standalone learning unit.",
        "ipa": "o",
        "translation": {"zh": "高的", "en": "high/tall"},
        "tokens": [
            {"text": "Haut", "lemma": "haut", "ipa": "o", "emoji": "⬆️", "translation": {"zh": "高的", "en": "high"}}
        ]
    },
    # 13. "S'il te plaît, papa." — natural spoken
    {
        "id": "02005301-7aa6-496b-9135-22391fa25948",
        "verdict": "keep",
        "ipa": "sil tə plɛ papa",
        "translation": {"zh": "求你了，爸爸。", "en": "Please, daddy."},
        "tokens": [
            {"text": "S'il te plaît", "lemma": "s'il te plaît", "ipa": "sil tə plɛ", "emoji": "🙏", "translation": {"zh": "请", "en": "please"}},
            {"text": "papa", "lemma": "papa", "ipa": "papa", "emoji": "👨", "translation": {"zh": "爸爸", "en": "daddy"}}
        ]
    },
    # 14. "Bonjour, madame." — useful greeting
    {
        "id": "020349d1-ec0a-46da-9979-0875b641ea11",
        "verdict": "keep",
        "ipa": "bɔ̃ʒuʁ madam",
        "translation": {"zh": "您好，女士。", "en": "Hello, ma'am."},
        "tokens": [
            {"text": "Bonjour", "lemma": "bonjour", "ipa": "bɔ̃ʒuʁ", "emoji": "👋", "translation": {"zh": "你好", "en": "hello"}},
            {"text": "madame", "lemma": "madame", "ipa": "madam", "emoji": "👩", "translation": {"zh": "女士", "en": "ma'am"}}
        ]
    },
    # 15. "Marcher" — bare infinitive
    {
        "id": "022f8e1f-d307-4661-8cbf-918e1a0a1cf9",
        "verdict": "delete",
        "delete_reason": "Bare infinitive with no context; better taught in a sentence.",
        "ipa": "maʁʃe",
        "translation": {"zh": "走路", "en": "to walk"},
        "tokens": [
            {"text": "Marcher", "lemma": "marcher", "ipa": "maʁʃe", "emoji": "🚶", "translation": {"zh": "走路", "en": "to walk"}}
        ]
    },
    # 16. "Merci" — single word but extremely common standalone expression — keep
    {
        "id": "02458356-a00e-4b39-bd69-dcb72ea3ae82",
        "verdict": "keep",
        "ipa": "mɛʁsi",
        "translation": {"zh": "谢谢", "en": "thank you"},
        "tokens": [
            {"text": "Merci", "lemma": "merci", "ipa": "mɛʁsi", "emoji": "🙏", "translation": {"zh": "谢谢", "en": "thank you"}}
        ],
        "notes": "Single word but functions as a complete utterance."
    },
    # 17. "Erreur" — bare noun, low context value
    {
        "id": "02733f68-c9e2-4e37-89ff-c8bf573b6497",
        "verdict": "delete",
        "delete_reason": "Bare noun out of context; pedagogically weak.",
        "ipa": "eʁœʁ",
        "translation": {"zh": "错误", "en": "error"},
        "tokens": [
            {"text": "Erreur", "lemma": "erreur", "ipa": "eʁœʁ", "emoji": "❌", "translation": {"zh": "错误", "en": "error"}}
        ]
    },
    # 18. "C'est génial !" — useful expression
    {
        "id": "0279be76-28e6-49b8-9f4d-74c73031edb5",
        "verdict": "keep",
        "ipa": "sɛ ʒenjal",
        "translation": {"zh": "太棒了！", "en": "That's awesome!"},
        "tokens": [
            {"text": "C'est", "lemma": "être", "ipa": "sɛ", "emoji": "", "emoji_reason": "copula", "translation": {"zh": "这是", "en": "it is"}},
            {"text": "génial", "lemma": "génial", "ipa": "ʒenjal", "emoji": "🤩", "translation": {"zh": "太棒的", "en": "awesome"}}
        ]
    },
    # 19. "Lâche-moi !" — natural spoken imperative
    {
        "id": "02a036ff-11fb-4f82-ad7d-a51fd6e8b4fa",
        "verdict": "keep",
        "ipa": "lɑʃ mwa",
        "translation": {"zh": "放开我！", "en": "Let go of me!"},
        "tokens": [
            {"text": "Lâche-moi", "lemma": "lâcher", "ipa": "lɑʃ mwa", "emoji": "✋", "translation": {"zh": "放开我", "en": "let go of me"}}
        ]
    },
    # 20. "Contrat" — bare noun
    {
        "id": "02a21005-19c6-4c08-821d-4f7665b44f28",
        "verdict": "delete",
        "delete_reason": "Bare noun with no context; abstract concept, low value as standalone.",
        "ipa": "kɔ̃tʁa",
        "translation": {"zh": "合同", "en": "contract"},
        "tokens": [
            {"text": "Contrat", "lemma": "contrat", "ipa": "kɔ̃tʁa", "emoji": "📄", "translation": {"zh": "合同", "en": "contract"}}
        ]
    },
    # 21. "de rien" — useful set phrase (you're welcome)
    {
        "id": "02d16b61-4f3e-4299-ab2d-bfc1bf9777a1",
        "verdict": "keep",
        "ipa": "də ʁjɛ̃",
        "translation": {"zh": "不客气", "en": "you're welcome"},
        "tokens": [
            {"text": "de rien", "lemma": "de rien", "ipa": "də ʁjɛ̃", "emoji": "🙂", "translation": {"zh": "不客气", "en": "you're welcome"}}
        ]
    },
    # 22. "Restaurant" — bare noun, but easily recognized cognate
    {
        "id": "02d3a1a0-d792-4e70-824d-b62779f9cd51",
        "verdict": "delete",
        "delete_reason": "Bare noun without article or context; better taught as 'un restaurant' or in a sentence.",
        "ipa": "ʁɛstɔʁɑ̃",
        "translation": {"zh": "餐厅", "en": "restaurant"},
        "tokens": [
            {"text": "Restaurant", "lemma": "restaurant", "ipa": "ʁɛstɔʁɑ̃", "emoji": "🍽️", "translation": {"zh": "餐厅", "en": "restaurant"}}
        ]
    },
    # 23. "Jura, mais un peu tard, qu'on ne l'y prendrait plus." — odd literary fragment
    {
        "id": "02ec04f9-b705-4796-9c79-d69d57e0711a",
        "verdict": "delete",
        "delete_reason": "Literary fragment ripped out of context (likely from La Fontaine); ungrammatical-feeling standalone, not real spoken French.",
        "ipa": "ʒyʁa mɛ œ̃ pø taʁ kɔ̃ nə li pʁɑ̃dʁɛ ply",
        "translation": {"zh": "他发誓——但有点晚了——再也不会让人在那里抓到他。", "en": "He swore, but a bit late, that they wouldn't catch him there again."},
        "tokens": [
            {"text": "Jura", "lemma": "jurer", "ipa": "ʒyʁa", "emoji": "🤞", "translation": {"zh": "发誓", "en": "swore"}},
            {"text": "mais", "lemma": None, "ipa": "mɛ", "emoji": "", "emoji_reason": "conjunction", "translation": {"zh": "但是", "en": "but"}},
            {"text": "un peu tard", "lemma": "tard", "ipa": "œ̃ pø taʁ", "emoji": "🕰️", "translation": {"zh": "有点晚", "en": "a bit late"}},
            {"text": "qu'on ne l'y prendrait plus", "lemma": "prendre", "ipa": "kɔ̃ nə li pʁɑ̃dʁɛ ply", "emoji": "", "emoji_reason": "complex clause, abstract", "translation": {"zh": "再也抓不到他", "en": "they wouldn't catch him there again"}}
        ]
    },
    # 24. "un embouteillage" — useful concrete noun phrase
    {
        "id": "0304f359-3f82-494c-9bfa-80c2f4af54b3",
        "verdict": "keep",
        "ipa": "œ̃ nɑ̃butɛjaʒ",
        "translation": {"zh": "一场堵车", "en": "a traffic jam"},
        "tokens": [
            {"text": "un embouteillage", "lemma": "embouteillage", "ipa": "œ̃ nɑ̃butɛjaʒ", "emoji": "🚗", "translation": {"zh": "堵车", "en": "traffic jam"}}
        ]
    },
    # 25. "Emploi" — bare noun
    {
        "id": "03421c0a-d2db-43c8-933c-2e28621122a6",
        "verdict": "delete",
        "delete_reason": "Bare abstract noun with no context.",
        "ipa": "ɑ̃plwa",
        "translation": {"zh": "工作", "en": "job/employment"},
        "tokens": [
            {"text": "Emploi", "lemma": "emploi", "ipa": "ɑ̃plwa", "emoji": "💼", "translation": {"zh": "工作", "en": "job"}}
        ]
    },
    # 26. "Salut" — single common greeting — keep
    {
        "id": "036226a9-e931-419e-9e6f-17795b68ef8b",
        "verdict": "keep",
        "ipa": "saly",
        "translation": {"zh": "你好/再见", "en": "hi/bye"},
        "tokens": [
            {"text": "Salut", "lemma": "salut", "ipa": "saly", "emoji": "👋", "translation": {"zh": "你好", "en": "hi"}}
        ],
        "notes": "Single word but a complete casual greeting."
    },
    # 27. "Désolé, j'ai oublié." — natural useful
    {
        "id": "03a4ee29-fd54-400f-8cf9-943502bc1399",
        "verdict": "keep",
        "ipa": "dezɔle ʒe ublije",
        "translation": {"zh": "对不起，我忘了。", "en": "Sorry, I forgot."},
        "tokens": [
            {"text": "Désolé", "lemma": "désolé", "ipa": "dezɔle", "emoji": "😔", "translation": {"zh": "抱歉", "en": "sorry"}},
            {"text": "j'ai oublié", "lemma": "oublier", "ipa": "ʒe ublije", "emoji": "🤦", "translation": {"zh": "我忘了", "en": "I forgot"}}
        ]
    },
    # 28. "Je prends le bus." — natural useful A1
    {
        "id": "03ad24eb-06a8-4791-a407-8faba2187a18",
        "verdict": "keep",
        "ipa": "ʒə pʁɑ̃ lə bys",
        "translation": {"zh": "我坐公交车。", "en": "I take the bus."},
        "tokens": [
            {"text": "Je prends", "lemma": "prendre", "ipa": "ʒə pʁɑ̃", "emoji": "✋", "translation": {"zh": "我乘坐", "en": "I take"}},
            {"text": "le bus", "lemma": "bus", "ipa": "lə bys", "emoji": "🚌", "translation": {"zh": "公交车", "en": "the bus"}}
        ]
    },
    # 29. "Projet" — bare noun
    {
        "id": "03b21ef9-a7ba-446a-83a2-a3e6da795e11",
        "verdict": "delete",
        "delete_reason": "Bare abstract noun with no context.",
        "ipa": "pʁɔʒɛ",
        "translation": {"zh": "项目，计划", "en": "project"},
        "tokens": [
            {"text": "Projet", "lemma": "projet", "ipa": "pʁɔʒɛ", "emoji": "📋", "translation": {"zh": "项目", "en": "project"}}
        ]
    },
    # 30. "Pluie" — bare noun, weather word — borderline. Single weather noun, very common, easy to remember with image but no article. Delete for consistency.
    {
        "id": "03b8391f-4cbd-4eb7-87bb-51ed7f04d48d",
        "verdict": "delete",
        "delete_reason": "Bare noun without article or context; weather words better taught as 'Il pleut' or 'la pluie'.",
        "ipa": "plɥi",
        "translation": {"zh": "雨", "en": "rain"},
        "tokens": [
            {"text": "Pluie", "lemma": "pluie", "ipa": "plɥi", "emoji": "🌧️", "translation": {"zh": "雨", "en": "rain"}}
        ]
    }
]

with open("/Users/xieyu/projects/LLLB/tools/batch_output.json", "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=2)

print(f"Total: {len(out)}")
print(f"Keep:   {sum(1 for x in out if x['verdict']=='keep')}")
print(f"Delete: {sum(1 for x in out if x['verdict']=='delete')}")
