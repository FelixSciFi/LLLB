#!/usr/bin/env python3
"""
LLLB Library Generator
基于 LIBRARY_STANDARD.md 生成和维护句库
用法：
  python scripts/generate_library.py --action generate --lang fr --level A1 --count 50
  python scripts/generate_library.py --action classify --lang fr
  python scripts/generate_library.py --action clean --lang fr
  python scripts/generate_library.py --action validate --lang fr

依赖： pip install openai
从项目根目录运行；也可从其他目录运行（路径相对于本脚本所在仓库根目录解析）。
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STANDARD_PATH = ROOT / "LIBRARY_STANDARD.md"


def _require_api_key() -> None:
    if not os.environ.get("OPENAI_API_KEY"):
        print("错误：未设置环境变量 OPENAI_API_KEY", file=sys.stderr)
        sys.exit(1)


def load_standard() -> str:
    if not STANDARD_PATH.is_file():
        print(f"错误：找不到 {STANDARD_PATH}", file=sys.stderr)
        sys.exit(1)
    return STANDARD_PATH.read_text(encoding="utf-8")


def sentences_path(lang: str) -> Path:
    return ROOT / "LearnLanguageLikeABaby" / "Resources" / f"sentences_{lang}.json"


def load_sentences(lang: str) -> list:
    path = sentences_path(lang)
    if not path.is_file():
        print(f"错误：找不到 {path}", file=sys.stderr)
        sys.exit(1)
    with path.open(encoding="utf-8") as f:
        data = json.load(f)
    return data.get("sentences", [])


def save_sentences(lang: str, sentences: list) -> Path:
    """写回句库，严格保持 {\"sentences\": [...]} 外层结构。返回实际写入的路径（绝对路径）。"""
    path = sentences_path(lang)
    resolved = path.resolve()
    payload = {"sentences": sentences}
    text = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    print(f"已写回 {len(sentences)} 句到 {resolved}")
    return resolved


def _parse_json_completion(content: str):
    content = content.replace("```json", "").replace("```", "").strip()
    return json.loads(content)


# --- Action 1: 生成新内容 ---
def action_generate(lang: str, level: str, count: int) -> None:
    from openai import OpenAI

    _require_api_key()
    client = OpenAI(api_key=os.environ.get("OPENAI_API_KEY"))
    standard = load_standard()
    level_slug = level.lower()
    timestamp = int(time.time())
    id_example = f"{lang}_{level_slug}_{timestamp}_001"
    prompt = f"""
你是一个语言教学内容生成器，严格遵循以下标准：

{standard}

请生成{count}条{lang}语言{level}级别的学习内容。

要求：
- 严格按照标准里的格式规范
- library字段填"{level}"
- id格式：{lang}_{level_slug}_{timestamp}_001开始递增（本次批次必须使用此前缀，依次 002、003…）
- 只输出JSON数组，不要任何其他文字

JSON格式：
[
  {{
    "id": "{id_example}",
    "text": "...",
    "ipa": "...",
    "translation": "...",
    "library": "{level}",
    "tokens": [
      {{
        "text": "...",
        "lemma": "...",
        "hasImage": true/false,
        "emoji": "...",
        "ipa": "...",
        "translation": "..."
      }}
    ]
  }}
]
"""
    out_path = sentences_path(lang).resolve()
    print(f"[generate] ROOT = {ROOT.resolve()}")
    print(f"[generate] 目标句库文件 = {out_path}")
    print(f"[generate] 本批 id 时间戳前缀 = {lang}_{level_slug}_{timestamp}_（001…递增）")

    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.7,
    )
    content = (response.choices[0].message.content or "").strip()
    print(f"[generate] 模型返回: 长度 {len(content)} 字符")
    if not content:
        print("错误：模型返回内容为空，未写入文件", file=sys.stderr)
        sys.exit(1)

    # 控制台预览（便于确认 GPT 是否真的返回了 JSON）
    preview_len = 2000
    print(f"[generate] 返回内容预览（前 {min(preview_len, len(content))} 字符）：")
    print(content[:preview_len] + ("…" if len(content) > preview_len else ""))
    print("[generate] --- 预览结束 ---")

    try:
        new_sentences = _parse_json_completion(content)
    except json.JSONDecodeError as e:
        print(f"错误：JSON 解析失败: {e}", file=sys.stderr)
        sys.exit(1)

    if not isinstance(new_sentences, list):
        print("错误：模型返回的不是 JSON 数组", file=sys.stderr)
        sys.exit(1)

    print(f"[generate] 解析得到 {len(new_sentences)} 条（模型侧条数）")

    existing = load_sentences(lang)
    existing_texts = {(s.get("text") or "").strip() for s in existing if (s.get("text") or "").strip()}
    added = [s for s in new_sentences if (s.get("text") or "").strip() not in existing_texts]
    skipped = [s for s in new_sentences if (s.get("text") or "").strip() in existing_texts]

    written = save_sentences(lang, existing + added)
    print(f"[generate] 写入确认: {written} （exists={written.is_file()}, size={written.stat().st_size} bytes）")

    print(f"[generate] 库中原有 {len(existing)} 句；本次新增 {len(added)} 句；因正文与库中重复跳过 {len(skipped)} 句")
    if skipped:
        preview = [(s.get("id"), (s.get("text") or "")[:60]) for s in skipped[:15]]
        print(f"[generate] 跳过示例 (id, text前60字): {preview}{'…' if len(skipped) > 15 else ''}")

    # 打印本次实际合并进库的新条目 JSON（用户核对质量）
    if added:
        print("[generate] 本次新增条目的 JSON：")
        print(json.dumps(added, ensure_ascii=False, indent=2))


