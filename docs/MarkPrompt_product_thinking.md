# MarkPrompt 产品思考文档

> 产品定位：面向 Markdown 长文档创作与审核的「批注转 Prompt」工具。  
> 核心目标：让人类在 Markdown 文档上的修改意见、批注和审稿判断，能够被整理成结构化 Prompt，顺畅传递给 Codex、Claude Code 或其他 AI Agent 执行后续修改。

---

## 1. 背景与问题

当前在使用 Codex、Claude Code 等 AI 编程/写作 Agent 处理 Markdown 长文档时，存在一个明显断点：

人类在阅读文档时，通常会产生大量局部判断，例如：

- 这一段逻辑不够强；
- 这里表达太口语化；
- 这部分需要补充结论；
- 这个标题不够抓人；
- 这里和前文重复；
- 这一节需要重组；
- 这里应该面向 B 端客户，而不是普通读者；
- 这个观点可以保留，但需要换一种更商业化的表达。

这些判断本质上是非常重要的「编辑意图」，但它们很难被顺滑地传递给 AI。

现在常见的做法是：

1. 人先阅读 Markdown；
2. 手动复制某一段；
3. 在 Codex / Claude Code 里描述修改意见；
4. AI 根据模糊描述进行修改；
5. 人再回去检查；
6. 多轮重复。

这个过程的问题是：

- 批注和修改意见分散；
- Prompt 手写成本高；
- 长文档上下文容易丢；
- AI 容易误解人类的修改意图；
- 无法一次性整理多个修改点；
- Codex/Claude Code 虽然擅长执行，但不擅长接收大量松散批注；
- 人类审稿意见没有被结构化沉淀。

因此，真正需要解决的不是「AI 会不会改 Markdown」，而是：

> 人类如何高效、准确、低歧义地把 Markdown 审稿意见传递给 AI 执行器。

MarkPrompt 就是围绕这个问题设计的。

---

## 2. 产品名称

### 2.1 推荐名称

# MarkPrompt

中文解释：

> Markdown + Mark/批注 + Prompt

MarkPrompt 表示：

- 在 Markdown 文档上做标记；
- 将批注和修改意见整理成结构化 Prompt；
- 传递给 Codex / Claude Code 等 AI 工具继续执行。

### 2.2 中文副标题

**MD 批注转 Prompt 工具**

或：

**Markdown 审稿意见编译器**

### 2.3 一句话定位

> MarkPrompt 是一个面向 Markdown 长文档的批注转 Prompt 工具。用户可以在 Markdown 文档上做细致批注，然后一键生成适合 Codex、Claude Code 或其他 AI Agent 执行的结构化修改 Prompt。

更口语化版本：

> 你负责批注，MarkPrompt 负责把批注整理成 AI 能执行的修改指令。

---

## 3. 产品边界

MarkPrompt 不应该一开始做成完整的写作编辑器，也不应该替代 Codex 或 Claude Code。

它的定位应该非常克制：

> MarkPrompt 是 AI 写作工作流里的「Prompt Bridge」，不是最终执行器。

### 3.1 MarkPrompt 不做什么

初期不做：

- 不直接替代 Codex；
- 不直接替代 Claude Code；
- 不做完整 Agent Workspace；
- 不做复杂的 Markdown 编辑器；
- 不做全量文档版本管理；
- 不做自动回写文件；
- 不做复杂的实时 AI 修改；
- 不做截图驱动的视觉理解作为核心能力。

### 3.2 MarkPrompt 要做什么

初期只做：

- 打开或粘贴 Markdown 文档；
- 支持用户选中文本；
- 支持对选中文本添加批注；
- 支持批注类型结构化；
- 支持积累多个批注；
- 支持一键生成「给 Codex / Claude Code 的修改 Prompt」；
- 支持复制 Prompt 到剪贴板；
- 后续可以把 Prompt 直接发送到指定工具的输入框，但不是 MVP 必须项。

---

## 4. 核心用户场景

### 4.1 场景一：长文档审稿

用户通过 AI 生成了一篇较长 Markdown 文档，例如：

- 产品规划；
- 商业分析；
- 内容脚本；
- 技术方案；
- 创业方向梳理；
- UI 修改建议；
- 需求文档；
- 报告草稿。

