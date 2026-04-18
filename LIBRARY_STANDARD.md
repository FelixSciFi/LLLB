# LLLB Library Standard

## 定位

本词库基于CEFR（欧洲语言共同参考框架）分级体系，词汇来源遵循各语言官方参考词表：
- 法语：Français Fondamental（法国教育部）
- 西班牙语：Plan Curricular del Instituto Cervantes（塞万提斯学院）

## 核心原则

词库是词汇驱动的，不是场景驱动的。

先确定当前级别的核心词，再围绕这些词生成内容。内容形式不限——单词、词组、短句均可，不要求完整句子。判断标准只有一个：真实的人类会在真实场景里用到它吗？

---

## 内容规范

### 允许的内容形式
- 单独的词：`rouge`、`chaud`、`trois`
- 词组：`un sac rouge`、`très bien`、`s'il vous plaît`
- 短句：`J'ai faim`、`Où est la gare ?`、`C'est combien ?`
- 常用表达：`Bonne journée`、`Pas de problème`

### 内容质量优先级
- **优先**：有具体信息量的——`une pomme rouge`（颜色+名词）、`J'ai faim`（真实状态）、`C'est combien ?`（真实问句）
- **可以有，但降频**：纯评价性的——`La pomme est bonne`、`C'est beau`
- **禁止**：模板句、元语言句、超纲词汇、为凑句子加入的冗余成分

### 禁止内容
- 模板句：`Je note « X »`、`Tu entends « X » ?`、`C'est écrit : X`、`Réponse courte : X`
- 元语言句：任何描述"学习这个词"本身的句子
- 超纲词汇：当前级别词表以外的词不应作为核心词出现
- 强行凑句：为了造完整句子而加入的冗余成分

### 词汇比例建议
- 名词占比最高，尤其具体可视化的名词，占比不低于40%
- 基础动词次之
- 形容词和副词穿插
- 功能词（连词、介词）不单独作为核心词，附属出现

---

## 格式规范

### 词块（tokens）
- 每条内容2-4个词块，最多不超过5个
- 切分原则：有学习价值的词单独成块，功能词附属合并
- 冠词并入名词：`le pain`、`une pomme`
- 人称代词并入动词：`je voudrais`、`vous avez`
- 固定搭配保持整体：`s'il vous plaît`、`il y a`
- 标点删除，不单独成块

### 必填字段
- `text`：原文
- `ipa`：国际音标，必须完整准确
- `translation`：中文翻译，实词必填，功能词留空
- `library`：CEFR级别，`A1`/`A2`/`B1`等
- `tokens`：词块数组，每个词块含text、lemma、hasImage、emoji、ipa、translation

### emoji规范
- 具体名词尽量配emoji
- 没有对应emoji的词显示法语文字
- 不强行配不准确的emoji

---

## 各级别词汇范围

### A1 入门
词汇来源：Français Fondamental第一级核心词，约300-500词

核心覆盖：
- 数字：1-20，基础序数词
- 颜色：红橙黄绿蓝紫黑白
- 食物饮料：水、面包、牛奶、咖啡、水果、蔬菜常见品种
- 动物：猫、狗、鸟、鱼、马等日常动物
- 身体部位：头、手、脚、眼、嘴、耳
- 家庭成员：爸爸、妈妈、兄弟、姐妹、孩子
- 日常物品：书、包、钥匙、手机、桌子、椅子、门
- 基础动词20个：être、avoir、aller、venir、faire、vouloir、pouvoir、manger、boire、parler、comprendre、acheter、donner、prendre、voir、savoir、aimer、habiter、travailler、partir
- 基础形容词：大小、冷热、好坏、新旧、贵便宜、快慢
- 基础问句：où、quand、comment、combien、qui、quoi

### A2 基础
词汇来源：Français Fondamental扩展词，约500-1500词

在A1基础上增加：
- 更多场景词汇：交通、天气、购物、餐厅、医院
- 时间表达：星期、月份、季节
- 情绪状态：高兴、难过、累、饿、渴
- 简单描述：颜色组合、数量表达、方向

### B1及以上
暂不生成，待A1/A2内容稳定后扩展。

### 跨级别原则
一条内容的级别由其**核心词**决定，不是句子结构。
`Je voudrais du pain`核心词是`pain`（A1），整条归A1。
功能词、连接词不影响级别判断。

---

## 质量验收标准

### 生成后自动检查
- 每条必须有IPA，不能为空
- 每条必须有中文翻译
- 词块数在2-4之间，超过5个报警
- library字段必须是有效的CEFR级别
- 不能包含模板句关键词：`Je note`、`Tu entends`、`C'est écrit`、`Réponse courte`
- lemma字段不能为空字符串或`-`

### 人工验收标准
- 这条内容，真实场景里有人会说吗？
- 核心词是否属于当前级别词表？
- emoji是否准确对应词义？
- IPA是否和发音一致？
- 词块切分是否合理，有没有过碎或过长？

### 词汇覆盖检查
- A1词表里每个核心词至少出现3次
- 名词占比不低于40%
- 不应出现连续5条都没有emoji的情况