# --- Action 2: 分类现有内容 ---
def action_classify(lang: str) -> None:
    from openai import OpenAI

    _require_api_key()
    client = OpenAI(api_key=os.environ.get("OPENAI_API_KEY"))
    standard = load_standard()
    sentences = load_sentences(lang)
    batch_size = 20

    for i in range(0, len(sentences), batch_size):
        batch = sentences[i : i + batch_size]
        texts = [{"id": s["id"], "text": s["text"]} for s in batch]

        prompt = f"""
根据CEFR标准，给以下句子分类到正确的级别（A1/A2/B1/B2）。

标准参考：
{standard}

句子列表：
{json.dumps(texts, ensure_ascii=False)}

只输出JSON，格式：
[{{"id": "...", "library": "A1"}}, ...]
"""
        response = client.chat.completions.create(
            model="gpt-4o",
            messages=[{"role": "user", "content": prompt}],
            temperature=0,
        )
        content = response.choices[0].message.content or ""
        classifications = _parse_json_completion(content)
        if not isinstance(classifications, list):
            print("错误：分类结果不是 JSON 数组", file=sys.stderr)
            sys.exit(1)

        class_map = {c["id"]: c["library"] for c in classifications if "id" in c and "library" in c}
        for s in sentences:
            if s["id"] in class_map:
                s["library"] = class_map[s["id"]]

        print(f"已分类 {min(i + batch_size, len(sentences))}/{len(sentences)} 句")

    save_sentences(lang, sentences)


# --- Action 3: 清理不合格内容 ---
def action_clean(lang: str) -> None:
    sentences = load_sentences(lang)
    before = len(sentences)

    bad_patterns = ["Je note «", "Tu entends «", "C'est écrit", "Réponse courte"]

    cleaned = []
    for s in sentences:
        if any(p in s.get("text", "") for p in bad_patterns):
            continue
        if not s.get("text", "").strip():
            continue
        if len(s.get("tokens", [])) > 5:
            print(f"警告：词块过多 [{s['id']}] {s['text']}")
            # 仍保留；仅警告（与说明「只删除明确不合格」一致）
        cleaned.append(s)

    save_sentences(lang, cleaned)
    print(f"清理完成：{before} → {len(cleaned)}，删除 {before - len(cleaned)} 句")


# --- Action 4: 验证格式 ---
def action_validate(lang: str) -> None:
    sentences = load_sentences(lang)
    errors: list[str] = []

    for s in sentences:
        sid = s.get("id", "?")
        if not s.get("ipa"):
            errors.append(f"[{sid}] 缺少IPA")
        if not s.get("translation"):
            errors.append(f"[{sid}] 缺少翻译")
        if not s.get("library"):
            errors.append(f"[{sid}] 缺少library字段")
        tokens = s.get("tokens", [])
        if len(tokens) > 5:
            errors.append(f"[{sid}] 词块数{len(tokens)}超过5")
        if len(tokens) < 1:
            errors.append(f"[{sid}] 没有词块")
        for t in tokens:
            if t.get("lemma") in ["-", "", None]:
                errors.append(f"[{sid}] 词块lemma无效：{t.get('text')}")

    if errors:
        print(f"发现 {len(errors)} 个问题：")
        for e in errors:
            print(" ", e)
    else:
        print(f"验证通过，共 {len(sentences)} 句，格式无误")


def main() -> None:
    parser = argparse.ArgumentParser(description="LLLB Library Generator")
    parser.add_argument(
        "--action",
        choices=["generate", "classify", "clean", "validate"],
        required=True,
    )
    parser.add_argument("--lang", default="fr")
    parser.add_argument("--level", default="A1")
    parser.add_argument("--count", type=int, default=50)
    args = parser.parse_args()

    if args.action == "generate":
        action_generate(args.lang, args.level, args.count)
    elif args.action == "classify":
        action_classify(args.lang)
    elif args.action == "clean":
        action_clean(args.lang)
    elif args.action == "validate":
        action_validate(args.lang)


if __name__ == "__main__":
    main()
