#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Re-chunk sentences.json into 3–6 learning units per sentence (spaCy + heuristics).
Merges: article+noun phrases, pronoun+verb, fixed expressions; punctuation → previous chunk.
Fills Chinese via Google Translate (deep-translator); lemmas from spaCy.
"""

from __future__ import annotations

import importlib.util
import json
import re
import sys
import time
from pathlib import Path

import spacy
from deep_translator import GoogleTranslator

ROOT = Path(__file__).resolve().parents[1]
SENTENCES_PATH = ROOT / "LearnLanguageLikeABaby" / "Resources" / "sentences.json"
EXAMPLES_PATH = ROOT / "LearnLanguageLikeABaby" / "Resources" / "exampleSentences.json"
RETOKENIZE = ROOT / "scripts" / "retokenize_sentences.py"

# --- IPA helpers (must match retokenize_sentences IPA_FUSED) ---
IPA_FUSED: dict[str, list[str]] = {
    "kɔmɑ̃talevu": ["kɔmɑ̃", "ale", "vu"],
    "afɛ̃": ["a", "fɛ̃"],
    "dɔnlyi": ["dɔn", "lɥi"],
    "domineʁal": ["do", "mineʁal"],
    "dəmikilo": ["də", "mikilo"],
    "fɛtmwa": ["fɛt", "mwa"],
    "dɔnemwa": ["dɔne", "mwa"],
    "gaʁdmwa": ["gaʁde", "mwa"],
    "ɛkskyzemwa": ["ɛkskyze", "mwa"],
}


def _ipa_tokens(ipa: str) -> list[str]:
    s = ipa.strip()
    if not s:
        return []
    return [p for p in re.split(r"\s+", s) if p]


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
        while len(ipa) < len(w):
            ipa.append(ipa[-1] if ipa else "")
        while len(ipa) > len(w):
            ipa[-2] = ipa[-2] + " " + ipa[-1]
            ipa.pop()
    return ipa


def _align_ipa_pad_words(words: list[str], ipa_parts: list[str]) -> list[str]:
    """One IPA slot per surface word: pad or merge IPA slots only (never merge orthographic words)."""
    ipa = _flatten_ipa_parts(ipa_parts)
    w = list(words)
    while len(ipa) > len(w) and len(w) >= 1:
        ipa[-2] = ipa[-2] + " " + ipa[-1]
        ipa.pop()
    while len(ipa) < len(w):
        ipa.append(ipa[-1] if ipa else "")
    return ipa[: len(w)]


def _norm_apos(s: str) -> str:
    return s.replace("\u2019", "'").replace("\u2018", "'")


# Longest first — matched against lowercased norm(text)
FIXED_PHRASES: tuple[str, ...] = tuple(
    sorted(
        {
            "qu'est-ce que",
            "qu'est-ce qui",
            "n'est-ce pas",
            "est-ce que",
            "est-ce qu'",
            "s'il vous plaît",
            "s'il te plaît",
            "il n'y a pas",
            "il n'y a",
            "n'y a-t-il",
            "y a-t-il",
            "il y a",
            "peut-être",
            "aujourd'hui",
            "à côté de",
            "en face de",
            "en face",
            "à gauche",
            "à droite",
            "tout droit",
            "parce que",
            "d'accord",
            "tout de suite",
        },
        key=len,
        reverse=True,
    )
)

FIXED_TRANSLATION: dict[str, str] = {
    "s'il vous plaît": "请",
    "s'il te plaît": "请",
}

# Google often returns empty for isolated copulas / spacing
AUX_SURFACE_ZH: dict[str, str] = {
    "est": "是",
    "sont": "是",
    "été": "是",
    "sera": "将是",
    "étais": "是",
    "était": "是",
    "sommes": "是",
    "êtes": "是",
    "ai": "有",
    "as": "有",
    "a": "有",
    "avez": "有",
    "ont": "有",
    "suis": "是",
    "es": "是",
}

# spaCy lemma quirks in short spans
LEMMA_OVERRIDE: dict[str, str] = {
    "prend": "prendre",
    "voudr": "vouloir",
    "fais": "faire",
    "fait": "faire",
    "dis": "dire",
    "dit": "dire",
    "suis": "être",
    "es": "être",
    "est": "être",
    "sommes": "être",
    "êtes": "être",
    "sont": "être",
    "ai": "avoir",
    "as": "avoir",
    "a": "avoir",
    "avez": "avoir",
    "ont": "avoir",
}


def _load_retokenize_module():
    spec = importlib.util.spec_from_file_location("retokenize_sentences", str(RETOKENIZE))
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader
    spec.loader.exec_module(mod)
    return mod


def find_fixed_spans(text: str) -> list[tuple[int, int]]:
    tn = _norm_apos(text)
    tl = tn.lower()
    found: list[tuple[int, int]] = []
    for phrase in FIXED_PHRASES:
        pn = _norm_apos(phrase).lower()
        start = 0
        while True:
            i = tl.find(pn, start)
            if i < 0:
                break
            found.append((i, i + len(pn)))
            start = i + 1
    found.sort(key=lambda x: -(x[1] - x[0]))
    picked: list[tuple[int, int]] = []

    def overlaps(a: tuple[int, int], b: tuple[int, int]) -> bool:
        return not (a[1] <= b[0] or b[1] <= a[0])

    for sp in found:
        if any(overlaps(sp, p) for p in picked):
            continue
        picked.append(sp)
    picked.sort(key=lambda x: x[0])
    return picked


def span_intersects(a: tuple[int, int], b: tuple[int, int]) -> bool:
    return not (a[1] <= b[0] or b[1] <= a[0])


NP_CHILD_DEPS = {"det", "compound", "nummod", "flat", "fixed", "case"}


def _collect_np_tokens(head) -> list:
    """Noun head + determiners / compounds / de-structures — not full UD subtree (avoids swallowing questions)."""
    out: set = {head}
    stack = [head]
    while stack:
        t = stack.pop()
        for c in t.children:
            if c in out:
                continue
            if c.dep_ in NP_CHILD_DEPS:
                out.add(c)
                stack.append(c)
            elif c.dep_ == "nmod":
                for x in c.subtree:
                    if x not in out:
                        out.add(x)
                        stack.append(x)
    return sorted(out, key=lambda z: z.i)


def noun_phrase_spans(doc) -> list[tuple[int, int, object]]:
    """(start_char, end_char, head_noun_token) maximal non-overlapping NPs."""
    candidates: list[tuple[int, int, int, object]] = []
    for token in doc:
        if token.pos_ not in ("NOUN", "PROPN"):
            continue
        toks = _collect_np_tokens(token)
        if not toks:
            continue
        sc, ec = toks[0].idx, toks[-1].idx + len(toks[-1].text)
        candidates.append((ec - sc, sc, ec, token))
    candidates.sort(reverse=True)
    used_tok_idx: set[int] = set()
    out: list[tuple[int, int, object]] = []
    for _, sc, ec, head in candidates:
        ii = {t.i for t in _collect_np_tokens(head)}
        if ii & used_tok_idx:
            continue
        out.append((sc, ec, head))
        used_tok_idx |= ii
    return out


def merge_intervals(intervals: list[tuple[int, int]]) -> list[tuple[int, int]]:
    if not intervals:
        return []
    s = sorted(intervals)
    m = [s[0]]
    for a, b in s[1:]:
        la, lb = m[-1]
        if a <= lb:
            m[-1] = (la, max(lb, b))
        else:
            m.append((a, b))
    return m




def complement_spans(text_len: int, covered: list[tuple[int, int]]) -> list[tuple[int, int]]:
    if not covered:
        return [(0, text_len)]
    cov = merge_intervals(covered)
    out = []
    cur = 0
    for a, b in cov:
        if cur < a:
            out.append((cur, a))
        cur = max(cur, b)
    if cur < text_len:
        out.append((cur, text_len))
    return out


def is_punct_or_space_only(s: str) -> bool:
    s2 = s.strip()
    if not s2:
        return True
    return not any(c.isalpha() or c.isdigit() for c in s2)


def chunk_sentence(text: str, doc) -> list[dict]:
    """Returns list of {start, end, head_token, kind} before text slice."""
    fixed = find_fixed_spans(text)
    nps = noun_phrase_spans(doc)
    np_spans = [(sc, ec, h) for sc, ec, h in nps if not any(span_intersects((sc, ec), f) for f in fixed)]

    covered = merge_intervals(list(fixed) + [(sc, ec) for sc, ec, _ in np_spans])
    gaps = complement_spans(len(text), covered)

    pieces: list[tuple[int, int, object | None, str]] = []
    for sc, ec in fixed:
        pieces.append((sc, ec, None, "fixed"))
    for sc, ec, head in np_spans:
        pieces.append((sc, ec, head, "np"))
    for sc, ec in gaps:
        if sc >= ec:
            continue
        seg = text[sc:ec]
        if not seg.strip():
            continue
        pieces.append((sc, ec, None, "gap"))

    pieces.sort(key=lambda x: (x[0], -(x[1] - x[0])))

    # Pull whitespace-only gaps into previous piece so coverage is contiguous
    changed = True
    while changed:
        changed = False
        i = 0
        while i < len(pieces) - 1:
            sc1, ec1, h1, k1 = pieces[i]
            sc2, ec2, h2, k2 = pieces[i + 1]
            mid = text[ec1:sc2]
            if not mid.strip() and mid:
                pieces[i] = (sc1, sc2, h1, k1)
                changed = True
            i += 1

    # Fold punctuation-only spans into previous chunk (or next if first)
    folded: list[tuple[int, int, object | None, str]] = []
    for sc, ec, head, kind in pieces:
        seg = text[sc:ec]
        if is_punct_or_space_only(seg) and seg.strip():
            if folded:
                ps, pe, ph, pk = folded[-1]
                folded[-1] = (ps, ec, ph, pk)
            else:
                folded.append((sc, ec, head, kind))
            continue
        folded.append((sc, ec, head, kind))

    # Leading punct-only piece: merge into following
    if folded and is_punct_or_space_only(text[folded[0][0] : folded[0][1]]) and folded[0][2] is None:
        if len(folded) >= 2:
            sc0, ec0, _, _ = folded[0]
            sc1, ec1, h1, k1 = folded[1]
            folded = [(sc0, ec1, h1, k1)] + folded[2:]

    folded.sort(key=lambda x: x[0])
    # sanity: no overlap
    out: list[tuple[int, int, object | None, str]] = []
    for it in folded:
        if out and it[0] < out[-1][1]:
            # overlap — extend previous
            a, b, h, k = out[-1]
            out[-1] = (a, max(b, it[1]), it[2] or h, it[3] if it[2] else k)
        else:
            out.append(it)

    cur = 0
    for a, b, _, _ in out:
        if a != cur:
            return [{"start": 0, "end": len(text), "head": None, "kind": "all"}]
        cur = b
    if cur != len(text):
        return [{"start": 0, "end": len(text), "head": None, "kind": "all"}]

    return [{"start": a, "end": b, "head": h, "kind": k} for a, b, h, k in out]


def head_lemma_for_chunk(doc, start: int, end: int, head_tok, kind: str) -> str | None:
    if kind == "fixed":
        return None
    if head_tok is not None:
        lem = head_tok.lemma_.lower()
        return LEMMA_OVERRIDE.get(lem, lem)
    # gap: find main verb / content word
    toks = [t for t in doc if t.idx >= start and t.idx + len(t.text) <= end and t.pos_ != "PUNCT"]
    if not toks:
        return None
    verbs = [t for t in toks if t.pos_ in ("VERB", "AUX")]
    if verbs:
        root = max(verbs, key=lambda t: (t.dep_ == "ROOT", t.i))
        lem = root.lemma_.lower()
        return LEMMA_OVERRIDE.get(lem, lem)
    return toks[-1].lemma_.lower()


def content_pos_in_span(doc, start: int, end: int) -> bool:
    for t in doc:
        if t.idx < start or t.idx + len(t.text) > end:
            continue
        if t.pos_ in ("NOUN", "VERB", "ADJ", "ADV", "PROPN", "NUM"):
            return True
        if t.pos_ == "PRON" and t.lemma_.lower() in ("moi", "toi", "lui", "elle", "nous", "vous", "eux"):
            return True
    return False


def assign_chunk_ipa(text: str, ipa_sentence: str, doc, start: int, end: int) -> str:
    chunk_tx = text[start:end]
    if re.search(r"s'\s*il\s+(vous|te)\s+plaît", _norm_apos(chunk_tx), re.I):
        tail = _flatten_ipa_parts(_ipa_tokens(ipa_sentence))[-3:]
        if len(tail) == 3:
            return " ".join(tail)

    parts = _flatten_ipa_parts(_ipa_tokens(ipa_sentence))
    all_surface = [t.text for t in doc if t.pos_ != "PUNCT" and not t.is_space]
    aligned = _align_ipa_pad_words(all_surface, parts)
    idx_map: dict[int, str] = {}
    j = 0
    for t in doc:
        if t.pos_ == "PUNCT" or t.is_space:
            continue
        if j < len(aligned):
            idx_map[t.i] = aligned[j]
            j += 1
    ips = []
    for t in doc:
        if t.pos_ == "PUNCT" or t.is_space:
            continue
        if t.idx < start or t.idx + len(t.text) > end:
            continue
        ips.append(idx_map.get(t.i, t.text))
    if not ips:
        return text[start:end].replace("\n", " ")
    return " ".join(ips)


def polish_translation(
    fr_slice_norm: str,
    raw_zh: str,
    kind: str,
    has_content: bool,
) -> str:
    key = _norm_apos(fr_slice_norm.strip()).lower()
    if key in FIXED_TRANSLATION:
        return FIXED_TRANSLATION[key]
    if re.search(r"s'\s*il\s+(vous|te)\s+plaît", _norm_apos(fr_slice_norm), re.I):
        return "请"
    if not has_content:
        return ""
    return raw_zh.strip() if raw_zh else ""


def reduce_chunk_count(
    chunks: list[dict],
    translator: GoogleTranslator,
    zh_cache: dict[str, str],
    max_n: int = 6,
) -> list[dict]:
    while len(chunks) > max_n and len(chunks) >= 2:
        best_i = 0
        best_len = len(chunks[0]["text"]) + len(chunks[1]["text"])
        for i in range(len(chunks) - 1):
            ln = len(chunks[i]["text"]) + len(chunks[i + 1]["text"])
            if ln < best_len:
                best_len = ln
                best_i = i
        a, b = chunks[best_i], chunks[best_i + 1]
        merged_text = a["text"] + b["text"]
        ipa_a = (a.get("ipa") or "").strip()
        ipa_b = (b.get("ipa") or "").strip()
        merged_ipa = ipa_a + (" " if ipa_a and ipa_b else "") + ipa_b
        key = _norm_apos(merged_text.strip()).lower()
        if key not in zh_cache and merged_text.strip():
            try:
                zh_cache[key] = translator.translate(merged_text.strip())
                time.sleep(0.03)
            except Exception:
                zh_cache[key] = (a.get("translation") or "") + (b.get("translation") or "")
        zh = zh_cache.get(key, (a.get("translation") or "") + (b.get("translation") or ""))
        merged = {
            "text": merged_text,
            "lemma": b.get("lemma") or a.get("lemma"),
            "hasImage": bool(a.get("hasImage") or b.get("hasImage")),
            "emoji": b.get("emoji") or a.get("emoji") or "",
            "ipa": merged_ipa,
            "translation": zh.strip(),
        }
        chunks = chunks[:best_i] + [merged] + chunks[best_i + 2 :]
    return chunks


def process_corpus(sentences: list[dict], translator: GoogleTranslator, lemma_emoji: dict[str, str]) -> list[dict]:
    nlp = spacy.load("fr_core_news_sm")
    zh_cache: dict[str, str] = {}
    out_sentences = []

    for s in sentences:
        text = s["text"]
        doc = nlp(text)
        meta = chunk_sentence(text, doc)
        tokens_out: list[dict] = []
        for m in meta:
            sc, ec = m["start"], m["end"]
            sl = text[sc:ec]
            kind = m["kind"]
            head_tok = m["head"]
            lem = head_lemma_for_chunk(doc, sc, ec, head_tok, kind)
            has_content = content_pos_in_span(doc, sc, ec)
            key = _norm_apos(sl.strip()).lower()
            if key in zh_cache:
                zh = zh_cache[key]
            else:
                if has_content and sl.strip():
                    try:
                        zh = translator.translate(sl.strip())
                        time.sleep(0.03)
                    except Exception:
                        zh = ""
                else:
                    zh = ""
                zh_cache[key] = zh
            zh = polish_translation(sl, zh, kind, has_content)
            if not zh and has_content:
                st = sl.strip().lower()
                if st in AUX_SURFACE_ZH:
                    zh = AUX_SURFACE_ZH[st]
            ipa = assign_chunk_ipa(text, s.get("ipa") or "", doc, sc, ec)
            em = lemma_emoji.get(lem or "", "") if lem else ""
            tokens_out.append(
                {
                    "text": sl,
                    "lemma": lem,
                    "hasImage": bool(em),
                    "emoji": em or "",
                    "ipa": ipa,
                    "translation": zh,
                }
            )
        tokens_out = reduce_chunk_count(tokens_out, translator, zh_cache, max_n=6)
        assert "".join(t["text"] for t in tokens_out) == text, (s["id"], "".join(t["text"] for t in tokens_out), text)
        out_sentences.append({**s, "tokens": tokens_out})
    return out_sentences


def build_lemma_emoji_map(sentences: list[dict]) -> dict[str, str]:
    m: dict[str, str] = {}
    for s in sentences:
        for t in s.get("tokens", []):
            lem = t.get("lemma")
            em = t.get("emoji") or ""
            if lem and em and t.get("hasImage"):
                m[lem] = em
    return m


def main() -> None:
    data = json.loads(SENTENCES_PATH.read_text(encoding="utf-8"))
    sentences = data["sentences"]
    lemma_emoji = build_lemma_emoji_map(sentences)
    translator = GoogleTranslator(source="fr", target="zh-CN")
    new_sentences = process_corpus(sentences, translator, lemma_emoji)

    rt = _load_retokenize_module()
    for s in new_sentences:
        rt.fill_empty_token_ipa(s)
    examples = rt.build_examples_by_lemma(new_sentences)

    SENTENCES_PATH.write_text(json.dumps({"sentences": new_sentences}, ensure_ascii=False, indent=2), encoding="utf-8")
    EXAMPLES_PATH.write_text(json.dumps({"examples_by_lemma": examples}, ensure_ascii=False, indent=2), encoding="utf-8")
    ntok = sum(len(s["tokens"]) for s in new_sentences)
    print("sentences:", len(new_sentences), "total chunks:", ntok, "avg:", ntok / len(new_sentences))


if __name__ == "__main__":
    main()
