# LLLB Design System — Visual Language v1.0

适用范围：所有页面和组件。本文档是视觉决策的唯一依据，具体实现以此为准。

---

## 1. 色彩系统

### 背景

| 场景 | Light | Dark |
|------|-------|------|
| 主背景 | `#F0EFF4`（冷紫白） | `#16151A`（深紫灰） |
| 次级表面（sheet、card） | `#FFFFFF` opacity 0.75 | `#FFFFFF` opacity 0.07 |
| topbar / 导航栏 | 主背景色 + blur material | 主背景色 + blur material |

不使用系统默认的 `systemGroupedBackground` 或 `systemBackground`。Light/Dark 统一用上表指定值。

### Accent 色（唯一品牌色）

| 用途 | 值 |
|------|----|
| 主 Accent | `#9B6B2F`（暖金，Light）/ `#CC9B6D`（暖金，Dark） |
| Accent tint 背景 | Accent opacity 0.10 |
| Accent 描边 | Accent opacity 0.28 |

系统蓝（`Color.accentColor` / `#007AFF`）不再用于高亮和激活态。全局替换为暖金。

### 文字

| 层级 | Light | Dark |
|------|-------|------|
| 主文字 | `#1C1C1E` | `rgba(255,255,255,0.92)` |
| 次要文字（IPA、翻译、label） | `rgba(60,60,67,0.45)` | `rgba(255,255,255,0.32)` |
| 极弱文字（翻译句、hint） | `rgba(60,60,67,0.32)` | `rgba(255,255,255,0.22)` |

### 语义色（状态信号，保持克制）

| 状态 | 颜色 | 用途 |
|------|------|------|
| Favorite mode | `Color.green` opacity 0.12（背景 tint） | 仅背景，不用于控件 |
| Focus mode | Accent tint | 仅背景，不用于控件 |
| 连续天数 | `#FF9500` | 仅 streak 数字 |
| 错误 | `Color.red` | 仅 loadError |

---

## 2. 控件格子（左右两列）

### 默认态
- 背景：透明
- 描边：`0.5pt`，`rgba(60,60,67,0.10)`（Light）/ `rgba(255,255,255,0.08)`（Dark）
- 圆角：`12pt`
- icon：`.title2`，次要文字色
- label：`.caption2`，次要文字色

### 激活态（on）
- 背景：Accent tint（opacity 0.10）
- 描边：Accent opacity 0.28
- icon + label：Accent 色
- **不改变尺寸，不加粗，不加阴影**

### 实现要点
- 移除所有 `Color(.secondarySystemGroupedBackground)` 填充
- `toggleCell` 和 `controlCell` 统一用上述规范
- Speed、Repeats 格子同样遵守，数字用主文字色，label 用次要文字色

---

## 3. Token Chip

Token chip 是全 app 最核心的视觉元素，设计目标是「轻」。

### 尺寸与层级
- emoji：`22pt`（从 44pt 缩小）
- 单词（spelling）：`.title3`，主文字色，`weight: .medium`
- IPA：`.caption`，次要文字色，italic
- 翻译：`.caption`，次要文字色

### 默认态
- 背景：`rgba(255,255,255,0.06)`（Dark）/ `rgba(255,255,255,0.75)`（Light）
- 描边：`0.5pt`，`rgba(255,255,255,0.09)`（Dark）/ `rgba(60,60,67,0.10)`（Light）
- 圆角：`12pt`

### 播放高亮态（正在朗读）
- 背景：Accent tint（opacity 0.12）
- 描边：Accent opacity 0.28
- 单词颜色：Accent 色
- **移除蓝色边框（`Color.blue` stroke）**

### Focus 态（用户点击聚焦某词）
- 背景：Accent tint（opacity 0.18）
- 描边：Accent opacity 0.35
- 单词颜色：Accent 色（略深）

---

## 4. TopBar

- 高度：`36pt`（保持不变）
- 背景：`.ultraThinMaterial`，底部加 `0.5pt` 分隔线，颜色 `rgba(0,0,0,0.06)`（Light）/ `rgba(255,255,255,0.06)`（Dark）
- streak 数字：`#FF9500`，`.system(size:13, weight:.semibold)`
- 糖果余额：次要文字色，同字号

---

## 5. Tag Chip（句子标签）

- 背景：`rgba(60,60,67,0.06)`（Light）/ `rgba(255,255,255,0.07)`（Dark）
- 描边：`0.5pt`，`rgba(60,60,67,0.10)`（Light）/ `rgba(255,255,255,0.09)`（Dark）
- 文字：次要文字色，`system(size:10, weight:.medium)`
- 激活态：Accent tint 背景 + Accent 描边 + Accent 文字色

---

## 6. 浮动按钮（右下角菜单、左上角 xmark）

- 背景：`.ultraThinMaterial`
- 形状：`Circle()`
- icon 颜色：
  - 普通模式菜单按钮：主文字色
  - Focus mode xmark：Accent 色
  - Favorite mode xmark：`Color.green`
- **不改变现有交互逻辑**

---

## 7. Sheet（Speed / Repeats 弹出层）

- 背景：跟随系统 material，无需手动设置背景色
- 按钮颜色：可用/不可用态改为 Accent 色 / 次要文字色
- 数字显示：主文字色，monospaced

---

## 8. 通用原则

1. **不用系统默认灰**：`Color(.secondarySystemGroupedBackground)`、`Color(.tertiarySystemGroupedBackground)` 全部替换
2. **激活态只改颜色**：激活/选中状态通过颜色传达，不通过背景块大小或加粗传达
3. **暖金是唯一 accent**：移除所有 `Color.accentColor`（系统蓝）的使用，替换为暖金
4. **描边统一 0.5pt**：所有边框线宽 0.5pt，不用 1pt 或 2pt（播放高亮除外可用 0.5pt）
5. **圆角统一 12pt**：所有 chip、格子、卡片使用 12pt，小 pill 标签使用 `Capsule()`
6. **emoji 上限 22pt**：任何场景下 emoji 不超过 22pt

---

## 9. 子页面适用规范

所有子页面（LibraryPickerView、ProfileView 等）遵守以下基准：

- 背景色使用主背景（`#F0EFF4` / `#16151A`），不使用系统默认
- 列表分隔线：`0.5pt`，极弱色
- 选中态：Accent tint 背景 + Accent 文字
- 按钮：outline 样式（透明底 + 0.5pt Accent 描边），不用实心填充按钮
- NavigationTitle：主文字色，`.inline` 样式优先

---

*本文档由设计探讨阶段产出，交 Claude Code 执行时可直接引用各节规范。*