用户不希望直接让 AI 一次性重写，而是希望自己先做审稿判断。

工作流：

1. 用户用 MarkPrompt 打开 Markdown；
2. 在渲染后的文档中逐段阅读；
3. 对具体句子/段落添加批注；
4. 批注可能包括「强化逻辑」「压缩表达」「改成 B 端视角」「补充结论」等；
5. 完成一轮审稿后，一键生成结构化 Prompt；
6. 把 Prompt 丢给 Codex 或 Claude Code；
7. Codex/Claude Code 根据批注整体修改 Markdown 文件。

### 4.2 场景二：AI 输出复核

用户经常让 AI 生成大量 Markdown 内容，但需要人工复核质量。

用户希望：

- 人来判断哪里不对；
- AI 来执行具体修改；
- 工具负责把人的判断转成 AI 可理解的指令。

MarkPrompt 解决的是「人类审稿意见 → AI 可执行 Prompt」这一段。

### 4.3 场景三：Codex 写作辅助

用户仍然把 Codex / Claude Code 作为主力执行器。

MarkPrompt 只负责前置整理：

```text
Markdown 原文
  ↓
人工批注
  ↓
结构化修改意见
  ↓
生成 Prompt
  ↓
粘贴到 Codex / Claude Code
  ↓
AI 执行文档修改
```

---

## 5. 核心产品理念

### 5.1 不是 AI 写作工具，而是 AI 输入增强器

MarkPrompt 的核心不是「帮你写」，而是「帮你把修改意见说清楚」。

它不追求在自身内部完成所有修改，而是把人的批注转换成更适合 AI 执行器理解的 Prompt。

### 5.2 批注不是普通评论，而是修改信号

传统批注系统里，评论是给人看的。

MarkPrompt 里的批注是给 AI 执行器看的，因此要尽量结构化。

例如普通批注：

```text
这里写得弱一点。
```

MarkPrompt 应该整理成：

```json
{
  "target": "选中的段落",
  "intent": "strengthen_argument",
  "instruction": "强化论证力度，增加明确结论，但不要改变原观点",
  "scope": "paragraph"
}
```

### 5.3 不是逐条调用 AI，而是先积累，再统一输出

MarkPrompt 不应该在每次批注时立刻调用 AI 改文档。

更合理的模式是：

```text
批注 1
批注 2
批注 3
...
批注 N
  ↓
统一生成 Prompt
  ↓
交给 Codex/Claude Code 执行
```

这样可以避免局部修改破坏全文一致性，也更适合长文档。

---

## 6. MVP 产品形态

### 6.1 MVP 形态

建议先做一个 Mac 小工具。

最小形态：

- 一个轻量 Markdown 阅读/批注窗口；
- 支持打开 `.md` 文件或粘贴 Markdown；
- 左侧/中间显示 Markdown 渲染结果；
- 用户可以选中文本并添加批注；
- 右侧显示批注列表；
- 底部或右上角有「生成 Prompt」按钮；
- 生成后复制到剪贴板；
- 用户自行粘贴到 Codex / Claude Code。

### 6.2 MVP 不必做复杂编辑

MVP 阶段不需要把 MarkPrompt 做成完整 Markdown 编辑器。

它更像一个「Markdown Review Tool」：

- 主要用于阅读；
- 主要用于批注；
- 主要用于生成 Prompt；
- 不负责最终修改文件。

这样开发成本低，产品边界清楚。

---

## 7. UI 设计：三个核心按钮

MVP 可以非常简单，核心只需要三个按钮。

### 7.1 按钮一：Add Note / 添加批注

用户选中文本后，点击：

```text
添加批注
```

弹出一个小浮窗，允许用户输入修改意见。

批注输入框建议包括：

- 自由文本；
- 批注类型；
- 作用范围；
- 修改强度。

### 7.2 按钮二：Review Notes / 查看批注

右侧打开批注列表。

每条批注展示：

- 被选中的原文；
- 用户批注意见；
- 批注类型；
- 所属标题/章节；
- 是否已确认；
- 是否纳入最终 Prompt。

用户可以删除、编辑、排序批注。

### 7.3 按钮三：Generate Prompt / 生成 Prompt

点击后生成一个完整 Prompt。

Prompt 输出后：

