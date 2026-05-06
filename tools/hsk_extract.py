"""Parse HSK official list → batch input for emoji+skip subagent."""
import json, sys, pathlib, math

LIST_PATH = "/tmp/hsk_data/data/lists/HSK Official With Definitions 2012 L1.txt"
OUT_DIR = pathlib.Path("/Users/xieyu/projects/LLLB/tools")

words = []
for line in open(LIST_PATH, encoding="utf-8"):
    line = line.strip().lstrip("﻿")
    if not line: continue
    parts = line.split("\t")
    if len(parts) < 5: continue
    simp, _trad, _num, pinyin, en = parts[:5]
    words.append({"text": simp, "pinyin": pinyin, "en": en})

print(f"parsed {len(words)} words")

BATCH_SIZE = 30
n = math.ceil(len(words) / BATCH_SIZE)
for i in range(n):
    chunk = words[i * BATCH_SIZE:(i + 1) * BATCH_SIZE]
    p = OUT_DIR / f"hsk_shard_{i:02d}_input.json"
    json.dump(chunk, open(p, "w"), ensure_ascii=False, indent=2)
print(f"wrote {n} shards of up to {BATCH_SIZE} words each")
