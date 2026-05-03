"""Apply batch decisions to sentences_fr.json.

Decisions for batch 1 (hardcoded for traceability):
- skip:        sentences with content tags — no change, no reviewed tag
- delete:      remove from sentences[]
- use_old:     keep current metadata, add reviewed tag
- use_new:     replace metadata from batch_output.json, add reviewed tag
"""
import json, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "LearnLanguageLikeABaby/Resources/sentences_fr.json"
NEW = ROOT / "tools/batch_output.json"
DECISIONS = ROOT / "tools/batch_decisions.json"
SIDECAR = ROOT / "tools/reviewed_ids.json"

STRIP_FIELDS_FROM_NEW = {"verdict", "delete_reason", "notes", "emoji_reason"}

def clean_token(t):
    return {
        "text": t["text"],
        "lemma": t.get("lemma"),
        "ipa": t["ipa"],
        "translation": t["translation"],
        "emoji": t.get("emoji", ""),
    }

def merge_new(old, new):
    """Replace metadata fields from new, preserve id and tags from old."""
    return {
        "id": old["id"],
        "text": old["text"],          # text never changes
        "ipa": new["ipa"],
        "translation": new["translation"],
        "cefr": old.get("cefr", "A2"),  # cefr from old (not regenerated)
        "tokens": [clean_token(t) for t in new["tokens"]],
        **({"tags": old["tags"]} if old.get("tags") else {}),
    }

def add_reviewed_tag(sentence, reviewed_ids):
    """Mark a sentence as reviewed in the sidecar set (NOT in sentence.tags)."""
    reviewed_ids.add(sentence["id"])
    return sentence

decisions = json.load(open(DECISIONS))
data = json.load(open(SRC))
new_by_id = {n["id"]: n for n in json.load(open(NEW))}
src_by_id = {s["id"]: s for s in data["sentences"]}
reviewed_ids = set(json.load(open(SIDECAR))) if SIDECAR.exists() else set()

actions = {"skip": 0, "delete": 0, "use_old": 0, "use_new": 0}
delete_ids = set()
log = []

for d in decisions:
    sid = d["id"]
    action = d["action"]
    s = src_by_id[sid]
    actions[action] += 1
    if action == "skip":
        log.append(f"  SKIP    [{sid[:8]}] {s['text']!r}")
    elif action == "delete":
        delete_ids.add(sid)
        log.append(f"  DELETE  [{sid[:8]}] {s['text']!r}  ({d.get('reason','')})")
    elif action == "use_old":
        add_reviewed_tag(s, reviewed_ids)
        log.append(f"  KEEP    [{sid[:8]}] {s['text']!r}  (metadata unchanged)")
    elif action == "use_new":
        merged = merge_new(s, new_by_id[sid])
        # preserve any existing non-reviewed tags
        if s.get("tags"):
            merged["tags"] = s["tags"]
        add_reviewed_tag(merged, reviewed_ids)
        src_by_id[sid] = merged
        log.append(f"  UPDATE  [{sid[:8]}] {s['text']!r}  (metadata replaced)")

# rebuild sentences list preserving order, dropping deletes, applying updates
new_sentences = []
for s in data["sentences"]:
    if s["id"] in delete_ids:
        continue
    new_sentences.append(src_by_id[s["id"]])
data["sentences"] = new_sentences

json.dump(data, open(SRC, "w"), ensure_ascii=False, indent=2)
json.dump(sorted(reviewed_ids), open(SIDECAR, "w"), ensure_ascii=False, indent=2)

print("=== Action summary ===")
for k, v in actions.items():
    print(f"  {k:10} {v}")
print(f"  total      {sum(actions.values())}")
print(f"\n=== Per-sentence log ===")
for line in log:
    print(line)
print(f"\nTotal sentences after apply: {len(new_sentences)}")