- 自动复制到剪贴板；
- 也可以在弹窗中预览；
- 用户手动粘贴到 Codex / Claude Code。

---

## 8. 快捷键设计

快捷键应该服务于高频审稿。

### 8.1 全局快捷键

建议：

```text
Cmd + Shift + P
```

用途：

- 唤起 MarkPrompt 小工具；
- 或打开当前批注面板；
- 类似命令面板。

### 8.2 选中后快捷键

建议：

```text
Cmd + Shift + A
```

用途：

- 对当前选中文本添加批注。

### 8.3 生成 Prompt 快捷键

建议：

```text
Cmd + Shift + Enter
```

用途：

- 生成最终 Prompt 并复制到剪贴板。

### 8.4 批注类型快捷键

可选：

```text
Cmd + 1：表达优化
Cmd + 2：逻辑增强
Cmd + 3：结构调整
Cmd + 4：压缩精简
Cmd + 5：自定义
```

---

## 9. 批注类型设计

为降低 AI 理解歧义，批注不应该只有自由文本。

建议使用「批注类型 + 自由说明」的混合模式。

### 9.1 初始批注类型

MVP 可内置以下类型：

| 类型 | 说明 |
|---|---|
| rewrite | 改写表达 |
| clarify | 提高清晰度 |
| strengthen | 强化论点 |
| shorten | 压缩精简 |
| expand | 扩展说明 |
| restructure | 调整结构 |
| change_tone | 调整语气 |
| add_conclusion | 增加结论 |
| remove_redundancy | 去除重复 |
| custom | 自定义 |

### 9.2 批注作用范围

每条批注应指定作用范围：

| 范围 | 说明 |
|---|---|
| selected_text | 只修改选中文本 |
| paragraph | 修改所在段落 |
| section | 修改所在章节 |
| global | 作为全文约束 |

### 9.3 修改强度

建议提供强度选项：

| 强度 | 说明 |
|---|---|
| light | 轻微润色 |
| medium | 中等修改 |
| heavy | 允许明显重写 |

### 9.4 风格约束

可选：

- 更商业化；
- 更正式；
- 更口语；
- 更适合 B 端；
- 更适合小红书；
- 更适合产品文档；
- 更像技术方案；
- 保持原意；
- 不改变结构；
- 不新增未经证实的信息。

---

## 10. Instruction Schema

MarkPrompt 内部可以把每条批注保存为结构化对象。

### 10.1 单条批注结构

```json
{
  "id": "note_001",
  "file_name": "example.md",
  "section_heading": "3. 产品定位",
  "selected_text": "当前这段产品定位还不够清楚。",
  "user_comment": "这里需要更明确地说明它不是编辑器，而是批注转 Prompt 的桥接工具。",
  "intent": "clarify",
  "scope": "paragraph",
  "strength": "medium",
  "constraints": [
    "保持原意",
    "不要扩展太多",
    "语言更直接"
  ],
  "priority": "normal"
}
```

### 10.2 多条批注结构

```json
{
  "document": {
    "file_name": "markprompt-product.md",
    "type": "markdown"
  },
  "global_instructions": [
    "保留 Markdown 标题层级",
    "不要删除用户已有的重要观点",
    "只根据批注进行修改，不要自由发挥"
  ],
  "annotations": [
    {
      "id": "note_001",
      "section_heading": "1. 背景",
      "selected_text": "...",
      "user_comment": "...",
      "intent": "strengthen",
      "scope": "paragraph",
      "strength": "medium"
    },
    {
      "id": "note_002",
      "section_heading": "2. 产品定位",
      "selected_text": "...",
      "user_comment": "...",
      "intent": "clarify",
      "scope": "section",
      "strength": "heavy"
    }
  ]
}
```

---

## 11. Prompt 模板

### 11.1 核心 Prompt 目标

生成给 Codex / Claude Code 的 Prompt 时，应确保：

- 明确说明要修改的是 Markdown 文档；
- 明确说明用户已经做了批注；
- 要求 AI 根据批注修改原文；
- 要求 AI 不要自由发挥；
- 要求保留 Markdown 结构；
- 要求输出修改后的完整 Markdown 或 patch；
- 如果是在 Codex 中使用，可以要求直接修改指定文件。

---

## 12. Codex / Claude Code 可用 Prompt 格式

