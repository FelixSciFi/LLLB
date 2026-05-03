"""One-shot migration: move 'reviewed' marker out of sentences[].tags into a sidecar file.

Sidecar: tools/reviewed_ids.json (a JSON array of sentence IDs)
"""
import json, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "LearnLanguageLikeABaby/Resources/sentences_fr.json"
SIDECAR = ROOT / "tools/reviewed_ids.json"

data = json.load(open(SRC))
reviewed_ids = []
cleaned = 0
for s in data["sentences"]:
    tags = s.get("tags", [])
    new_tags = [t for t in tags if t.get("name") != "reviewed"]
    if len(new_tags) != len(tags):
        reviewed_ids.append(s["id"])
        cleaned += 1
        if new_tags:
            s["tags"] = new_tags
        else:
            s.pop("tags", None)

json.dump(reviewed_ids, open(SIDECAR, "w"), ensure_ascii=False, indent=2)
json.dump(data, open(SRC, "w"), ensure_ascii=False, indent=2)
print(f"removed 'reviewed' tag from {cleaned} sentences")
print(f"sidecar written: {SIDECAR}  ({len(reviewed_ids)} ids)")
