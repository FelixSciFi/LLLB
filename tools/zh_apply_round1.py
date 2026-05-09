"""Apply round-1 zh review decisions:
- Drop the 16 confirmed sentence-residue ids (A class)
- Rewrite the 9 confirmed sentence-level fix ids (B1 class)

Bareword rewrites (85) and bareword drops (2099) are NOT applied — user policy
"裸词留着". They will be silently kept by skipping their decisions.

Reads zh_review_combined.json + the original sentences_zh.json.
Writes back sentences_zh.json (in place).
"""
import json, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "LearnLanguageLikeABaby/Resources/sentences_zh.json"
COMBINED = ROOT / "tools/zh_review_combined.json"

PUNCT = ("。", "！", "？")  # 。！？

def is_sentence(s):
    """A 'sentence' = has end-punct OR has >1 token."""
    return any(c in s["text"] for c in PUNCT) or len(s["tokens"]) > 1

data = json.load(open(SRC))
decisions = json.load(open(COMBINED))
src_by_id = {s["id"]: s for s in data["sentences"]}

drop_ids = set()
rewrite_map = {}  # id -> rewrite obj

for d in decisions.values():
    sid = d.get("id")
    if sid not in src_by_id:
        continue
    s = src_by_id[sid]
    sent = is_sentence(s)
    if d.get("verdict") == "drop":
        if sent:
            drop_ids.add(sid)
    elif d.get("verdict") == "rewrite":
        if sent:
            rw = d.get("rewrite") or {}
            if not rw.get("text") or not rw.get("tokens"):
                print(f"WARN skip rewrite (missing fields): {sid[:8]} {s['text']}", file=sys.stderr)
                continue
            rewrite_map[sid] = rw

print(f"Will DROP {len(drop_ids)} sentences:")
for sid in sorted(drop_ids):
    print(f"  {sid[:8]}  {src_by_id[sid]['text']}")

print(f"\nWill REWRITE {len(rewrite_map)} sentences:")
for sid in sorted(rewrite_map):
    s = src_by_id[sid]
    rw = rewrite_map[sid]
    print(f"  {sid[:8]}  {s['text']}  ->  {rw.get('text')}")

# Apply: build new sentence list
new_sents = []
for s in data["sentences"]:
    if s["id"] in drop_ids:
        continue
    if s["id"] in rewrite_map:
        rw = rewrite_map[s["id"]]
        # Keep id + cefr + tags (preserve any tags from old record),
        # replace text/ipa/translation/tokens.
        new_s = {
            "id": s["id"],
            "text": rw["text"],
            "ipa": rw.get("ipa", ""),
            "translation": rw.get("translation", {}),
            "cefr": s.get("cefr", "HSK1"),
            "tokens": rw["tokens"],
        }
        if s.get("tags"):
            new_s["tags"] = s["tags"]
        new_sents.append(new_s)
    else:
        new_sents.append(s)

data["sentences"] = new_sents
json.dump(data, open(SRC, "w"), ensure_ascii=False, indent=2)

print(f"\nWrote {SRC} ({len(new_sents)} sentences, was {len(src_by_id)})")
