"""
LLLB Sentence Tool — paste LLM JSON, validate, inject UUIDs + tags, write.
Usage: ./scripts/run_sentence_tool.sh
"""

import json
import uuid
import streamlit as st

TARGET_FILE = "/Users/xieyu/projects/LLLB/LearnLanguageLikeABaby/Resources/sentences_fr.json"

# ---------------------------------------------------------------------------
# LLM prompt template
# ---------------------------------------------------------------------------
LLM_PROMPT = """\
你是一个法语语言学习 app 的内容生成器。我给你一些词/短语（中文、英文或法语均可），请帮我生成对应的法语学习句子，输出 JSON 数组。

规则：
- 如果某条能自然地对应一句常见法语 → 生成
- 如果在法语里不自然或没有对应说法 → 跳过，不输出，不解释
- 每条输入最多生成一句法语
- 严禁引申造句
- 数字必须拼写出来，不能用阿拉伯数字

每句的 JSON 结构如下（不要输出 id 和 tags 字段）：
{{
  "text": "完整法语句子",
  "ipa": "整句 IPA（法语，不带重音符号 ˈˌ）",
  "translation": {{"zh": "自然中文翻译", "en": "natural English translation"}},
  "cefr": "A1 / A2 / B1 / B2 / C1 / C2",
  "tokens": [
    {{
      "text": "token 文本",
      "lemma": "词根原形（动词→不定式，名词/形容词→单数原形）",
      "ipa": "该 token 的 IPA",
      "translation": {{"zh": "2-6字中文标签", "en": "1-4 word English label"}},
      "emoji": "一个 emoji（有直观指代则给，否则空字符串）"
    }}
  ]
}}

Lemma 规则：除固定用法外，尽量选一个相对重要的词根原型而不是多个词

Token 切分规则：
- 实词（名词、动词、形容词、副词）单独一个 token
- 虚词（冠词、介词、连词、助动词、否定词 ne/pas）附在相邻实词上
- et 合并到后面的词
- Tu/Je/Il 等主语代词与后面动词合并
- C'est 与后面就近合并
- être 与后面合并
  示例：「à la caisse(caisse)」「ne mange pas(manger)」「je mange(manger)」

输出：只输出 JSON 数组，不要解释，不要 markdown 代码块。

我的输入：
{user_input}
"""

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
REQUIRED_SENTENCE = {"text", "ipa", "translation", "cefr", "tokens"}
REQUIRED_TOKEN    = {"text", "lemma", "ipa", "translation", "emoji"}

def validate_sentences(data) -> list[str]:
    errors = []
    if not isinstance(data, list):
        return ["顶层必须是 JSON 数组"]
    for i, s in enumerate(data):
        prefix = f"第 {i+1} 句"
        missing = REQUIRED_SENTENCE - set(s.keys())
        if missing:
            errors.append(f"{prefix} 缺少字段：{missing}")
            continue
        if not isinstance(s.get("tokens"), list) or len(s["tokens"]) == 0:
            errors.append(f"{prefix} tokens 为空或不是数组")
            continue
        for j, t in enumerate(s["tokens"]):
            tmissing = REQUIRED_TOKEN - set(t.keys())
            if tmissing:
                errors.append(f"{prefix} token {j+1} 缺少字段：{tmissing}")
        # Validate tags if present
        for j, tag in enumerate(s.get("tags", [])):
            if "name" not in tag:
                errors.append(f"{prefix} tag {j+1} 缺少 name 字段")
    return errors

def strip_markdown_fence(text: str) -> str:
    """Remove ```json ... ``` or ``` ... ``` wrappers that LLMs often add."""
    t = text.strip()
    if t.startswith("```"):
        t = t.lstrip("`")
        if t.startswith("json"):
            t = t[4:]
        t = t.strip().rstrip("`").strip()
    return t

def inject_tags(data: list, tag_name: str, tag_type: str):
    """Inject tag into each sentence. Ordered type assigns sequential index."""
    name = tag_name.strip()
    for i, s in enumerate(data):
        existing = [t for t in s.get("tags", []) if t.get("name") != name]
        entry = {"name": name}
        if tag_type == "内容标签（有序）":
            entry["index"] = i + 1
        existing.append(entry)
        s["tags"] = existing

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
st.set_page_config(page_title="LLLB Sentence Tool", layout="wide", page_icon="🇫🇷")
st.title("🇫🇷 LLLB Sentence Tool")

# Flash message (shown after rerun following a successful write/delete)
if "flash" in st.session_state:
    ftype, fmsg = st.session_state.pop("flash")
    (st.success if ftype == "ok" else st.warning)(fmsg)

# Widget-clear counters — incrementing forces Streamlit to create a fresh widget
if "paste_gen" not in st.session_state:
    st.session_state["paste_gen"] = 0
if "delete_gen" not in st.session_state:
    st.session_state["delete_gen"] = 0

with st.sidebar:
    st.header("⚙️")
    with st.expander("启动前提", expanded=False):
        st.markdown("**启动工具**（项目目录）")
        st.code("cd /Users/xieyu/projects/LLLB\n./scripts/run_sentence_tool.sh", language="bash")
        st.markdown("**写入后需重新编译 Xcode**")
        st.code("Product → Run  (⌘R)", language=None)
    st.markdown("---")
    with st.expander("📋 LLM 提示词", expanded=False):
        raw_input = st.text_area(
            "你的输入（每行一条，中/英/法均可）：",
            height=120,
            placeholder="去超市\n买苹果\npayer par carte",
            key="raw_input",
        )
        filled = LLM_PROMPT.format(
            user_input=raw_input.strip() or "[在这里粘贴你的内容，每行一条]"
        )
        st.text_area("复制给 LLM：", value=filled, height=500, key="prompt_out")
    st.caption(f"写入：`sentences_fr.json`")

