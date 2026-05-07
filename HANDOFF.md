# LLLB 三语内容工作交接（2026-05-07）

> 给下一个 session：所有内容进度、规则文件、临时产物的位置。

---

## 1. 三语句库现状

| 语言 | 总句数 | 等级分布 | 内容标签组 |
|---|---|---|---|
| **EN** | 2981 | A1: 860 / A2: 784 / B1: 681 / B2: 600 / C1: 24 / C2: 32 | 11 组 / 56 句 |
| **FR** | 5308 | A1: 1264 / A2: 965 / B1: 1423 / B2: 1539 / C1: 64 / C2: 53 | 35 组 / 239 句 |
| **ZH** | 6303 | HSK1: 692 / HSK2: 410 / HSK3: 851 / HSK4: 526 / HSK5: 1288 / HSK6: 2536 | 10 组 / 51 句 |

**主源文件：** `LearnLanguageLikeABaby/Resources/sentences_{en|fr|zh}.json`

---

## 2. 已完成的关键工作

### 内容生成
- ✅ **法语 FLELex top 5000 短语化**（A1-B2 主体，~3848 词通过 sonnet subagent 生成短语+IPA+翻译+token 切分）
- ✅ **法语 C1/C2 高阶内容组 20 组**（Voltaire/Hugo/Maupassant/Zola/Balzac/Daudet/Apollinaire/France/Verne/Sand + Baudelaire/Rimbaud/Proust/Flaubert/Verlaine/Stendhal/Mallarmé/Molière/Chateaubriand/Hugo Demain）
- ✅ **中文 HSK3 enrichment**（566 句补 ipa/translation/emoji）
- ✅ **中文 10 组高阶内容**（鲁迅故乡/朱自清背影/老舍骆驼祥子/鲁迅狂人日记/徐志摩再别康桥/戴望舒雨巷/余光中乡愁→已删/钱钟书围城→已删/张爱玲金锁记→已删/沈从文边城→已删 + 郁达夫故都的秋/萧红呼兰河传/闻一多死水/许地山落花生）—— 4 组因版权移除
- ✅ **英语 11 组高阶内容**（Orwell/Austen/Thoreau/Douglass/Emerson + Hamlet/Dickens/Lincoln/Woolf/Frost/Darwin）—— MLK/Russell/Sagan 因版权移除
- ✅ **英语 Oxford 3000 整体短语化（2914 词全部）**：50% 转成多词短语，50% subagent 判定保持单词更自然（数字、虚词、独立词）

### App 行为修复（最近）
- ✅ Language picker：母语/学习语言互相不可选时显示但灰掉（不再隐藏）
- ✅ UnlockPickerView 候选弹窗：单句和组卡片样式分开；组卡片显示前 3 句预览 + "展开余下 N 句"
- ✅ MyAssetsView "X sentences total" 显示真实 `pool.count`（不被 CEFR 过滤影响）
- ✅ Pool / Mastered / Later 按加入顺序倒叙显示（最新在最上）

### 用户上次提到的两个 bug
- **Bug 1（误报）**：archive 后 4 选 2 池子涨太多。**实际是设计正确**——挑组卡片就是整组进，下次 archive 重新算 deficit。用户确认。
- **Bug 2（待复现）**：cap 150→130 时看到池子掉到 130。代码里**没有任何路径**会因 cap 减小而截断 pool。诊断：很可能是 ProfileView 的 "X sentences total" 显示的是 filteredPool（被 CEFR 库过滤后），用户改 CEFR 库勾选导致。已修复显示问题（commit `f426e9f`）。如果用户重测还掉，需要进一步查（可能是 iCloud 同步竞争或我漏了路径）。

---

## 3. 规则 / 流水线文档（memory 文件）

路径：`/Users/xieyu/.claude/projects/-Users-xieyu-projects-LLLB/memory/`

| 文件 | 内容 |
|---|---|
| **MEMORY.md** | 索引文件，所有 memory 列表 |
| **sentence_corpus_status.md** | **三语库实时概况** — 等级分布、内容组清单、薄弱处、文件路径。**补内容前先看这个**。 |
| **c1_c2_content_groups.md** | 高阶内容组流水线：选材→opus 并行造→apply。aggressive token 合并规则。 |
| **sentence_generation_rules.md** | 法语 token 切分规则：être/c'est/主语代词/et/数词全部合并到实词。覆盖 SKILL.md 旧版。 |
| **sentence_review_pipeline.md** | extract_split.py + apply_batch.py + reviewed_ids.json sidecar；1188/1341 法语已审核 |
| **project_architecture.md** | 文件角色、咖啡杯模型、AppModel 转发规则、iCloud KVS 同步、连击/里程碑规则、MyAssets 缓存、句子池 |
| **project_backlog.md** | 延后的功能和讨论话题 |
| **project_lllb_use_pattern.md** | 用户自己当播客听（锁屏+CarPlay），3天/句 learning curve，规划录屏 + 少量投放 |
| **feedback_discuss_before_implementing.md** | 非trivial UI/layout 改动先讨论方案 + tradeoffs，不要直接动手 |
| **feedback_honest_professional_opinion.md** | 用户要直率批评，不要迎合 |
| **feedback_pro_only_unlimited_time.md** | Pro 唯一差异 = 无限时间，paywall 文案不要捏造其他特性 |
| **feedback_lllb_immersion_focus.md** | 不要推打断 TTS 流的功能（跟读评分/录音对比/输出测试都已被砍） |
| **feedback_worktree_session_sync.md** | worktree 完成后主动 commit + ff-only merge |
| **brand_color_rule.md** | 4 ring colors 只在 logo/progress rings/achievement cards 用 |
| **logo_design_spec.md** | Ring 几何比例、hex 颜色、Raleway Bold |
| **user_display_settings.md** | 用户用大号 Dynamic Type，别硬编码字号 |

