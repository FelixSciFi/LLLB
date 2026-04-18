#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Re-split sentences.json tokens to ~1 word per chunk (numbers, articles, classifiers separate).
Preserves exact sentence text; derives IPA from existing per-token IPA strings.
Rebuilds exampleSentences.json using the same logic as generate_lesson_corpus.
"""

from __future__ import annotations

import copy
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SENTENCES_PATH = ROOT / "LearnLanguageLikeABaby" / "Resources" / "sentences.json"
EXAMPLES_PATH = ROOT / "LearnLanguageLikeABaby" / "Resources" / "exampleSentences.json"

# --- Optional: French stem hints (no spaCy) ---
try:
    sys.path.insert(0, str(ROOT / ".pydeps"))
    import snowballstemmer  # type: ignore

    _stemmer = snowballstemmer.stemmer("french")

    def stem_word(w: str) -> str:
        return _stemmer.stemWord(w.lower())

except Exception:

    def stem_word(w: str) -> str:
        return w.lower()


# Fused IPA in our corpus → per-word IPA when splitting orthographic words
IPA_FUSED: dict[str, list[str]] = {
    "kɔmɑ̃talevu": ["kɔmɑ̃", "ale", "vu"],
    "afɛ̃": ["a", "fɛ̃"],
    "dɔnlyi": ["dɔn", "lɥi"],
    "domineʁal": ["do", "mineʁal"],
    "dəmikilo": ["də", "mikilo"],
    "fɛtmwa": ["fɛt", "mwa"],
    "dɔnemwa": ["dɔne", "mwa"],
    "gaʁdmwa": ["gaʁde", "mwa"],
    "ɛkskyzemwa": ["ɛkskyze", "mwa"],  # Excusez-moi fused in rs12 ipa
}

# Words that stay one orthographic unit (IPA stays single slot)
KEEP_HYPHEN_ONE = {
    "puis-je",
    "a-t-il",
    "a-t-on",
    "a-t-elle",
    "est-ce",
    "week-end",
    "pique-nique",
    "petit-déjeuner",
    "porte-monnaie",
    "après-midi",
    "rendez-vous",
    "quelqu'un",
    "l'autoroute",
    "l'addition",
    "l'heure",
    "l'air",
    "l'été",
    "l'entrée",
    "l'orage",
    "l'éclair",
    "m'indiquer",
    "s'être",
    "d'accord",
    "d'abord",
    "d'ailleurs",
    "d'avoine",
    "d'eau",
    "d'ail",
    "d'oignons",
    "d'identité",
    "d'attente",
    "d'urgence",
    "qu'on",
    "jusqu'à",
    "jusqu'à",
    "aujourd'hui",
    "peut-être",
    "s'il",
    "s'ils",
    "chez",
}

# Split VERB-pronoun / similar (two IPA slots expected)
SPLIT_HYPHEN_VERB = re.compile(
    r"^(.+)-(je|tu|il|elle|on|nous|vous|ils|elles|moi|toi|lui|leur|y|en|la|le|les)$",
    re.I,
)


def _ipa_tokens(ipa: str) -> list[str]:
    s = ipa.strip()
    if not s:
        return []
    return [p for p in re.split(r"\s+", s) if p]


def _ipa_nonword_chars(s: str) -> str:
    """IPA string for punctuation / spaces (mirror surface)."""
    return s.replace("\n", " ")


def _flatten_ipa_parts(parts: list[str]) -> list[str]:
    out: list[str] = []
    for p in parts:
        core = re.sub(r"^[.,;:!?«»\"]+|[.,;:!?«»\".]+$", "", p)
        if core in IPA_FUSED:
            exp = list(IPA_FUSED[core])
            if p.startswith(",") and exp and not exp[0].startswith(","):
                exp[0] = "," + exp[0]
            out.extend(exp)
        else:
            out.append(p)
    return out


def _align_ipa_len(words: list[str], ipa_parts: list[str]) -> list[str]:
    ipa = _flatten_ipa_parts(ipa_parts)
    w = list(words)
    while len(ipa) > len(w) and len(w) >= 1:
        ipa[-2] = ipa[-2] + " " + ipa[-1]
        ipa.pop()
    while len(w) > len(ipa) and len(ipa) >= 1:
        w[-2] = w[-2] + " " + w[-1]
        w.pop()
    if len(w) != len(ipa):
        # last resort: pad or merge
        while len(ipa) < len(w):
            ipa.append(ipa[-1] if ipa else "")
        while len(ipa) > len(w):
            ipa[-2] = ipa[-2] + " " + ipa[-1]
            ipa.pop()
    return ipa


def _token_has_french_letters(tx: str) -> bool:
    return bool(re.search(r"[A-Za-zÀ-ÿàâäéèêëïîôùûüçœæ]", tx))


def _collapse_whitespace_only_tokens(tokens: list[dict]) -> None:
    """Attach whitespace-only chunks to the next word, or to the previous word at end of list."""
    out: list[dict] = []
    pending = ""
    for t in tokens:
        tx = t.get("text") or ""
        if tx and not tx.strip():
            pending += tx
            continue
        nt = dict(t)
        nt["text"] = pending + tx
        pending = ""
        out.append(nt)
    if pending and out:
        last = dict(out[-1])
        last["text"] = last["text"] + pending
        out[-1] = last
    tokens[:] = out


def _assign_sentence_ipa_to_words(new_tokens: list[dict], sentence_ipa: str) -> None:
    """Overwrite IPA on word tokens using sentence-level IPA (per-token IPA is often wrong)."""
    parts = _flatten_ipa_parts(_ipa_tokens(sentence_ipa))
    if not parts:
        return
    word_indices = [i for i, x in enumerate(new_tokens) if _token_has_french_letters(x["text"])]
    if not word_indices:
        return
    surfaces = [new_tokens[i]["text"].strip() for i in word_indices]
    aligned = _align_ipa_len(surfaces, parts)
    for j, idx in enumerate(word_indices):
        ip = aligned[j] if j < len(aligned) else ""
        orig = new_tokens[idx]["text"]
        if orig.endswith(" ") and ip and not ip.endswith(" "):
            ip += " "
        new_tokens[idx]["ipa"] = ip


def fill_empty_token_ipa(obj: dict) -> None:
    for t in obj.get("tokens", []):
        if (t.get("ipa") or "").strip():
            continue
        tx = t.get("text", "")
        t["ipa"] = tx if tx else "."


def _split_hyphen_spans(seg: str, s: int, e: int) -> list[tuple[int, int]]:
    """Non-space span [s,e) inside seg; may split Donnez-moi → Donnez- | vous."""
    w = seg[s:e]
    wl = w.lower()
    if "-" not in w:
        return [(s, e)]
    if "-t-" in wl:
        return [(s, e)]
    if wl in {"est-il", "est-elle", "sont-ils", "sont-elles", "fait-il", "peut-il", "doit-il"}:
        return [(s, e)]
    if wl in KEEP_HYPHEN_ONE or (wl.startswith("l'") and len(wl) > 2):
        return [(s, e)]
    if wl.startswith("demi-"):
        idx = wl.index("-")
        hyp = s + idx
        return [(s, hyp + 1), (hyp + 1, e)]
    m = SPLIT_HYPHEN_VERB.match(w)
    if m:
        if wl in {"puis-je", "a-t-il", "a-t-on", "a-t-elle"}:
            return [(s, e)]
        a = m.group(1)
        hyp = s + len(a)
        return [(s, hyp + 1), (hyp + 1, e)]
    return [(s, e)]


def _build_lemma_glossary(sentences: list[dict]) -> tuple[dict[str, str | None], dict[str, str], dict[str, str]]:
    lemma_by_surface: dict[str, str | None] = {}
    zh_by_surface: dict[str, str] = {}
    emoji_by_lemma: dict[str, str] = {}
    for s in sentences:
        for t in s.get("tokens", []):
            tx = (t.get("text") or "").strip()
            lem = t.get("lemma")
            z = (t.get("translation") or "").strip()
            em = t.get("emoji") or ""
            if lem and em and t.get("hasImage"):
                emoji_by_lemma[lem] = em
            if " " in tx:
                continue
            if tx and tx[0].isalpha():
                lemma_by_surface[tx.lower()] = lem
                if z:
                    zh_by_surface[tx.lower()] = z
    return lemma_by_surface, zh_by_surface, emoji_by_lemma


NUM_ZH = {
    "un": "一",
    "une": "一",
    "deux": "二",
    "trois": "三",
    "quatre": "四",
    "cinq": "五",
    "six": "六",
    "sept": "七",
    "huit": "八",
    "neuf": "九",
    "dix": "十",
    "onze": "十一",
    "douze": "十二",
    "quinze": "十五",
    "vingt": "二十",
    "mille": "千",
    "cent": "百",
    "cents": "百",
}

ART_ZH = {
    "le": "（定冠词）",
    "la": "（定冠词）",
    "les": "（定冠词）",
    "l'": "（定冠词）",
    "du": "（部分冠词）",
    "des": "（复数冠词）",
    "de": "（介词/的）",
    "au": "（介词+冠词）",
    "aux": "（介词+冠词）",
    "un": "（不定冠词）",
    "une": "（不定冠词）",
    "ce": "（指示）",
    "cette": "（指示）",
    "ces": "（指示）",
    "cet": "（指示）",
    "mon": "我的",
    "ma": "我的",
    "mes": "我的",
    "ton": "你的",
    "ta": "你的",
    "tes": "你的",
    "son": "他/她的",
    "sa": "他/她的",
    "ses": "他/她的",
    "notre": "我们的",
    "nos": "我们的",
    "votre": "你们的",
    "vos": "你们的",
    "leur": "他们的",
    "leurs": "他们的",
}


def _zh_for_word(w: str, glossary_zh: dict[str, str]) -> str:
    wl = w.lower()
    if wl in NUM_ZH:
        return NUM_ZH[wl]
    if wl in ART_ZH:
        return ART_ZH[wl]
    if wl in glossary_zh:
        return glossary_zh[wl]
    if "'" in w:
        if wl.startswith("d'") and wl[2:] in glossary_zh:
            return glossary_zh[wl[2:]]
        if wl.startswith("l'") and wl[2:] in glossary_zh:
            return glossary_zh[wl[2:]]
    return ""


LEMMA_MANUAL: dict[str, str | None] = {
    "voudrais": "vouloir",
    "voudriez": "vouloir",
    "veux": "vouloir",
    "veut": "vouloir",
    "voulons": "vouloir",
    "veulent": "vouloir",
    "prends": "prendre",
    "prenez": "prendre",
    "prend": "prendre",
    "prenons": "prendre",
    "prennent": "prendre",
    "mangues": "pomme",
    "pommes": "pomme",
    "donne": "donner",
    "donnez": "donner",
    "donnent": "donner",
    "garde": "garder",
    "gardez": "garder",
    "faites": "faire",
    "fais": "faire",
    "fait": "faire",
    "font": "faire",
    "allez": "aller",
    "vas": "aller",
    "va": "aller",
    "vont": "aller",
    "êtes": "être",
    "es": "être",
    "est": "être",
    "sommes": "être",
    "sont": "être",
    "suis": "être",
    "avez": "avoir",
    "ai": "avoir",
    "as": "avoir",
    "a": "avoir",
    "avons": "avoir",
    "ont": "avoir",
    "peux": "pouvoir",
    "peut": "pouvoir",
    "peuvent": "pouvoir",
    "pouvez": "pouvoir",
    "pourriez": "pouvoir",
    "dois": "devoir",
    "doit": "devoir",
    "devez": "devoir",
    "devons": "devoir",
    "mets": "mettre",
    "mettez": "mettre",
    "met": "mettre",
    "montez": "monter",
    "monte": "monter",
    "passez": "passer",
    "passe": "passer",
    "cherche": "chercher",
    "cherchez": "chercher",
    "trouve": "trouver",
    "trouvez": "trouver",
    "trouvent": "trouver",
    "regarde": "regarder",
    "regardes": "regarder",
    "regardent": "regarder",
    "achète": "acheter",
    "achètes": "acheter",
    "achètent": "acheter",
    "achèterez": "acheter",
    "payez": "payer",
    "paye": "payer",
    "ferme": "fermer",
    "fermez": "fermer",
    "ferment": "fermer",
    "ouvre": "ouvrir",
    "ouvrez": "ouvrir",
    "ouvrent": "ouvrir",
    "oublie": "oublier",
    "oublies": "oublier",
    "oublient": "oublier",
    "tousse": "tousser",
    "tousses": "tousser",
    "toussent": "tousser",
    "appelle": "appeler",
    "appelles": "appeler",
    "appellent": "appeler",
    "appelez": "appeler",
    "présente": "présenter",
    "présentes": "présenter",
    "présentent": "présenter",
    "présentez": "présenter",
    "recommande": "recommander",
    "recommandez": "recommander",
    "recommandent": "recommander",
    "recommence": "recommencer",
    "recommences": "recommencer",
    "recommencent": "recommencer",
    "recommencez": "recommencer",
    "recommencer": "recommencer",
    "reviens": "revenir",
    "reviennent": "revenir",
    "revenez": "revenir",
    "accroche": "accrocher",
    "accroches": "accrocher",
    "accrochent": "accrocher",
    "accrochez": "accrocher",
    "annule": "annuler",
    "annules": "annuler",
    "annulent": "annuler",
    "annulez": "annuler",
    "espère": "espérer",
    "espèrent": "espérer",
    "espérez": "espérer",
    "hydrate": "hydrater",
    "hydrates": "hydrater",
    "hydratent": "hydrater",
    "synchronise": "synchroniser",
    "synchronises": "synchroniser",
    "synchronisent": "synchroniser",
    "synchronisez": "synchroniser",
    "mûres": "mûr",
    "mangé": "manger",
    "mangent": "manger",
    "mange": "manger",
    "manges": "manger",
    "mangez": "manger",
    "commandé": "commander",
    "commande": "commander",
    "commandes": "commander",
    "commandent": "commander",
    "commandez": "commander",
    "indiquer": "indiquer",
    "indiques": "indiquer",
    "indiquent": "indiquer",
    "indiquez": "indiquer",
    "valider": "valider",
    "valides": "valider",
    "valident": "valider",
    "validez": "valider",
    "récupérer": "récupérer",
    "récupères": "récupérer",
    "récupèrent": "récupérer",
    "récupérez": "récupérer",
    "répondez": "répondre",
    "réponds": "répondre",
    "répond": "répondre",
    "répondent": "répondre",
    "répète": "répéter",
    "répètes": "répéter",
    "répètent": "répéter",
    "répétez": "répéter",
    "répéter": "répéter",
    "note": "noter",
    "notes": "noter",
    "notent": "noter",
    "notez": "noter",
    "entends": "entendre",
    "entend": "entendre",
    "entendent": "entendre",
    "entendez": "entendre",
    "écris": "écrire",
    "écrit": "écrire",
    "écrivent": "écrire",
    "écrivez": "écrire",
    "dit": "dire",
    "dis": "dire",
    "disent": "dire",
    "dites": "dire",
    "dîtes": "dire",
    "sers": "servir",
    "sert": "servir",
    "servent": "servir",
    "servez": "servir",
    "travailles": "travailler",
    "travaille": "travailler",
    "travaillent": "travailler",
    "travaillez": "travailler",
    "range": "ranger",
    "ranges": "ranger",
    "rangent": "ranger",
    "rangez": "ranger",
    "repose": "reposer",
    "reposes": "reposer",
    "reposent": "reposer",
    "reposez": "reposer",
    "repose-toi": None,
    "manquent": "manquer",
    "manque": "manquer",
    "manques": "manquer",
    "manquez": "manquer",
    "excusez": "excuser",
    "excuses": "excuser",
    "excusent": "excuser",
    "excuse": "excuser",
}


def _lemma_for_surface(w: str, glossary: dict[str, str | None]) -> str | None:
    wl = w.lower().strip(".,;:!?")
    if wl in LEMMA_MANUAL:
        return LEMMA_MANUAL[wl]
    if wl in glossary and glossary[wl] is not None:
        return glossary[wl]
    if "'" in w:
        base = w.split("'")[-1].lower()
        if base in glossary and glossary[base] is not None:
            return glossary[base]
    return stem_word(w)


def _polite_match_from(seg: str, i: int) -> re.Match[str] | None:
    return re.match(r"s'il\s+(vous|te)\s+plaît", seg[i:], re.I)


def _merge_whitespace_prefix_into_following_word(
    pieces: list[tuple[str, int, int]], seg: str
) -> list[tuple[str, int, int]]:
    """Avoid a token that is only spaces (e.g. legacy ` aujourd'hui` → ` aujourd'hui` one word chunk)."""
    out: list[tuple[str, int, int]] = []
    i = 0
    while i < len(pieces):
        typ, s, e = pieces[i]
        if (
            typ == "p"
            and i + 1 < len(pieces)
            and pieces[i + 1][0] == "w"
            and seg[s:e].strip() == ""
            and seg[s:e]
        ):
            _, ws, we = pieces[i + 1]
            out.append(("w", s, we))
            i += 2
            continue
        out.append(pieces[i])
        i += 1
    return out


def subdivide_legacy_token(
    seg: str,
    _ipa: str,
    t: dict,
    glossary: dict[str, str | None],
    glossary_zh: dict[str, str],
    emoji_by_lemma: dict[str, str],
) -> list[dict]:
    if not seg:
        return []
    if not re.search(r"[A-Za-zÀ-ÿàâäéèêëïîôùûüçœæ]", seg):
        return [
            {
                "text": seg,
                "lemma": None,
                "hasImage": False,
                "emoji": "",
                "ipa": _ipa_nonword_chars(seg) if not (_ipa or "").strip() else (_ipa or seg),
                "translation": "",
            }
        ]

    m_polite = re.search(r"s'\s*il\s+(vous|te)\s+plaît", seg, re.I)
    if m_polite:
        out_pol: list[dict] = []
        t_edge = {**t, "translation": "", "lemma": None}
        if m_polite.start() > 0:
            out_pol.extend(
                subdivide_legacy_token(
                    seg[: m_polite.start()],
                    "",
                    t_edge,
                    glossary,
                    glossary_zh,
                    emoji_by_lemma,
                )
            )
        polite_span = seg[m_polite.start() : m_polite.end()]
        out_pol.append(
            {
                "text": polite_span,
                "lemma": None,
                "hasImage": False,
                "emoji": "",
                "ipa": "",
                "translation": t.get("translation") or "请",
            }
        )
        if m_polite.end() < len(seg):
            out_pol.extend(
                subdivide_legacy_token(
                    seg[m_polite.end() :],
                    "",
                    t_edge,
                    glossary,
                    glossary_zh,
                    emoji_by_lemma,
                )
            )
        return out_pol

    pieces: list[tuple[str, int, int]] = []
    i, n = 0, len(seg)
    while i < n:
        if seg[i].isspace():
            j = i + 1
            while j < n and seg[j].isspace():
                j += 1
            pieces.append(("p", i, j))
            i = j
            continue
        if seg[i] in ",.;:!?":
            j = i + 1
            while j < n and seg[j].isspace():
                j += 1
            pieces.append(("p", i, j))
            i = j
            continue
        polite = _polite_match_from(seg, i)
        if polite:
            end = i + polite.end()
            k = end
            while k < n and seg[k].isspace():
                k += 1
            pieces.append(("w", i, k))
            i = k
            continue
        j = i
        while j < n and (seg[j].isalpha() or seg[j] in "'’"):
            j += 1
        while j < n and seg[j] == "-":
            j += 1
            while j < n and seg[j].isalpha():
                j += 1
        e0 = j
        k = j
        while k < n and seg[k].isspace():
            k += 1
        subs = _split_hyphen_spans(seg, i, e0)
        tail = seg[e0:k]
        if len(subs) == 1:
            pieces.append(("w", subs[0][0], subs[0][1] + len(tail)))
        else:
            for si, (a, b) in enumerate(subs):
                if si == len(subs) - 1:
                    pieces.append(("w", a, b + len(tail)))
                else:
                    pieces.append(("w", a, b))
        i = k

    pieces = _merge_whitespace_prefix_into_following_word(pieces, seg)
    wpieces = [p for p in pieces if p[0] == "w"]

    out: list[dict] = []
    for typ, s, e in pieces:
        tx = seg[s:e]
        if typ == "p":
            out.append(
                {
                    "text": tx,
                    "lemma": None,
                    "hasImage": False,
                    "emoji": "",
                    "ipa": _ipa_nonword_chars(tx),
                    "translation": "",
                }
            )
            continue
        wstrip = tx.strip()
        ip = ""
        lem = _lemma_for_surface(wstrip, glossary)
        zh = _zh_for_word(wstrip, glossary_zh)
        if not zh and len(wpieces) == 1:
            zh = t.get("translation") or ""
        em = emoji_by_lemma.get(lem or "", "") if lem else ""
        if not em and t.get("hasImage") and wstrip.lower() in (t.get("text") or "").lower():
            em = t.get("emoji") or ""
        out.append(
            {
                "text": tx,
                "lemma": lem,
                "hasImage": bool(em),
                "emoji": em or "",
                "ipa": ip,
                "translation": zh,
            }
        )

    return out


def refine_sentence(s: dict, glossary, glossary_zh, emoji_by_lemma) -> dict:
    full_text = s["text"]
    new_tokens: list[dict] = []
    cursor = 0
    for t in s["tokens"]:
        seg = t["text"]
        ipa = t.get("ipa") or ""
        idx = full_text.find(seg, cursor)
        if idx < 0:
            idx = full_text.find(seg)
        if idx < 0:
            raise ValueError(f"token fragment not found {seg!r} in {full_text}")
        if idx != cursor:
            raise ValueError(f"gap in tokens {s['id']} cursor={cursor} idx={idx} seg={seg!r}")
        cursor = idx + len(seg)
        new_tokens.extend(subdivide_legacy_token(seg, ipa, t, glossary, glossary_zh, emoji_by_lemma))

    _collapse_whitespace_only_tokens(new_tokens)
    _assign_sentence_ipa_to_words(new_tokens, s.get("ipa") or "")

    assert "".join(x["text"] for x in new_tokens) == full_text, s["id"]
    return {**s, "tokens": new_tokens}


def build_examples_by_lemma(sentences: list[dict]) -> dict[str, list[dict]]:
    lemmas: set[str] = set()
    for s in sentences:
        for t in s["tokens"]:
            if t.get("lemma"):
                lemmas.add(t["lemma"])

    def ipa_hint_for_lemma(lem: str) -> str:
        for s in sentences:
            for t in s["tokens"]:
                if t.get("lemma") != lem:
                    continue
                ip = (t.get("ipa") or "").strip()
                if not ip:
                    continue
                if (t.get("text") or "").strip().lower() == lem.lower():
                    return ip
        for s in sentences:
            for t in s["tokens"]:
                if t.get("lemma") == lem:
                    ip = (t.get("ipa") or "").strip()
                    if ip:
                        return ip
        return lem

    def synth_raw_row(lem: str, variant: int, ip: str) -> tuple:
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
                f"sɛ e kʁi : « {i} ».",
                f"写着：「{l}」。",
                [
                    ("C'est écrit : « ", "écrire", False, "", "sɛ e kʁi : « ", "写着"),
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

    def T(text, lemma=None, has_image=False, emoji="", ipa="", zh=""):
        return {
            "text": text,
            "lemma": lemma,
            "hasImage": bool(has_image),
            "emoji": emoji or "",
            "ipa": ipa if ipa else "",
            "translation": zh if zh else "",
        }

    def S(sid, text, ipa, zh, parts):
        tokens = [T(*p) if isinstance(p, tuple) and len(p) == 6 else T(**p) for p in parts]
        assert "".join(t["text"] for t in tokens) == text, (sid, "".join(t["text"] for t in tokens), text)
        return {"id": str(sid), "text": text, "ipa": ipa, "translation": zh, "tokens": tokens}

    examples_by_lemma: dict[str, list] = {lem: [] for lem in lemmas}
    ex_counters: defaultdict[str, int] = defaultdict(int)

    def clone_with_id(s: dict, new_id: str) -> dict:
        c = copy.deepcopy(s)
        c["id"] = new_id
        return c

    for lem in sorted(lemmas):
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

    return examples_by_lemma


def main() -> None:
    data = json.loads(SENTENCES_PATH.read_text(encoding="utf-8"))
    sentences = data["sentences"]
    gl, gzh, em = _build_lemma_glossary(sentences)
    new_sentences = [refine_sentence(s, gl, gzh, em) for s in sentences]
    for s in new_sentences:
        assert "".join(t["text"] for t in s["tokens"]) == s["text"], s["id"]
        fill_empty_token_ipa(s)

    examples = build_examples_by_lemma(new_sentences)
    SENTENCES_PATH.write_text(json.dumps({"sentences": new_sentences}, ensure_ascii=False, indent=2), encoding="utf-8")
    EXAMPLES_PATH.write_text(json.dumps({"examples_by_lemma": examples}, ensure_ascii=False, indent=2), encoding="utf-8")
    print("sentences:", len(new_sentences), "lemma keys:", len(examples))


if __name__ == "__main__":
    main()