这里的「兼容格式」不是某种官方协议，而是指：

> 生成出来的 Prompt 可以直接粘贴到 Codex 或 Claude Code 的聊天框里，并且对方能理解要怎么修改 Markdown 文件。

### 12.1 Codex 版本 Prompt

适合在 Codex 里使用，因为 Codex 通常可以读取和修改项目文件。

```text
你现在要修改一个 Markdown 文档。

目标文件：
{file_path}

请根据下面的人工批注，对该 Markdown 文档进行修改。

重要要求：
1. 保留原文的 Markdown 标题层级和整体结构，除非批注明确要求调整结构。
2. 不要删除未被批注影响的重要观点。
3. 不要添加未经原文或批注支持的新事实。
4. 优先根据批注进行局部修改，但要保证全文读起来连贯。
5. 如果多个批注之间存在冲突，请优先保留原意，并在修改后说明冲突点。
6. 修改完成后，请给出简短变更摘要。

全局修改要求：
{global_instructions}

人工批注如下：

{annotations}

请直接修改目标 Markdown 文件。
```

### 12.2 Claude Code 版本 Prompt

适合 Claude Code 或其他文件型 Agent。

```text
Please revise the Markdown document according to the human review notes below.

File:
{file_path}

Editing principles:
- Preserve the Markdown heading hierarchy unless a note explicitly requests restructuring.
- Keep the author's original intent.
- Do not invent new facts.
- Apply all notes as a coherent editing pass, not as isolated rewrites.
- If two notes conflict, choose the option that best preserves clarity and document consistency.

Global instructions:
{global_instructions}

Human annotations:
{annotations}

Expected output:
1. Update the Markdown file.
2. Provide a brief summary of major changes.
3. Mention any annotation that could not be applied cleanly.
```

### 12.3 纯复制版 Prompt

适合没有文件访问能力的 AI。

````text
请根据下面的人工批注，修改这份 Markdown 文档。

修改原则：
1. 保留 Markdown 标题层级。
2. 保持原文核心意思。
3. 不要添加未经支持的新事实。
4. 将所有批注作为一次整体修改任务处理，而不是逐条割裂修改。
5. 修改后输出完整 Markdown。

原始 Markdown：

```markdown
{full_markdown}
```

人工批注：

{annotations}

请输出修改后的完整 Markdown。
````

---

## 13. Prompt 输出中的批注格式

为了让 Codex/Claude Code 更好理解，批注不应该只输出自然语言列表，而应半结构化展示。

### 13.1 推荐格式

```text
[NOTE note_001]
Location: 3. 产品定位
Scope: paragraph
Intent: clarify
Strength: medium

Selected text:
"""
当前这个产品像是一个编辑器。
"""

Human comment:
"""
这里要改清楚：它不是编辑器，而是把 MD 批注转成 Prompt 的桥接工具。
"""

Constraints:
- 保持表达简洁
- 不要引入过多技术细节
[/NOTE]
```

### 13.2 多条批注示例

```text
[NOTE note_001]
Location: 1. 背景与问题
Scope: paragraph
Intent: strengthen
Strength: medium

Selected text:
"""
AI 修改 Markdown 的过程不太顺。
"""

Human comment:
"""
这里要把痛点写得更具体：不是 AI 不会改，而是人类修改意见无法顺滑传递给 AI。
"""
[/NOTE]

[NOTE note_002]
Location: 2. 产品定位
Scope: section
Intent: clarify
Strength: heavy

Selected text:
"""
这是一个写作工具。
"""

Human comment:
"""
定位不应该是写作工具，而是批注转 Prompt 工具，强调它服务于 Codex/Claude Code 工作流。
"""
[/NOTE]
```

---

## 14. 为什么不建议一开始做截图

用户之前考虑过截图作为输入，但从 MarkPrompt 当前定位来看，截图不应该是核心。

原因：

- Markdown 文档本身是文本结构，文本比截图更适合 AI 修改；
- 截图无法稳定定位原文；
- 截图不可 diff；
- 截图很难进入版本管理；
- 截图会增加复杂度；
- 批注转 Prompt 的核心不依赖视觉理解。

截图可以作为后续辅助能力，例如：

- 批注时自动生成上下文截图；
- 提供给人类回看；
- 用于 UI 视觉反馈；
- 但不应作为 MVP 的主要输入源。

