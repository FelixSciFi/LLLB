#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Conservative token merge for sentences.json (local only, ~instant).

- Merge only: article + one following noun (each side exactly one French word).
- Merge only: je/tu/il/elle/nous/vous/ils + one following verb (each side one word).
- No preposition-phrase merging.
- Punctuation is never merged into word tokens: split into separate tokens (translation "").
- Merged chunk: at most 3 French words.
- Fixes known translation errors (frais, addition, Passe in greetings).

Tokens must concatenate to sentence text exactly (Swift NarrationEngine).
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SENTENCES_PATH = ROOT / "LearnLanguageLikeABaby" / "Resources" / "sentences_fr.json"

# One French “word” (allows l’addition, s’il, demi-kilo)
WORD_RE = re.compile(
    r"[A-Za-zÀ-ÿàâäéèêëïîôùûüçœæ]+(?:['’][A-Za-zÀ-ÿàâäéèêëïîôùûüçœæ]+)*",
    re.UNICODE,
)

ARTICLE_LEMMAS = {
    "le",
    "la",
    "les",
    "un",
    "une",
    "du",
    "des",
    "ce",
    "cet",
    "cette",
    "ces",
    "de",
    "d'",
    "l'",
}
# User list (no on/se/en/y)
PRON_FOR_VERB = {"je", "tu", "il", "elle", "nous", "vous", "ils"}

VERB_LEMMAS = {
    "être",
    "avoir",
    "faire",
    "aller",
    "venir",
    "vouloir",
    "pouvoir",
    "devoir",
    "prendre",
    "mettre",
    "dire",
    "voir",
    "savoir",
    "falloir",
    "passer",
    "donner",
    "parler",
    "aimer",
    "demander",
    "trouver",
    "porter",
    "laisser",
    "rendre",
    "tenir",
    "sentir",
    "partir",
    "sortir",
    "servir",
    "manger",
    "boire",
    "vivre",
    "écrire",
    "lire",
    "ouvrir",
    "couvrir",
    "offrir",
    "souffrir",
    "cueillir",
    "assaillir",
    "monter",
    "descendre",
    "rester",
    "tomber",
    "naître",
    "mourir",
    "pleuvoir",
    "neiger",
    "valoir",
    "plaire",
    "sembler",
}


def _lemma_key(t: dict) -> str:
    lem = (t.get("lemma") or "").strip().lower()
    if lem:
        return lem
    m = WORD_RE.search(t.get("text") or "")
    return m.group(0).lower() if m else ""


def _surface_head_word(t: dict) -> str:
    """First French word in token text (surface), lowercase."""
    m = WORD_RE.search(t.get("text") or "")
    return m.group(0).lower() if m else ""


def french_word_count(s: str) -> int:
    return len(WORD_RE.findall(s or ""))


def is_whitespace_only(t: dict) -> bool:
    tx = t.get("text") or ""
    return tx != "" and tx.strip() == ""


def is_punct_only(t: dict) -> bool:
    tx = t.get("text") or ""
    if not tx.strip():
        return True
    return not bool(WORD_RE.search(tx))


def is_word_token(t: dict) -> bool:
    return bool(WORD_RE.search(t.get("text") or ""))


def segment_preserving(text: str) -> list[str]:
    """Split into pieces that concatenate back to text: words, whitespace, punctuation."""
    if not text:
        return []
    parts: list[str] = []
    i = 0
    n = len(text)
    while i < n:
        if text[i].isspace():
            j = i
            while j < n and text[j].isspace():
                j += 1
            parts.append(text[i:j])
            i = j
            continue
        if not WORD_RE.match(text, i):
            parts.append(text[i])
            i += 1
            continue
        m = WORD_RE.match(text, i)
        assert m
        parts.append(m.group(0))
        i = m.end()
    return parts


def _split_ipa_parts(ipa: str) -> list[str]:
    return [p for p in (ipa or "").split() if p]


