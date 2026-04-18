#!/usr/bin/env python3
"""Fill IPA for each lemma in word_table_fr.json via OpenAI GPT-4o (batched).

Requires: OPENAI_API_KEY in environment.
Optional: OPENAI_BASE_URL (default https://api.openai.com/v1)
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WT = ROOT / "LearnLanguageLikeABaby" / "Resources" / "word_table_fr.json"

BATCH_SIZE = 50
MODEL = "gpt-4o"


def extract_json_array(text: str) -> list:
    text = text.strip()
    m = re.search(r"```(?:json)?\s*([\s\S]*?)```", text)
    if m:
        text = m.group(1).strip()
    text = text.strip()
    start = text.find("[")
    end = text.rfind("]")
    if start == -1 or end == -1 or end <= start:
        raise ValueError(f"No JSON array in model output: {text[:500]}...")
    return json.loads(text[start : end + 1])


def chat_completion(api_key: str, base_url: str, prompt: str) -> str:
    url = base_url.rstrip("/") + "/chat/completions"
    body = json.dumps(
        {
            "model": MODEL,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.2,
        }
    ).encode("utf-8")
    req = urllib.request.Request(url, data=body, method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {api_key}")
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {e.code}: {err}") from e
    try:
        return data["choices"][0]["message"]["content"]
    except (KeyError, IndexError) as e:
        raise RuntimeError(f"Unexpected API response: {data}") from e


def main() -> None:
    api_key = os.environ.get("OPENAI_API_KEY", "").strip()
    if not api_key:
        print("Error: set OPENAI_API_KEY", file=sys.stderr)
        sys.exit(1)
    base_url = os.environ.get("OPENAI_BASE_URL", "https://api.openai.com/v1")

    with WT.open("r", encoding="utf-8") as f:
        data = json.load(f)

    words = data.get("words", [])
    total = len(words)

    for start in range(0, total, BATCH_SIZE):
        batch = words[start : start + BATCH_SIZE]
        lemmas = [w["lemma"] for w in batch]
        prompt = (
            "为以下法语词提供IPA音标，只输出JSON数组，格式：\n"
            '[{"lemma": "maman", "ipa": "mamɑ̃"}, ...]\n\n'
            f"词列表：{json.dumps(lemmas, ensure_ascii=False)}"
        )
        raw = chat_completion(api_key, base_url, prompt)
        arr = extract_json_array(raw)
        by_lemma = {item["lemma"]: item.get("ipa", "").strip() for item in arr if isinstance(item, dict) and "lemma" in item}
        for w in batch:
            lem = w["lemma"]
            if lem in by_lemma:
                w["ipa"] = by_lemma[lem]
            else:
                print(f"Warning: missing IPA in batch response for lemma: {lem}", file=sys.stderr)
        done = min(start + BATCH_SIZE, total)
        print(f"progress: {done}/{total}")
        time.sleep(0.4)

    with WT.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    with_ipa = sum(1 for w in words if str(w.get("ipa", "")).strip())
    print(f"done. words with non-empty ipa: {with_ipa}/{total}")


if __name__ == "__main__":
    main()