---

## 4. 临时产物 / 流水线产物

`tools/` 目录（**不进 git**，工作时产生）：

| 路径 | 内容 |
|---|---|
| `tools/en_phrases/` | 英语短语化流水线：to_generate.json + shards/000-097（input + output 各 98 个） |
| `tools/fr_words/` | 法语 FLELex 流水线：to_generate.json + shards/000-128 |
| `tools/fr_groups/` | 法语高阶内容组的 21 个 JSON 输出（Voltaire/Hugo/...） |
| `tools/en_groups/` | 英语高阶内容组的 11 个 JSON 输出（Orwell/Austen/...） |
| `tools/zh_groups/` | 中文高阶内容组的 14 个 JSON 输出（含已删的 4 组） |
| `tools/hsk3_enrich/` | 中文 HSK3 enrichment 流水线（29 shard） |
| `tools/zh_hsk4_shard_*` | 中文 HSK4 词的 shard 文件 |
| `tools/reviewed_ids.json` | 法语审核 sidecar（不在 app tags 里） |
| `tools/extract_split.py` | 抽 N 句拆 K shard |
| `tools/apply_batch.py` | 应用 batch decisions |

**清理建议：** `tools/` 当前包含历史所有 batch 的产物，可以保留作 reference，也可以归档到别处释放空间。

---

## 5. 待办 / 薄弱处

按优先级排（参考 `sentence_corpus_status.md`）：

### 出货向（推荐先做）
1. **录屏 demo + App Store 截图**（用 iOS 自带录屏即可；注意 App Store Preview 规格）
2. **TestFlight 上架** —— 内容已经够了

### 内容向（如果继续做）
3. **英语日常情景组 ~10 组**（法语有 15 组，英语 0 组）。沿用 c1_c2_content_groups.md 流水线。题材建议：At the supermarket / Job interview / Doctor visit / Ordering coffee / Travel / 等
4. **中文 HSK2 补 200-300 句**（HSK2 410 句明显比相邻级别少）。HSK3 enrichment 流水线直接套用
5. **法语短情景组扩展**（La Parure 5 句、le mariage 5 句等可补到 ~12 句）

### 不需要做（边际效用低）
- 三语 C1/C2 / HSK6 高阶不再追量（11/20/10 组已足够"小奖励"密度）
- 法语 A1-B2 已饱满（FLELex top 5000 跑完）
- 中文 HSK6 已 2536 句，远超用户实际能消化

---

## 6. 关键代码点

| 文件 | 主要职责 |
|---|---|
| `LessonSessionModel.swift` | 句子池、archive 流、unlock 候选选择、tag 组展开。pool 是 `[String]`（有序），masteredIDs/laterIDs 是 Set + 影子 order array |
| `Models/SentenceModels.swift` | `LessonSentence` / `TokenChunk` 结构。注意 `emoji` 是非 optional（null 会崩） |
| `Services/SentenceLibrary.swift` | JSON 加载，期望 `{"sentences": [...]}` 格式（不是裸数组！踩过坑） |
| `Services/PoolUnlockSelector.swift` | distribution-aware 候选选择 |
| `LanguageConfig.swift` | 学习语言 + UI 语言配置 |
| `ContentView.swift` | 主播放界面 + UnlockPickerView 候选弹窗 + 候选卡片 |
| `ProfileView.swift` | Settings + MyAssetsView（pool/mastered/later 列表）+ LanguagePickerView |

---

## 7. 关键约定 / 容易踩坑

1. **`sentences_*.json` 必须是 `{"sentences": [...]}` 格式**（不是裸数组）。曾因为 apply 脚本写成裸数组让 app 加载失败
2. **`TokenChunk.emoji` 非 optional**，null 会崩。所有 apply 脚本里 `entry.get("emoji") or ""` 兜底
3. **带 tag 的句子在 app 里被池隔离**，只能通过 archive→tryUnlockAfterArchive 路径进池
4. **法语 IPA 用 `ʁ`（不是 r）和 `ɡ`（不是 g）**，无重音符号
5. **中文 token "他/她/我"等代词应合并到动词**（"我看见"、"他穿着..."）
6. **古文不用**，跟现代汉语两套系统
7. **subagent 有时输出 emoji=null**，apply 时务必兜底；shard 输出经常违反 token 规则（过度切分），review 时关注

---

## 8. Sentence pool 关键不变量（用户确认过的设计）

- 每次 archive 触发一次 deficit 检查（`poolCapacity - pool.count`）
- deficit ≤ 0 → 不弹窗
- deficit = 1 → 2 选 1
- deficit ≥ 2 → 4 选 2
- 候选可包含内容标签组的句子；用户挑组卡片，整组进池（可能溢出 cap，下次 archive 自然不再触发）
- **没有任何代码会因 cap 减小而截断 pool**（已确认）

---

下一个 session 开始时直接看这个文件 + `sentence_corpus_status.md`，能 30 秒内进入状态。
