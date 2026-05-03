"""Diff blind-regen output against original sentences. Bucket into auto-pass / auto-update / needs-human / delete."""
import json, pathlib, re

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "LearnLanguageLikeABaby/Resources/sentences_fr.json"
NEW = ROOT / "tools/batch_output.json"
REPORT = ROOT / "tools/diff_report.json"

def norm_ipa(s):
    if not s: return ""
    return re.sub(r"\s+", " ", s.replace("r", "ʁ")).strip().lower()

def norm_text(s):
    if not s: return ""
    return re.sub(r"\s+", " ", s).strip().lower()

src = {s["id"]: s for s in json.load(open(SRC))["sentences"]}
new_list = json.load(open(NEW))

buckets = {"auto_pass": [], "auto_update": [], "needs_human": [], "delete": []}

for n in new_list:
    sid = n["id"]
    o = src[sid]
    diffs = []

    if n["verdict"] == "delete":
        buckets["delete"].append({"id": sid, "text": o["text"], "reason": n.get("delete_reason", ""), "old": o, "new": n})
        continue

    # sentence IPA
    old_ipa = norm_ipa(o.get("ipa", ""))
    new_ipa = norm_ipa(n.get("ipa", ""))
    ipa_only_rphi = old_ipa == new_ipa and o.get("ipa", "") != n.get("ipa", "")
    if old_ipa != new_ipa:
        diffs.append(("ipa", o.get("ipa"), n.get("ipa")))

    # translations
    for lang in ("zh", "en"):
        ot = norm_text(o.get("translation", {}).get(lang, ""))
        nt = norm_text(n.get("translation", {}).get(lang, ""))
        if ot != nt:
            diffs.append((f"tr.{lang}", o.get("translation", {}).get(lang), n.get("translation", {}).get(lang)))

    # tokens: count + per-token text/lemma/ipa/translation/emoji
    o_toks = o.get("tokens", [])
    n_toks = n.get("tokens", [])
    if len(o_toks) != len(n_toks):
        diffs.append(("token_count", len(o_toks), len(n_toks)))
    else:
        for i, (ot, nt) in enumerate(zip(o_toks, n_toks)):
            if norm_text(ot.get("text", "")) != norm_text(nt.get("text", "")):
                diffs.append((f"tok{i}.text", ot.get("text"), nt.get("text")))
            if (ot.get("lemma") or "") != (nt.get("lemma") or ""):
                diffs.append((f"tok{i}.lemma", ot.get("lemma"), nt.get("lemma")))
            if norm_ipa(ot.get("ipa", "")) != norm_ipa(nt.get("ipa", "")):
                diffs.append((f"tok{i}.ipa", ot.get("ipa"), nt.get("ipa")))
            for lang in ("zh", "en"):
                a = norm_text((ot.get("translation") or {}).get(lang, ""))
                b = norm_text((nt.get("translation") or {}).get(lang, ""))
                if a != b:
                    diffs.append((f"tok{i}.tr.{lang}", (ot.get("translation") or {}).get(lang), (nt.get("translation") or {}).get(lang)))
            if (ot.get("emoji") or "") != (nt.get("emoji") or ""):
                diffs.append((f"tok{i}.emoji", ot.get("emoji"), nt.get("emoji")))

    entry = {"id": sid, "text": o["text"], "diffs": diffs, "old": o, "new": n}

    if not diffs:
        buckets["auto_pass"].append(entry)
    elif len(diffs) == 1 and diffs[0][0] == "ipa" and ipa_only_rphi:
        buckets["auto_update"].append(entry)
    else:
        buckets["needs_human"].append(entry)

json.dump(buckets, open(REPORT, "w"), ensure_ascii=False, indent=2)

print(f"auto_pass:    {len(buckets['auto_pass'])}")
print(f"auto_update:  {len(buckets['auto_update'])}  (r→ʁ only)")
print(f"needs_human:  {len(buckets['needs_human'])}")
print(f"delete:       {len(buckets['delete'])}")
print(f"\nreport -> {REPORT}")
