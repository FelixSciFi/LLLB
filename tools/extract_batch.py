"""Extract a batch of unreviewed sentences (text + cefr only) for blind regen."""
import json, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "LearnLanguageLikeABaby/Resources/sentences_fr.json"
OUT = ROOT / "tools/batch_input.json"

N = int(sys.argv[1]) if len(sys.argv) > 1 else 30

data = json.load(open(SRC))
SIDECAR = ROOT / "tools/reviewed_ids.json"
reviewed_ids = set(json.load(open(SIDECAR))) if SIDECAR.exists() else set()

def is_reviewed(s):
    return s["id"] in reviewed_ids

def has_content_tag(s):
    # any tag in sentences[].tags is a content/group tag — skip in batch review
    return bool(s.get("tags"))

# preserve file order — easier for the user to scan in the JSON
eligible = [s for s in data["sentences"] if not is_reviewed(s) and not has_content_tag(s)]
batch = eligible[:N]

# stats
total = len(data["sentences"])
reviewed = sum(1 for s in data["sentences"] if is_reviewed(s))
tagged = sum(1 for s in data["sentences"] if has_content_tag(s) and not is_reviewed(s))
print(f"total={total}  reviewed={reviewed}  content-tagged-skipped={tagged}  eligible={len(eligible)}")

out = [{"id": s["id"], "text": s["text"], "cefr": s.get("cefr", "A2")} for s in batch]
json.dump(out, open(OUT, "w"), ensure_ascii=False, indent=2)
print(f"extracted {len(out)} sentences -> {OUT}")