def _bucket_ipa(parts: list[str], n_buckets: int) -> list[list[str]]:
    if not parts or n_buckets <= 0:
        return [[] for _ in range(max(n_buckets, 0))]
    out: list[list[str]] = [[] for _ in range(n_buckets)]
    for j, p in enumerate(parts):
        b = min(j * n_buckets // len(parts), n_buckets - 1)
        out[b].append(p)
    return out


def atomize_token(t: dict) -> list[dict]:
    """Split one token into word / whitespace / punct sub-tokens."""
    segs = segment_preserving(t.get("text") or "")
    if len(segs) <= 1:
        return [dict(t)]
    ipa_parts = _split_ipa_parts(t.get("ipa") or "")
    word_idx = [i for i, s in enumerate(segs) if WORD_RE.search(s)]
    nw = len(word_idx)
    if nw == 1:
        wi0 = word_idx[0]
        buckets = {wi0: ipa_parts}
    else:
        b = _bucket_ipa(ipa_parts, nw)
        buckets = {word_idx[k]: b[k] for k in range(nw)}
    last_wi = word_idx[-1] if word_idx else -1
    out: list[dict] = []
    for i, s in enumerate(segs):
        if not s:
            continue
        is_w = i in word_idx
        ip = " ".join(buckets.get(i, [])) if is_w else ""
        if is_w:
            lem = t.get("lemma") if i == last_wi else None
            tr = (t.get("translation") or "") if i == last_wi else ""
            em = (t.get("emoji") or "") if i == last_wi else ""
            hi = bool(t.get("hasImage")) if i == last_wi else False
        else:
            lem, tr, em, hi = None, "", "", False
            if is_punct_only({"text": s}):
                ip = s.replace("\n", " ")
        out.append(
            {
                "text": s,
                "lemma": lem,
                "hasImage": hi,
                "emoji": em,
                "ipa": ip,
                "translation": tr,
            }
        )
    return out


def atomize_all(tokens: list[dict]) -> list[dict]:
    out: list[dict] = []
    for t in tokens:
        tx = t.get("text") or ""
        has_trailing_word_punct = bool(re.search(r"[A-Za-zÀ-ÿ]['’]?\s*[.,;:!?…]+\s*$", tx))
        multi_words = french_word_count(tx) > 1
        if multi_words or has_trailing_word_punct or re.search(r"[.,;:!?…]+\s+[A-Za-zÀ-ÿ]", tx):
            out.extend(atomize_token(t))
        else:
            out.append(dict(t))
    return out


def coalesce_whitespace(tokens: list[dict]) -> list[dict]:
    out: list[dict] = []
    i = 0
    while i < len(tokens):
        t = dict(tokens[i])
        if is_whitespace_only(t):
            if out:
                prev = dict(out[-1])
                prev["text"] = (prev.get("text") or "") + (t.get("text") or "")
                p_ip = (prev.get("ipa") or "").strip()
                w_ip = (t.get("ipa") or "").strip() or (t.get("text") or "").replace("\n", " ")
                prev["ipa"] = _join_ipa(p_ip, w_ip) if w_ip else p_ip
                out[-1] = prev
            else:
                if i + 1 < len(tokens):
                    nxt = dict(tokens[i + 1])
                    nxt["text"] = (t.get("text") or "") + (nxt.get("text") or "")
                    n_ip = (nxt.get("ipa") or "").strip()
                    w_ip = (t.get("ipa") or "").strip() or (t.get("text") or "").replace("\n", " ")
                    nxt["ipa"] = _join_ipa(w_ip, n_ip) if w_ip else n_ip
                    out.append(nxt)
                    i += 2
                    continue
                out.append(t)
            i += 1
            continue
        out.append(t)
        i += 1
    return out


def combine_range(tokens: list[dict], i: int, j: int) -> dict:
    """Inclusive merge tokens[i..j]."""
    chunk = dict(tokens[i])
    for k in range(i + 1, j + 1):
        r = tokens[k]
        chunk["text"] = (chunk.get("text") or "") + (r.get("text") or "")
        chunk["ipa"] = _join_ipa(chunk.get("ipa"), r.get("ipa"))
        if r.get("lemma"):
            chunk["lemma"] = r["lemma"]
        if r.get("hasImage"):
            chunk["hasImage"] = True
        if r.get("emoji"):
            chunk["emoji"] = r["emoji"]
        tr = (chunk.get("translation") or "").strip()
        tr2 = (r.get("translation") or "").strip()
        chunk["translation"] = tr + tr2 if tr and tr2 else (tr or tr2)
    return chunk


def _join_ipa(a: str | None, b: str | None) -> str:
    a, b = (a or "").strip(), (b or "").strip()
    if not a:
        return b
    if not b:
        return a
    return f"{a} {b}"


def redistribute_ipa_from_sentence(s: dict, tokens: list[dict]) -> None:
    """Align each token's ipa with sentence ipa by consecutive word counts (fixes merge drift)."""
    parts = _split_ipa_parts(s.get("ipa") or "")
    tw = sum(french_word_count(t.get("text") or "") for t in tokens)
    if not parts or tw != len(parts):
        return
    idx = 0
    last_word_i: int | None = None
    for ti, t in enumerate(tokens):
        if is_whitespace_only(t):
            continue
        if is_punct_only(t):
            tx = (t.get("text") or "").strip()
            if len(tx) == 1:
                t["ipa"] = tx
            continue
        nw = french_word_count(t.get("text") or "")
        if nw <= 0:
            continue
        last_word_i = ti
        chunk = parts[idx : idx + nw]
        idx += nw
        t["ipa"] = " ".join(chunk)
    if idx < len(parts) and last_word_i is not None:
        rest = parts[idx:]
        t = tokens[last_word_i]
        cur = (t.get("ipa") or "").strip()
        t["ipa"] = _join_ipa(cur, " ".join(rest))


def _is_article_word(t: dict) -> bool:
    if not is_word_token(t):
        return False
    if french_word_count(t.get("text") or "") != 1:
        return False
    sk = _surface_head_word(t)
    if sk in ARTICLE_LEMMAS:
        return True
    return bool(re.match(r"^[ld]['’][a-zàâäéèêëïîôùûüçœæ]", sk, re.I))


def _is_noun_like_after_article(t: dict) -> bool:
    if not is_word_token(t):
        return False
    if french_word_count(t.get("text") or "") != 1:
        return False
    sk = _surface_head_word(t)
    if sk in ARTICLE_LEMMAS:
        return False
    if re.match(r"^[ld]['’]", sk, re.I):
        return False
    return True


def _is_restricted_pron(t: dict) -> bool:
    if not is_word_token(t):
        return False
    if french_word_count(t.get("text") or "") != 1:
        return False
    return _surface_head_word(t) in PRON_FOR_VERB


def _is_single_verb(t: dict) -> bool:
    if not is_word_token(t):
        return False
    if french_word_count(t.get("text") or "") != 1:
        return False
    k = _lemma_key(t)
    if k in ARTICLE_LEMMAS | PRON_FOR_VERB:
        return False
    if k in VERB_LEMMAS:
        return True
    # surface heuristics for conjugated forms
    tx = (t.get("text") or "").strip().lower()
    if tx.endswith(("ez", "ent", "ons", "ais", "ait", "ions", "iez")):
        return True
    if tx in ("est", "sont", "fait", "vais", "vas", "va", "allons", "allez", "vont"):
        return True
    return bool(t.get("lemma")) and k not in ARTICLE_LEMMAS


def _second_word_index(tokens: list[dict], i: int) -> int | None:
    """Index of next word after tokens[i], allowing one whitespace-only token in between."""
    j = i + 1
    if j >= len(tokens):
        return None
    if is_whitespace_only(tokens[j]):
        j += 1
    if j >= len(tokens):
        return None
    if is_word_token(tokens[j]):
        return j
    return None


def conservative_merge_once(tokens: list[dict]) -> list[dict]:
    out: list[dict] = []
    n = len(tokens)
    i = 0
    while i < n:
        merged = False
        j = _second_word_index(tokens, i)
        if j is not None:
            a, b = tokens[i], tokens[j]
            if _is_article_word(a) and _is_noun_like_after_article(b):
                cand = combine_range(tokens, i, j)
                if french_word_count(cand["text"]) <= 3:
                    out.append(cand)
                    i = j + 1
                    merged = True
            elif _is_restricted_pron(a) and _is_single_verb(b):
                cand = combine_range(tokens, i, j)
                if french_word_count(cand["text"]) <= 3:
                    out.append(cand)
                    i = j + 1
                    merged = True
        if not merged:
            out.append(dict(tokens[i]))
            i += 1
    return out


def conservative_merge(tokens: list[dict]) -> list[dict]:
    for _ in range(4):
        nxt = conservative_merge_once(tokens)
        if nxt == tokens:
            break
        tokens = nxt
    return tokens


def emergency_unmerge_monolith(s: dict) -> list[dict]:
    """If the whole sentence is one token, split on ', ' (clauses) with rough IPA split."""
    toks = s.get("tokens") or []
    if len(toks) != 1:
        return toks
    text = toks[0].get("text") or ""
    ipa = toks[0].get("ipa") or ""
    if french_word_count(text) < 6:
        return toks
    if ", " not in text:
        return toks
    parts = text.split(", ")
    if len(parts) < 2:
        return toks
    chunks: list[str] = []
    for idx, p in enumerate(parts):
        if idx < len(parts) - 1:
            chunks.append(p + ", ")
        else:
            chunks.append(p)
    ipa_parts = _split_ipa_parts(ipa)
    buckets = _bucket_ipa(ipa_parts, len(chunks))
    base = toks[0]
    out: list[dict] = []
    for ci, ctext in enumerate(chunks):
        if not ctext:
            continue
        ip = " ".join(buckets[ci]) if ci < len(buckets) else ""
        out.append(
            {
                "text": ctext,
                "lemma": base.get("lemma") if ci == 0 else None,
                "hasImage": bool(base.get("hasImage") and ci == 0),
                "emoji": (base.get("emoji") or "") if ci == 0 else "",
                "ipa": ip,
                "translation": (base.get("translation") or "") if ci == 0 else "",
            }
        )
    joined = "".join(t["text"] for t in out)
    if joined != text:
        return toks
    return out


def apply_translation_fixes(s: dict, tokens: list[dict]) -> None:
    sid = s.get("id") or ""
    full = (s.get("text") or "").lower()
    for t in tokens:
        lem = (t.get("lemma") or "").lower()
        tx = (t.get("text") or "").lower()
        z = (t.get("translation") or "").strip()

        if lem == "frais" or re.search(r"\bfrais\b", tx):
            if "au frais" in tx or full.find("au frais") >= 0:
                t["translation"] = "冷藏；低温保存"
            else:
                t["translation"] = "新鲜"

        if lem == "addition" or "addition" in tx:
            if "结账" in z or "账单" in z:
                t["translation"] = z.replace("另外", "账单").replace("其他", "账单")
            else:
                t["translation"] = "账单"

        if lem == "passer" and re.match(r"passez?\b|passe\b", (t.get("text") or "").strip(), re.I):
            if re.search(r"soirée|journée|week-end|vacances", full):
                t["translation"] = "祝"

        # sm05: Passez devant… → 请（到）… 经过→请
        if sid == "sm05" and lem == "passer":
            t["translation"] = "请"


def process_sentence(s: dict) -> dict:
    tokens = [dict(t) for t in (s.get("tokens") or [])]
    tokens = atomize_all(tokens)
    full = s.get("text") or ""
    if "".join(t.get("text") or "" for t in tokens) != full:
        raise ValueError(f"atomize broke {s.get('id')!r}")

    tokens = conservative_merge(tokens)
    tokens = coalesce_whitespace(tokens)
    tokens = conservative_merge(tokens)
    tokens = coalesce_whitespace(tokens)

    s2 = {**s, "tokens": tokens}
    tokens = emergency_unmerge_monolith(s2)
    s2["tokens"] = tokens

    joined = "".join(t.get("text") or "" for t in tokens)
    if joined != full:
        raise ValueError(f"mismatch {s.get('id')!r}")

    redistribute_ipa_from_sentence(s, tokens)

    apply_translation_fixes(s, tokens)
    return s2


def main() -> None:
    data = json.loads(SENTENCES_PATH.read_text(encoding="utf-8"))
    sentences = data.get("sentences") or []
    fixed = [process_sentence(s) for s in sentences]
    data["sentences"] = fixed
    SENTENCES_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    one = sum(1 for s in fixed if len(s.get("tokens") or []) == 1)
    print(f"处理完成：{len(fixed)} 句（其中仅 1 个词块：{one} 句）")


if __name__ == "__main__":
    main()
