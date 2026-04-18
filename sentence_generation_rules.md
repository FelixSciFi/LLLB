---
name: Sentence generation rules
description: Rules for generating new sentences for the LLLB app sentence JSON files
type: reference
---

# LLLB 造句规则

## 概述

每种语言对应一个 `sentences_{lang}.json`，新句子加进 `sentences` 数组。每句话围绕一个**目标词（target lemma）**，即当前正在教/卖的词，但句子里也可以包含其他实词。

---

## 1. 每个 lemma 造几句

- 标准是每个 lemma **2句**。
- 两句结构要有变化：一句简单陈述，一句有动作或场景。

### 1b. 提示类型优先（覆盖 §1 的默认「2 句」）

造几条、每条长什么样，**先看用户怎么描述**，不要套用固定套路。

| 提示类型 | 典型输入 | 条数 | 表面形式 |
|----------|----------|------|----------|
| **列举型** | 只列若干词/物/主题（顿号、逗号、`+` 连接），**没有**情节、场景、对话说明 | **默认 = 列举项数**，每项 **1 条**，除非用户写了「N 句」或明确要复数条 | 允许 **名词短语、标签式 utterance**（如 `Une batterie externe.`）；**不强制** 补成叙事句（不必硬加「J'ai…」「Je vais…」） |
| **场景型** | 描述了情景、流程、场合、对话 | 以用户写的 **N 句** 为准；若完全没写条数，在预览里说明拟定条数或 **先问再写** | 仍要短、口语；可按 §1 给同一 lemma 多条，但**不得**为凑数编造用户没说的细节 |

**列举型硬约束（防「脑补剧情」）**

- **禁止** 自动「每个词来两句」或固定默认 6 条等，除非用户明确要。
- **禁止** 添加用户**未提及**的目的、地点、时间、因果链（例如未说洗手就不要写洗手，未说上班就不要写 travail）。
- **最短表意优先**：用户只给概念时，`text` 取 **能单独站得住的法语表意单位** 即可；不要为了「像课本完整句」而加长。

---

## 2. 句子质量

- 短、自然、日常用语，A1–A2 水平。
- 不要用复杂语法，像小孩或初学者能懂的程度。
- 目标词必须自然出现在句子里。
- 主语要多样，不要全用"Je"，可以用 Elle / Il / On 等。

---

## 3. Token 切分规则

每句话切成若干 **token**（短语级别的块）。

### 3a. 按短语切分
- 功能词靠近实词，合并成一个 token。
- 常见的切法：`[冠词 + 名词]`、`[介词 + 冠词 + 名词]`、`[主语代词 + 动词]`、`[动词 + 宾语]`。
- 每句话目标 2–4 个 token。

### 3b. 每个含实词的 token 都要有 lemma
- **只要 token 里有实词，就必须填 lemma**——填该实词的原形（动词填不定式，名词/形容词填单数形式）。
- 只有**纯功能词组**（如 `s'il te plaît`、`est-ce que`、单独的 `est`）才填 `null`。
- 不能因为这个词不在 word table 里就写 null。

### 3b-lemma. Lemma 只能是单个词（强制）
- **`lemma` 字符串里不得含空格**：禁止 `batterie externe`、`eau oxygénée`、`deux mille` 这类**多词 lemma**；连写复合词若法语词典作一词（如部分带连字符的写法）可保留为一词，否则仍按「一个词」处理。
- **固定搭配 / 数字读法 / 不便拆的 token**：若按 §3c 不拆或整段包在一个 token 里，**lemma 从该 token 中的实词里任选一个**填原形即可；**不要**为「忠实于搭配」而写多词 lemma。
- **难以权衡时**：任选其中一个实词的 lemma，**无需**声明理由或与中文单一译词严格对齐。

### 3c. 一个 token 里有两个实词怎么办
- **默认**：拆开，每个实词单独成一个 token；每个 token 的 lemma 对应该实词（单个词）。
- **例外**：若按 §1b「列举型」或固定搭配需要**整条短语保持一个 token**（避免 token 释义与整句译文错位），则 **lemma 仍只填一个词**（见 §3b-lemma），不要写多词 lemma。

### 3d. 目标词的 token
- 包含目标词的 token，lemma 填目标词的原形。
- 其他 token 填各自主要实词的原形。

---

## 4. Lemma 与 word table 的关系