# --- 粘贴区 ---
st.subheader("粘贴 LLM 返回的 JSON")
pasted = st.text_area(
    "json_paste",
    height=380,
    placeholder='[\n  {\n    "text": "je mange une pomme",\n    ...\n  }\n]',
    label_visibility="collapsed",
    key=f"json_paste_{st.session_state['paste_gen']}",
)

# --- 标签设置 ---
st.subheader("标签设置（可选）")
add_tag = st.checkbox("为这批句子添加标签")
tag_name = ""
tag_type = "内容标签（有序）"
override_cefr = ""
if add_tag:
    col_name, col_type = st.columns([2, 1])
    with col_name:
        tag_name = st.text_input("标签名", placeholder="例：Frère Jacques")
    with col_type:
        tag_type = st.radio(
            "类型",
            ["内容标签（有序）", "随机标签"],
            horizontal=True,
        )
    if tag_type == "内容标签（有序）":
        col_cefr, col_hint = st.columns([1, 3])
        with col_cefr:
            override_cefr = st.selectbox("统一 CEFR（必选）", ["A1", "A2", "B1", "B2", "C1", "C2"], index=0)
        with col_hint:
            if tag_name.strip():
                st.caption(f"句子将按数组顺序依次分配 index 1, 2, 3 …，全部设为 {override_cefr}")
    elif tag_name.strip() and tag_type == "随机标签":
        st.caption("每句添加随机标签（无 index）")

st.markdown("---")
col_validate, col_write = st.columns(2)

with col_validate:
    if st.button("验证", use_container_width=True):
        if not pasted.strip():
            st.error("内容为空")
        else:
            try:
                data = json.loads(strip_markdown_fence(pasted))
                errs = validate_sentences(data)
                if errs:
                    for e in errs:
                        st.error(e)
                else:
                    tag_info = f"，标签「{tag_name.strip()}」({tag_type})" if add_tag and tag_name.strip() else ""
                    st.success(f"✅ 结构正确，共 {len(data)} 句{tag_info}")
            except json.JSONDecodeError as e:
                st.error(f"JSON 解析失败：{e}")

with col_write:
    if st.button("写入文件", type="primary", use_container_width=True):
        if not pasted.strip():
            st.error("内容为空")
            st.stop()
        try:
            data = json.loads(strip_markdown_fence(pasted))
        except json.JSONDecodeError as e:
            st.error(f"JSON 解析失败：{e}")
            st.stop()

        errs = validate_sentences(data)
        if errs:
            for e in errs:
                st.error(e)
            st.stop()

        if add_tag and tag_name.strip():
            inject_tags(data, tag_name, tag_type)

        # Override CEFR if specified
        if override_cefr:
            for s in data:
                s["cefr"] = override_cefr

        # Inject UUIDs (skip if already present)
        for s in data:
            if not s.get("id"):
                s["id"] = str(uuid.uuid4())

        try:
            with open(TARGET_FILE, "r") as f:
                existing = json.load(f)
            existing["sentences"].extend(data)
            with open(TARGET_FILE, "w") as f:
                json.dump(existing, f, ensure_ascii=False, indent=2)
            total = len(existing["sentences"])
            tag_info = f"，标签「{tag_name.strip()}」({tag_type})" if add_tag and tag_name.strip() else ""
            st.session_state["flash"] = ("ok", f"✅ 已写入 {len(data)} 句{tag_info}，共 {total} 句")
            st.session_state["paste_gen"] += 1
            st.rerun()
        except Exception as e:
            st.error(f"写入失败：{e}")

st.markdown("---")
st.subheader("删除句子")
delete_input = st.text_area(
    "delete_uuids",
    height=120,
    placeholder='直接粘贴 JSON 片段或纯 UUID 均可\n"id": "e2a8e464-9c16-4ed1-966f-670f00b15028"\nab12cd34-...',
    label_visibility="collapsed",
    key=f"delete_uuids_{st.session_state['delete_gen']}",
)

if st.button("删除", type="secondary", use_container_width=True):
    import re as _re
    to_delete = set(_re.findall(
        r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
        delete_input, _re.IGNORECASE
    ))
    if not to_delete:
        st.error("请输入至少一个 UUID")
    else:
        try:
            with open(TARGET_FILE, "r") as f:
                existing = json.load(f)
            original_ids = {s.get("id") for s in existing["sentences"]}
            existing["sentences"] = [s for s in existing["sentences"] if s.get("id") not in to_delete]
            removed = len(original_ids & to_delete)
            not_found = len(to_delete - original_ids)
            after = len(existing["sentences"])
            with open(TARGET_FILE, "w") as f:
                json.dump(existing, f, ensure_ascii=False, indent=2)
            if removed == 0:
                st.warning(f"未找到任何匹配的 UUID（共输入 {len(to_delete)} 个）")
            else:
                msg = f"✅ 已删除 {removed} 句，剩余 {after} 句"
                if not_found:
                    msg += f"（{not_found} 个 UUID 未找到）"
                st.session_state["flash"] = ("ok", msg)
                st.session_state["delete_gen"] += 1
                st.rerun()
        except Exception as e:
            st.error(f"删除失败：{e}")

# Keep-alive
import streamlit.components.v1 as components
components.html("<script>setInterval(function(){}, 600000);</script>", height=0)
