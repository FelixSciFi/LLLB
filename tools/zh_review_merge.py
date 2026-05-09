"""Merge zh_review_shard_NN_output.json files, validate, tally, and produce a flat list
keyed by id with original text+verdict+reason+rewrite for human review.

Outputs:
  tools/zh_review_combined.json      — full merged decisions (id-keyed dict)
  tools/zh_review_drops.txt          — readable drop list (text + reason)
  tools/zh_review_rewrites.txt       — readable rewrite list (before → after + reason)
"""
import json, pathlib, sys
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "LearnLanguageLikeABaby/Resources/sentences_zh.json"

# Load original sentences for cross-reference
src = json.load(open(SRC))
src_by_id = {s["id"]: s for s in src["sentences"]}

# Load all shard outputs
all_decisions = []
missing_shards = []
for i in range(20):
    p = ROOT / f"tools/zh_review_shard_{i:02d}_output.json"
    if not p.exists():
        missing_shards.append(i)
        continue
    try:
        decisions = json.load(open(p))
    except json.JSONDecodeError as e:
        print(f"ERROR shard {i:02d}: invalid JSON — {e}", file=sys.stderr)
        missing_shards.append(i)
        continue
    all_decisions.extend(decisions)
    print(f"shard {i:02d}: {len(decisions)} decisions")

if missing_shards:
    print(f"\nMISSING/INVALID SHARDS: {missing_shards} — proceeding with partial merge", file=sys.stderr)

# Validate every decision points to an existing sentence
unknown = [d for d in all_decisions if d.get("id") not in src_by_id]
if unknown:
    print(f"\nWARN: {len(unknown)} decisions reference unknown ids; first 5:")
    for d in unknown[:5]:
        print(f"  {d.get('id')[:8]}  verdict={d.get('verdict')}")

# Tally
verdicts = Counter(d.get("verdict", "?") for d in all_decisions)
print(f"\nTotal decisions: {len(all_decisions)}")
for v, n in verdicts.most_common():
    print(f"  {v}: {n}")

# Build keyed dict
combined = {d["id"]: d for d in all_decisions if d.get("id") in src_by_id}
json.dump(combined, open(ROOT / "tools/zh_review_combined.json", "w"),
          ensure_ascii=False, indent=2)

# Group by verdict
drops    = [d for d in combined.values() if d["verdict"] == "drop"]
rewrites = [d for d in combined.values() if d["verdict"] == "rewrite"]

# Write readable drop list
with open(ROOT / "tools/zh_review_drops.txt", "w") as f:
    f.write(f"# DROP candidates ({len(drops)})\n")
    f.write(f"# Format: id_short  cefr  text  ←  reason\n\n")
    drops_sorted = sorted(drops, key=lambda d: (
        src_by_id[d["id"]].get("cefr", ""),
        src_by_id[d["id"]]["text"],
    ))
    for d in drops_sorted:
        s = src_by_id[d["id"]]
        f.write(f"{d['id'][:8]}  {s.get('cefr','?'):5s}  {s['text']:20s}  ←  {d.get('reason','')}\n")

# Write readable rewrite list
with open(ROOT / "tools/zh_review_rewrites.txt", "w") as f:
    f.write(f"# REWRITE candidates ({len(rewrites)})\n")
    f.write(f"# Format:\n#   id_short  cefr  reason\n#   OLD: 原文\n#   NEW: 新文  →  en\n\n")
    rewrites_sorted = sorted(rewrites, key=lambda d: (
        src_by_id[d["id"]].get("cefr", ""),
        src_by_id[d["id"]]["text"],
    ))
    for d in rewrites_sorted:
        s = src_by_id[d["id"]]
        rw = d.get("rewrite") or {}
        new_text = rw.get("text", "(missing)")
        new_en   = (rw.get("translation") or {}).get("en", "")
        f.write(f"{d['id'][:8]}  {s.get('cefr','?'):5s}  {d.get('reason','')}\n")
        f.write(f"  OLD: {s['text']}\n")
        f.write(f"  NEW: {new_text}  →  {new_en}\n\n")

print(f"\nWrote:")
print(f"  tools/zh_review_combined.json  ({len(combined)} decisions)")
print(f"  tools/zh_review_drops.txt      ({len(drops)} drops)")
print(f"  tools/zh_review_rewrites.txt   ({len(rewrites)} rewrites)")