---

## 15. 为什么不建议一开始做完整编辑器

做完整 Markdown 编辑器会引入大量非核心成本：

- 文件管理；
- 编辑器体验；
- Markdown 语法兼容；
- 预览同步；
- diff；
- 插件系统；
- 历史版本；
- 快捷键冲突；
- 多窗口；
- 自动保存。

这些都不是 MarkPrompt 的核心价值。

核心价值只有一个：

> 把人的 Markdown 审稿批注，转译成 AI 可执行 Prompt。

因此 MVP 应尽量避免陷入编辑器工程。

---

## 16. 独立 Mac 软件 vs VS Code 插件

### 16.1 VS Code 插件的优点

- 文件系统现成；
- Markdown 编辑器现成；
- 适合开发者使用；
- 可以直接读取当前文件路径；
- 可以直接插入批注标记；
- 和 Codex/Claude Code 的开发环境更接近。

### 16.2 VS Code 插件的问题

- 用户心理仍然是代码编辑器；
- 对长文沉浸式审稿不够自然；
- UI 自由度受限；
- 不适合做轻量浮窗和跨工具 Prompt Bridge；
- 更容易被做成「另一个插件」，而不是独立写作辅助工具。

### 16.3 Mac 小工具的优点

- 独立、轻量；
- 可以跨 VS Code、Obsidian、Typora、Finder、浏览器使用；
- 可以作为全局 Prompt Bridge；
- 用户只需要复制/打开 Markdown；
- 更适合未来做系统级辅助工具。

### 16.4 当前建议

MVP 更建议先做 **Mac 小工具**，而不是 VS Code 插件。

原因：

MarkPrompt 的核心不是依赖某个编辑器，而是作为 Codex/Claude Code 的上游批注整理层。

但可以保留未来 VS Code 插件版本：

- Mac App：主产品；
- VS Code 插件：开发者增强版；
- Web 版：轻量试用版。

---

## 17. 最小可行产品规格

### 17.1 输入

支持：

- 打开 `.md` 文件；
- 粘贴 Markdown 文本；
- 从剪贴板读取 Markdown。

### 17.2 阅读

支持：

- Markdown 渲染预览；
- 标题层级识别；
- 文本选择；
- 高亮已批注片段。

### 17.3 批注

支持：

- 选中文本添加批注；
- 批注类型选择；
- 自由输入修改意见；
- 指定作用范围；
- 指定修改强度；
- 批注列表管理。

### 17.4 Prompt 生成

支持：

- 生成 Codex 风格 Prompt；
- 生成 Claude Code 风格 Prompt；
- 生成通用完整 Markdown 输入 Prompt；
- 一键复制；
- 预览 Prompt。

### 17.5 输出

MVP 输出：

- Prompt 文本；
- 可复制到剪贴板。

后续输出：

- `.prompt.md` 文件；
- `.review.json` 批注文件；
- 直接发送到某个 Agent 输入框；
- 自动打开 Codex/Claude Code。

---

## 18. 数据文件设计

### 18.1 原文文件

```text
product-thinking.md
```

### 18.2 批注文件

```text
product-thinking.review.json
```

用于保存批注结构。

### 18.3 Prompt 文件

```text
product-thinking.prompt.md
```

用于保存生成给 Codex/Claude Code 的 Prompt。

### 18.4 目录示例

```text
/project
  ├── product-thinking.md
  ├── product-thinking.review.json
  └── product-thinking.prompt.md
```

---

## 19. Review JSON 示例

```json
{
  "version": "0.1",
  "source_file": "product-thinking.md",
  "created_at": "2026-06-26T00:00:00Z",
  "global_instructions": [
    "保持 Markdown 结构",
    "语言更直接",
    "不要新增未经证实的信息"
  ],
  "annotations": [
    {
      "id": "note_001",
      "section_heading": "产品定位",
      "selected_text": "这是一个 AI 写作工具。",
      "user_comment": "改成批注转 Prompt 工具，不要定位成完整写作工具。",
      "intent": "clarify",
      "scope": "paragraph",
      "strength": "medium",
      "constraints": [
        "强调服务于 Codex/Claude Code",
        "避免泛化成写作平台"
      ]
    }
  ]
}
```

---

