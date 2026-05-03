"""Extract N unreviewed, untagged sentences and split into K sub-batches for parallel subagents."""
import json, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "LearnLanguageLikeABaby/Resources/sentences_fr.json"
SIDECAR = ROOT / "tools/reviewed_ids.json"

N = int(sys.argv[1]) if len(sys.argv) > 1 else 100
K = int(sys.argv[2]) if len(sys.argv) > 2 else 10

data = json.load(open(SRC))
reviewed_ids = set(json.load(open(SIDECAR))) if SIDECAR.exists() else set()

# preserve file order — easier for the user to scan in the JSON
eligible = [s for s in data["sentences"]
            if s["id"] not in reviewed_ids and not s.get("tags")]
batch = eligible[:N]

out = [{"id": s["id"], "text": s["text"], "cefr": s.get("cefr", "A2")} for s in batch]

# write combined for diff later
json.dump(out, open(ROOT / "tools/batch_input.json", "w"), ensure_ascii=False, indent=2)

# split into K shards
import math
shard_size = math.ceil(len(out) / K)
for i in range(K):
    shard = out[i * shard_size:(i + 1) * shard_size]
    if not shard:
        continue
    p = ROOT / f"tools/shard_{i:02d}_input.json"
    json.dump(shard, open(p, "w"), ensure_ascii=False, indent=2)

total = len(data["sentences"])
print(f"total={total} reviewed={len(reviewed_ids)} eligible={len(eligible)} batch={len(out)} shards={K} per_shard={shard_size}")
