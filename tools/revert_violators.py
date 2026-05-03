"""Revert specific sentences to git-HEAD original metadata.
Reason: their use_new application violated the user's merging rules
(C'est merges, être merges, subject-pronoun + verb merge, et merges forward).
The reviewed marker stays in the sidecar — these sentences are still considered reviewed
(just with their original-and-correct merging restored).
"""
import json, pathlib, subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "LearnLanguageLikeABaby/Resources/sentences_fr.json"

VIOLATOR_PREFIXES = [
    "00d67769",  # Le soleil... sont dans le ciel
    "0279be76",  # C'est génial !
    "040049f2",  # Le désert est sec.
    "0c1c6b10",  # C'est parti !
    "09640996",  # Ma maison a trois pièces.
    "08c17836",  # Tu peux pas m'attraper !
    "0d4ac032",  # Deux professeurs canadiens.
    "0e800798",  # Le billet coûte cinq cents euros.
    "0d34f12e",  # Non, nous n'en avons pas besoin.
    "0b482b94",  # je veux rentrer à la maison
    "0edf98b0",  # des frites et un coca
    "0ef8491e",  # Tu m'aides ?
]

# Read git-HEAD original
orig_text = subprocess.check_output(
    ["git", "show", "HEAD:LearnLanguageLikeABaby/Resources/sentences_fr.json"],
    cwd=ROOT,
).decode()
orig = json.loads(orig_text)
orig_by_id = {s["id"]: s for s in orig["sentences"]}

data = json.load(open(SRC))
reverted = 0
for i, s in enumerate(data["sentences"]):
    if any(s["id"].startswith(p) for p in VIOLATOR_PREFIXES):
        original = orig_by_id.get(s["id"])
        if original:
            # restore original, but preserve any non-reviewed tags from current
            restored = dict(original)
            if s.get("tags"):
                restored["tags"] = s["tags"]
            else:
                restored.pop("tags", None)
            data["sentences"][i] = restored
            reverted += 1
            print(f"  revert [{s['id'][:8]}] {s['text']!r}")

json.dump(data, open(SRC, "w"), ensure_ascii=False, indent=2)
print(f"\nreverted {reverted} sentences to git-HEAD original metadata")