## 20. 技术实现建议

### 20.1 技术路线

建议优先考虑：

- Electron + React；
- 或 Tauri + React。

如果想尽快做出原型，Electron 更快。

### 20.2 前端模块

- Markdown 文件加载；
- Markdown 渲染；
- 文本选择监听；
- 批注浮窗；
- 批注列表；
- Prompt 预览；
- 剪贴板复制。

### 20.3 Markdown 渲染

可使用：

- `react-markdown`
- `remark`
- `rehype`
- `markdown-it`

### 20.4 批注定位

MVP 可以不追求完美 range 精准定位。

建议先用：

- section heading；
- selected text；
- before/after context；
- annotation id。

示例：

```json
{
  "selected_text": "...",
  "section_heading": "3. 产品定位",
  "before_context": "...",
  "after_context": "..."
}
```

这样即使文档轻微变化，Codex 仍然可以通过上下文定位。

### 20.5 剪贴板

MVP 必须做好：

- 一键复制 Prompt；
- 复制成功提示；
- 保留 Markdown 格式。

---

## 21. 批注定位策略

为了降低 AI 歧义，单靠 selected_text 可能不够。

每条批注建议包含四层定位：

1. 文件名；
2. 所属标题；
3. 选中文本；
4. 前后上下文。

示例：

```text
Location:
File: product-thinking.md
Section: 3. 产品定位

Before context:
"""
...
"""

Selected text:
"""
...
"""

After context:
"""
...
"""
```

这样 Codex / Claude Code 更容易定位要修改的区域。

---

## 22. 生成 Prompt 的关键原则

MarkPrompt 生成 Prompt 时，要遵守以下原则：

### 22.1 明确角色

告诉 AI：

> 你正在修改 Markdown 文档。

### 22.2 明确目标

告诉 AI：

> 根据人工批注修改文档。

### 22.3 明确边界

告诉 AI：

> 不要无关发挥，不要新增事实，不要大幅改结构。

### 22.4 明确输出方式

告诉 AI：

> 直接修改文件 / 输出完整 Markdown / 输出 diff。

### 22.5 明确冲突处理

告诉 AI：

> 如果批注冲突，优先保持原意和文档一致性，并说明冲突。

---

## 23. 未来功能方向

### 23.1 批注模板

允许用户保存常用批注模板，例如：

- 改成更商业化；
- 加强结论；
- 压缩废话；
- 改成小红书口吻；
- 改成产品经理表达；
- 改成技术方案表达。

### 23.2 Prompt 模板管理

支持不同执行器：

- Codex；
- Claude Code；
- ChatGPT；
- Gemini；
- Cursor；
- 自定义 Agent。

### 23.3 Agent 输入框自动粘贴

未来可以做：

- 生成 Prompt 后自动复制；
- 自动切换到 Codex/Claude Code；
- 自动粘贴到输入框；
- 用户手动按 Enter。

这一功能需要处理系统权限和应用兼容性，不建议 MVP 阶段做。

### 23.4 批注导出

支持导出：

- `.review.json`
- `.prompt.md`
- `.md` 批注版
- HTML 批注报告

### 23.5 差异对照

未来可以加入：

- 原文；
- 批注；
- AI 修改后版本；
- diff 对照。

但这属于第二阶段，不是 MVP 必须项。

---

## 24. 产品路线图

### Phase 0：概念验证

目标：

- 验证批注转 Prompt 是否真的提升 Codex/Claude Code 修改效率。

功能：

- 粘贴 Markdown；
- 手动添加批注；
- 生成 Prompt；
- 复制到剪贴板。

### Phase 1：Mac MVP

目标：

- 做成可日常使用的小工具。

功能：

- 打开 `.md` 文件；
- Markdown 渲染；
- 选中添加批注；
- 批注列表；
- 生成 Prompt；
- 复制 Prompt；
- 保存 `.review.json`。

### Phase 2：工作流增强

目标：

- 让工具嵌入真实写作流程。

功能：

- Prompt 模板；
- Codex / Claude Code 输出格式选择；
- 批注模板；
- 多文档支持；
- 最近文件；
- 自动保存。

### Phase 3：高级版本

目标：

- 形成完整 AI 写作审稿工作台。

功能：

