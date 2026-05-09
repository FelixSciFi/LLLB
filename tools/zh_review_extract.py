"""Extract Chinese ≤3-token, untagged sentences and split into K shards for parallel subagents.

Each shard contains the full sentence record (text, ipa, translation, cefr, tokens) so the
subagent can judge whether the sentence works without context, and propose a rewrite if the
problem is fixable.
"""
import json, sys, math, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "LearnLanguageLikeABaby/Resources/sentences_zh.json"

K = int(sys.argv[1]) if len(sys.argv) > 1 else 20
MAX_TOKENS = int(sys.argv[2]) if len(sys.argv) > 2 else 3

data = json.load(open(SRC))
sents = data["sentences"]

eligible = [
    s for s in sents
    if len(s["tokens"]) <= MAX_TOKENS and not s.get("tags")
]

print(f"total={len(sents)} eligible(≤{MAX_TOKENS}t, untagged)={len(eligible)}")

shard_size = math.ceil(len(eligible) / K)
for i in range(K):
    shard = eligible[i * shard_size:(i + 1) * shard_size]
    if not shard:
        continue
    p = ROOT / f"tools/zh_review_shard_{i:02d}_input.json"
    json.dump(shard, open(p, "w"), ensure_ascii=False, indent=2)
    print(f"  shard {i:02d}: {len(shard)} sentences -> {p.name}")

print(f"shards={K} per_shard~{shard_size}")