### 两套系统完全独立：
1. **word_table_{lang}.json** — 可以购买的词。句子进入播放池的条件：用户拥有该句任意一个 token 的 lemma。
2. **sentences 里的 token lemma** — 用于聚焦模式跨句联动。`focusOnToken()` 直接在全部句子里按 lemma 字符串匹配，与 word table 无关。

### 写句子时不需要操心 word table：
- word table（法语）已覆盖 A1–A2 日常词汇（1000+ 词），写句子时**不需要检查、不需要修改** word table。
- 直接把 token 的 lemma 填准确就行。
- 某个词不在 word table 里：点击仍然正常聚焦，只是用户无法在商店里购买它——**功能零影响**。
- 举例：句子里出现「双氧水」（如 `eau oxygénée`），token 的 `lemma` 只填一个词（如 `eau` 或 `oxygénée` 任选其一），不在 word table 也完全没问题。

### 什么时候才需要动 word table：
- 给新语言做初始词库时。
- 决定把某个生僻词正式纳入售卖体系时。
- 日常写句子：**完全不需要。**

---

## 5. IPA 规则

### 句子级别（顶层 `ipa` 字段）
- 对应**完整句子**，包括跨 token 的连音（liaison）。
- 连音明确发生时要写出来（如 `très intéressant` = `tʁɛz ɛ̃teʁesɑ̃`）。
- 使用标准法语 IPA 符号：ʁ ɛ œ ɑ̃ ɔ̃ ɛ̃ ʃ ʒ ɥ 等。
- 不能省略或近似，必须完整准确。
- h aspiré 不连音（如 `beaux habits` = `bo abi`，不是 `bo zabi`）。

### Token 级别（每个 token 的 `ipa` 字段）
- 对应**该 token 文字本身**的发音。
- 包含 token 内部的连音，但不需要考虑跨 token 的连音。
- **不能留空**，每个 token 都必须填写。
- 例：token `"Elle passe"` → `"ɛl pɑs"`；token `"à la caisse"` → `"a la kɛs"`

---

## 6. 翻译

### 句子级别（顶层 `translation` 字段）
- **`zh`**：自然的中文表达，不要直译，要读起来像中文。
- **`en`**：自然的英文表达。
- 翻译整句意思。

### Token 级别（每个 token 的 `translation` 字段）
- **`zh`** 和 **`en`** 都要填，对应该 token 在上下文中的意思。
- 保持简短，是标签而非完整句子。
- **不能留空**，每个 token 都必须填写。
- 例：token `"Elle passe"` → zh: `"她走过"`, en: `"she goes"`
- 例：token `"à la caisse"` → zh: `"去收银台"`, en: `"to the checkout"`

---

## 7. Emoji

- 包含**目标词**的 token 要配一个合适的 emoji。
- 其他 token 如果表达动作/情绪也可以加，但不要堆砌。
- 找不到合适的 emoji 就留空 `""`。
- Emoji 要和词义在视觉/语义上匹配。

---

## 8. CEFR 等级

- `"A1"`：结构简单、词汇基础的句子。
- `"A2"`：结构稍复杂或词汇稍难的句子。

---

## 9. ID

> **rank 字段已废弃**，新句子不要写。解锁逻辑完全由 token lemma 匹配决定。

- 每句话生成一个新的 UUID（Python 用 `uuid.uuid4()`，或任意 UUID v4 生成器）。
- 整个文件里 ID 不能重复。

---

## 11. JSON 结构参考

```json
{
  "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "text": "La chaise est confortable.",
  "ipa": "la ʃɛz ɛ kɔ̃fɔʁtabl",
  "translation": {
    "zh": "这把椅子很舒适。",
    "en": "The chair is comfortable."
  },
  "cefr": "A1",
  "tokens": [
    { "text": "La chaise", "lemma": "chaise", "ipa": "", "translation": {"zh": "", "en": ""}, "emoji": "🪑" },
    { "text": "est confortable", "lemma": "confortable", "ipa": "", "translation": {"zh": "", "en": ""}, "emoji": "" }
  ]
}
```

---

## 12. 操作流程

1. 每个场景/lemma 写 2 句。
3. 每句切成 2–4 个 token。
4. 每个含实词的 token 填 lemma（原形）——不管该词在不在 word table。
5. 写准确的完整句子 IPA。
6. 写自然的中文和英文翻译。
7. **先展示给用户确认，用户确认后再写入 JSON。**
8. 写入后验证句子总数和缺失字段。