- diff 对照；
- 版本管理；
- 自动粘贴 Agent；
- 批注统计；
- 团队协作；
- Web 版或 VS Code 插件。

---

## 25. MVP 成功标准

MarkPrompt MVP 是否成功，不看功能复杂度，而看以下指标：

### 25.1 是否降低 Prompt 编写成本

用户是否觉得：

> 我不用再手写一大段修改意见了。

### 25.2 是否降低 AI 理解歧义

Codex/Claude Code 是否更准确理解：

- 改哪里；
- 怎么改；
- 改到什么程度；
- 什么不能改。

### 25.3 是否适合长文档

用户是否能在一篇长 Markdown 里连续添加 10 条以上批注，并统一生成 Prompt。

### 25.4 是否形成稳定工作流

理想工作流：

```text
AI 生成初稿
  ↓
MarkPrompt 批注
  ↓
生成 Prompt
  ↓
Codex/Claude Code 修改
  ↓
人工复核
```

---

## 26. 需要警惕的风险

### 26.1 过早做成完整编辑器

会导致产品工程量爆炸。

### 26.2 过早接入 AI 自动修改

会模糊产品边界。

### 26.3 批注太自由

如果用户只写自然语言批注，AI 仍然容易误解。

### 26.4 批注定位不准

长文档中仅靠选中文本可能定位失败，需要 heading 和上下文辅助。

### 26.5 Prompt 太长

长文档 + 多批注容易超过上下文，需要控制输出策略：

- Codex 文件模式：只输出批注和文件路径；
- 通用模式：必要时附全文；
- 局部模式：只附相关 section。

---

## 27. Prompt 长度策略

### 27.1 文件型 Agent 模式

当使用 Codex/Claude Code 且它能读取项目文件时：

不需要把全文放进 Prompt。

只需要：

- 文件路径；
- 全局修改原则；
- 批注列表；
- 选中文本和上下文。

### 27.2 非文件型 AI 模式

当 AI 无法访问文件时：

需要把完整 Markdown 放进 Prompt。

### 27.3 长文档模式

当文档很长时，可以选择只输出相关 section：

- 批注所在章节；
- 章节上下文；
- 批注说明；
- 要求 AI 修改后输出该章节。

---

## 28. 产品最终定义

MarkPrompt 是一个面向 Markdown 长文档的批注转 Prompt 工具。

它的核心价值不是替用户写作，而是：

> 把用户在 Markdown 文档上的审稿判断、修改意见和局部批注，整理成结构化、低歧义、可直接交给 Codex/Claude Code 执行的 Prompt。

它服务于以下工作流：

```text
Markdown 文档
  ↓
人工批注
  ↓
MarkPrompt 编译
  ↓
Codex / Claude Code 执行修改
  ↓
产出新版本 Markdown
```

一句话总结：

> MarkPrompt 是写作型 AI Agent 的上游输入增强器。

---

## 29. 下一步建议

建议下一步让 Codex 基于本文档继续做两件事：

### 29.1 生成 PRD

让 Codex 将本文档整理为：

- 产品目标；
- 用户故事；
- MVP 功能列表；
- 非目标；
- 技术约束；
- 验收标准。

### 29.2 生成技术方案

让 Codex 继续拆：

- Electron/Tauri 选型；
- React 组件结构；
- Markdown 渲染方案；
- 批注数据结构；
- Prompt 模板生成器；
- 本地文件保存；
- 快捷键和剪贴板功能。

---

## 30. 可以直接给 Codex 的下一步 Prompt

```text
请阅读这个 MarkPrompt 产品思考文档，并基于它继续完成两份输出：

1. MarkPrompt MVP PRD
- 产品定位
- 用户场景
- 核心流程
- 功能列表
- 非目标
- 验收标准

2. MarkPrompt MVP 技术方案
- 推荐技术栈
- 项目目录结构
- 核心数据模型
- 主要 React/Electron 模块
- Prompt 生成器设计
- 文件读写与本地保存策略
- 快捷键设计
- 第一阶段开发任务拆解

要求：
- 保持 MVP 克制，不要扩大成完整编辑器或 Agent Workspace。
- 核心目标是：Markdown 批注 → 结构化修改意见 → 生成可粘贴给 Codex/Claude Code 的 Prompt。
- 优先保证可用性和开发速度。
```
