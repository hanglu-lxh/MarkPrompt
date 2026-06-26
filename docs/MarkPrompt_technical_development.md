# MarkPrompt 技术开发文档

> 技术版本：V1 开发方案  
> 产品依据：[MarkPrompt_PRD.md](MarkPrompt_PRD.md)  
> 交互依据：[MarkPrompt_interaction_spec.md](MarkPrompt_interaction_spec.md)  
> 原型依据：V4 高保真原型  
> 目标平台：macOS 原生应用  
> 核心目标：实现一款本地优先的 Markdown 阅读批注工具，并将批注稳定生成可交给 Codex / Claude Code 执行的 Prompt。

![MarkPrompt V4 原型](assets/markprompt_interaction_prototype_v4.png)

---

## 1. 技术目标

MarkPrompt V1 的技术目标是用原生 macOS 技术实现以下闭环：

```text
打开 Markdown 文件
  -> 解析文档结构
  -> 渲染可选择的阅读视图
  -> 在选区旁创建批注
  -> 保存批注 sidecar
  -> 右侧实时生成 Prompt
  -> 复制或保存 Prompt
```

必须优先保证：

- 文本选择准确；
- 批注锚点可恢复；
- Prompt 生成稳定；
- 所有数据默认本地保存；
- 主流程符合 V4 一窗三栏交互。

---

## 2. 技术选型

### 2.1 总体方案

首版采用 Swift 原生 macOS 应用。

| 模块 | 技术 |
|---|---|
| App 外壳 | SwiftUI |
| 主窗口布局 | `NavigationSplitView` 或自定义三栏 SwiftUI layout |
| Markdown 解析 | `swift-markdown` |
| 阅读区渲染与选择 | AppKit `NSTextView` / TextKit |
| SwiftUI 与 AppKit 桥接 | `NSViewRepresentable` |
| 批注浮层 | SwiftUI popover + AppKit 选区坐标 |
| 数据保存 | 本地 JSON sidecar |
| Prompt 生成 | 本地模板引擎 |
| 剪贴板 | `NSPasteboard` |
| 文件访问 | `NSOpenPanel`、security-scoped bookmark |

### 2.2 为什么不用 WebView / React

产品核心体验依赖原生文本选择、选区定位、浮动按钮、阅读滚动和本地文件处理。使用 `NSTextView` 能更直接地获得：

- 原生 macOS 选区行为；
- 稳定的字符 range；
- 系统字体、滚动、辅助功能；
- 更低的渲染和事件桥接成本；
- 更自然的 popover、菜单、快捷键和剪贴板体验。

WebView 可以作为后续实验方案，但不作为 V1 主路径。

---

## 3. 应用架构

### 3.1 分层结构

```text
App Layer
├── MarkPromptApp
├── AppCommands
└── WindowScene

Feature Layer
├── DocumentFeature
├── ReaderFeature
├── AnnotationFeature
├── PromptFeature
└── SettingsFeature

Core Layer
├── MarkdownCore
├── AnchorCore
├── PromptCore
├── PersistenceCore
└── SharedModels
```

### 3.2 推荐目录结构

```text
MarkPrompt/
├── App/
│   ├── MarkPromptApp.swift
│   ├── AppState.swift
│   └── AppCommands.swift
├── Features/
│   ├── Document/
│   │   ├── DocumentStore.swift
│   │   ├── DocumentLoader.swift
│   │   └── RecentDocumentStore.swift
│   ├── Reader/
│   │   ├── MarkdownReaderView.swift
│   │   ├── MarkdownTextViewRepresentable.swift
│   │   ├── ReaderTextView.swift
│   │   ├── SelectionCoordinator.swift
│   │   └── AnnotationHighlightRenderer.swift
│   ├── Outline/
│   │   ├── OutlineSidebarView.swift
│   │   └── OutlineBuilder.swift
│   ├── Annotation/
│   │   ├── AnnotationPopoverView.swift
│   │   ├── AnnotationPanelView.swift
│   │   ├── NoteCardView.swift
│   │   └── QuickPromptCatalog.swift
│   ├── Prompt/
│   │   ├── PromptPreviewView.swift
│   │   ├── PromptBuilder.swift
│   │   └── PromptTemplate.swift
│   └── Settings/
│       └── SettingsView.swift
├── Core/
│   ├── Markdown/
│   │   ├── MarkdownParser.swift
│   │   ├── MarkdownRenderModel.swift
│   │   ├── MarkdownAttributedRenderer.swift
│   │   └── MarkdownSourceMap.swift
│   ├── Anchors/
│   │   ├── TextAnchor.swift
│   │   ├── TextAnchorResolver.swift
│   │   └── TextNormalizer.swift
│   ├── Persistence/
│   │   ├── ReviewSessionStore.swift
│   │   ├── SidecarFileLocator.swift
│   │   └── FileBookmarkStore.swift
│   └── Models/
│       ├── ReviewSession.swift
│       ├── ReviewNote.swift
│       ├── MarkdownDocument.swift
│       └── AppError.swift
└── Tests/
    ├── AnchorCoreTests/
    ├── PromptCoreTests/
    ├── PersistenceCoreTests/
    └── MarkdownCoreTests/
```

---

## 4. 核心数据流

### 4.1 打开文档

```text
NSOpenPanel / drag file
  -> DocumentLoader 读取 Markdown
  -> MarkdownParser 解析标题和节点
  -> MarkdownAttributedRenderer 生成 attributed string
  -> MarkdownSourceMap 建立 rendered range 到 source range 的映射
  -> ReviewSessionStore 加载 .review.json
  -> ReaderView 渲染正文和批注标记
  -> PromptBuilder 生成初始预览
```

### 4.2 添加批注

```text
用户选择文本
  -> ReaderTextView 提供 selectedRange
  -> SelectionCoordinator 计算浮动按钮位置
  -> MarkdownSourceMap 将 selectedRange 映射到 source range
  -> 用户输入批注意见
  -> AnnotationFeature 创建 ReviewNote
  -> ReviewSessionStore 自动保存
  -> AnnotationHighlightRenderer 更新正文标记
  -> PromptBuilder 刷新 Prompt 预览
```

### 4.3 复制 Prompt

```text
用户点击复制
  -> PromptBuilder 读取当前 session
  -> 过滤 include_in_prompt = true 的批注
  -> 按模板生成 prompt string
  -> NSPasteboard 写入字符串
  -> UI 显示复制成功状态
```

---

## 5. 数据模型

### 5.1 MarkdownDocument

```swift
struct MarkdownDocument: Identifiable, Equatable {
    let id: UUID
    let fileURL: URL?
    var displayName: String
    var rawMarkdown: String
    var sourceHash: String
    var outline: [DocumentHeading]
    var renderModel: MarkdownRenderModel
}
```

### 5.2 DocumentHeading

```swift
struct DocumentHeading: Identifiable, Codable, Equatable {
    let id: UUID
    var level: Int
    var title: String
    var sourceRange: SourceTextRange
    var children: [DocumentHeading]
}
```

### 5.3 ReviewSession

```swift
struct ReviewSession: Codable, Equatable {
    var version: String
    var sourceFile: String?
    var sourceHash: String
    var notes: [ReviewNote]
    var createdAt: Date
    var updatedAt: Date
}
```

### 5.4 ReviewNote

```swift
struct ReviewNote: Identifiable, Codable, Equatable {
    var id: String
    var status: ReviewNoteStatus
    var includeInPrompt: Bool
    var anchor: TextAnchor
    var comment: String
    var quickPrompts: [QuickPromptUsage]
    var inferredMetadata: InferredNoteMetadata?
    var createdAt: Date
    var updatedAt: Date
}
```

### 5.5 TextAnchor

```swift
struct TextAnchor: Codable, Equatable {
    var headingPath: [String]
    var selectedText: String
    var normalizedSelectedText: String
    var sourceRange: SourceTextRange?
    var renderedRange: RenderedTextRange?
    var contextBefore: String
    var contextAfter: String
    var documentHash: String
}
```

### 5.6 QuickPromptUsage

```swift
struct QuickPromptUsage: Codable, Equatable {
    var id: String
    var label: String
    var insertedText: String
}
```

### 5.7 Note 状态

```swift
enum ReviewNoteStatus: String, Codable {
    case draft
    case confirmed
    case excluded
    case anchorLost = "anchor_lost"
}
```

---

## 6. Markdown 渲染方案

### 6.1 渲染原则

阅读区必须渲染成可选择文本，而不是图片或不可选 HTML。V1 推荐使用 `NSTextView` 承载 `NSAttributedString`。

渲染能力：

- H1-H6；
- 段落；
- 无序和有序列表；
- 引用；
- 行内代码；
- 代码块；
- 链接；
- 表格基础展示；
- 分割线。

### 6.2 Source Map

批注能否精准生成 Prompt，取决于渲染文本与原始 Markdown 的映射。

需要维护两类 range：

```text
source range   原始 Markdown 字符范围
rendered range 渲染后 NSTextView 字符范围
```

`MarkdownSourceMap` 负责：

- 从 Markdown AST 生成 block 级映射；
- 渲染时记录每个 block 的 rendered range；
- 对用户选区进行 source range 反查；
- 当精确映射失败时，提供基于文本和上下文的 fallback。

### 6.3 首版映射策略

V1 可以分三层实现：

1. 精确映射：选区落在单一 block 内时，通过 block source range 和 rendered offset 计算 source range。
2. 跨 block 映射：选区跨段落或列表时，保存 selectedText、headingPath、contextBefore、contextAfter，不强求单一连续 source range。
3. 恢复映射：重新打开文档时，先用 source range 和 hash，失败后使用 headingPath + normalizedSelectedText + context 匹配。

### 6.4 文本标准化

锚点匹配前需要标准化文本。

规则：

- 合并连续空白；
- 去掉 Markdown 装饰字符影响；
- 统一换行；
- 保留中文、英文、数字和标点；
- 不做语义改写。

---

## 7. Reader 与选区实现

### 7.1 ReaderTextView

`ReaderTextView` 是 `NSTextView` 子类，职责包括：

- 展示 attributed string；
- 监听选区变化；
- 暴露 selectedRange；
- 计算选区 rect；
- 绘制或协助绘制批注高亮；
- 处理右键菜单和快捷键。

### 7.2 SwiftUI 桥接

```swift
struct MarkdownTextViewRepresentable: NSViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @Binding var selection: ReaderSelection?
    var notes: [ReviewNote]
    var onSelectionChange: (ReaderSelection?) -> Void
    var onRequestAnnotation: (ReaderSelection) -> Void
}
```

桥接注意：

- 不要在每次 SwiftUI 刷新时重建 `NSTextView`；
- attributed string 更新应尽量 diff 或按文档级别更新；
- 选区变化要节流，避免高频刷新 SwiftUI；
- popover 坐标要从 text container 转换到 window 坐标。

### 7.3 浮动按钮定位

浮动按钮位置来自当前选区末尾 rect。

计算过程：

```text
selectedRange
  -> layoutManager.boundingRect(forGlyphRange:)
  -> textContainer origin offset
  -> textView coordinate
  -> window coordinate
  -> SwiftUI overlay coordinate
```

交互规则：

- 选区为空时隐藏；
- 选区变化时更新位置；
- 滚动导致选区不可见时隐藏；
- 点击浮动按钮时保留 selectedRange。

---

## 8. 批注实现

### 8.1 创建批注

创建批注时需要生成：

- note id；
- anchor；
- comment；
- quick prompt usage；
- includeInPrompt；
- timestamps。

note id 规则：

```text
note_001
note_002
note_003
```

删除 note 后不复用旧 id。

### 8.2 快捷提示

快捷提示由本地 catalog 管理。

```swift
struct QuickPromptDefinition: Identifiable, Equatable {
    let id: String
    let label: String
    let insertedText: String
}
```

默认 catalog：

| id | label |
|---|---|
| improve_expression | 优化表达 |
| rewrite_segment | 重写这段 |
| adjust_tone | 优化语气 |
| add_actions | 补充措施 |
| strengthen_argument | 强化论证 |
| compress | 压缩精简 |

### 8.3 高亮渲染

高亮有三种视觉状态：

| 状态 | 表现 |
|---|---|
| confirmed | 柔和黄色下划线或浅色背景 |
| selected | 更明显的黄色下划线和浅蓝轮廓 |
| excluded | 降低透明度 |
| anchor_lost | 右侧卡片显示状态，正文不强行标记 |

实现方式建议：

- V1 可直接给 attributed string 添加 background / underline attributes；
- 如果需要更接近手绘下划线，可后续自定义 `NSLayoutManager` 或 overlay layer；
- 当前 note 选中态可以通过二次属性覆盖。

---

## 9. 右侧面板实现

### 9.1 AnnotationPanelView

右侧面板包含：

- header；
- segmented control；
- note list；
- prompt preview；
- bottom actions。

`批注` 分段：

- note list 占主要高度；
- prompt preview 保持紧凑高度。

`Prompt` 分段：

- prompt preview 占主要高度；
- note list 变为摘要列表或折叠。

### 9.2 NoteCardView

卡片操作：

- 点击：跳转到正文锚点；
- 开关：切换 includeInPrompt；
- 更多：编辑、删除、重新定位；
- 双击 comment：进入编辑。

### 9.3 状态同步

任何 note 变更必须触发：

```text
ReviewSession 更新
  -> 自动保存
  -> Reader 高亮刷新
  -> Prompt 预览刷新
```

---

## 10. Prompt 生成

### 10.1 PromptBuilder

`PromptBuilder` 是纯本地模块，不调用模型。

输入：

- MarkdownDocument；
- ReviewSession；
- PromptTemplate；
- 用户设置。

输出：

- prompt string；
- prompt metadata；
- validation warnings。

### 10.2 模板接口

```swift
protocol PromptTemplate {
    var id: String { get }
    var name: String { get }
    func render(context: PromptRenderContext) -> String
}
```

### 10.3 Codex 文件修改模式

默认模板结构：

```text
# Codex 文件修改模式

目标文件：
<absolute file path>

全局修改原则：
- 保持 Markdown 标题层级
- 不新增未经证实的信息
- 语言更直接，更易读
- 以用户批注意见为准

批注列表：

[NOTE note_001]
章节：<heading path>
选中文本：<selected text>
批注意见：<comment>
定位信息：
- source range: <start>-<end>
- context before: <context before>
- context after: <context after>

输出要求：
- 直接修改目标文件
- 完成后说明修改了哪些位置
- 如果定位不确定，先说明原因，不要擅自改写无关段落
```

### 10.4 Prompt 刷新策略

Prompt 预览应实时刷新，但需要节流。

建议：

- note 变更后 100-200ms debounce；
- 大文档仅重建 prompt string，不重新解析 Markdown；
- preview 使用 monospaced text view；
- 超长 prompt 只在 UI 层截断显示，复制时使用完整内容。

---

## 11. 持久化方案

### 11.1 Sidecar 文件

默认保存：

```text
example.md
example.review.json
example.prompt.md
```

### 11.2 保存路径

优先级：

1. 源 Markdown 同目录；
2. 如果同目录不可写，保存到应用数据目录；
3. UI 中提示用户当前保存位置。

### 11.3 自动保存

触发：

- 创建批注；
- 编辑批注；
- 删除批注；
- 切换 includeInPrompt；
- 修复锚点；
- 修改模板设置。

策略：

- 立即更新内存状态；
- 300-500ms debounce 写入磁盘；
- 写入使用临时文件 + 原子替换；
- 失败时保留内存状态并显示错误。

### 11.4 文件权限

如果启用 App Sandbox，需要处理：

- 用户通过 open panel 授权文件；
- 保存 security-scoped bookmark；
- 重启后恢复文件访问；
- bookmark 失效时请求用户重新定位。

---

## 12. 状态管理

### 12.1 AppState

全局状态建议保持少量、清晰。

```swift
@Observable
final class AppState {
    var currentDocument: MarkdownDocument?
    var reviewSession: ReviewSession?
    var readerSelection: ReaderSelection?
    var selectedNoteID: String?
    var promptPreview: PromptPreviewState
    var saveState: SaveState
    var panelMode: InspectorPanelMode
}
```

### 12.2 单向更新规则

推荐更新路径：

```text
User Action
  -> Feature Intent
  -> Store / Core Service
  -> AppState mutation
  -> UI render
```

不要让 Reader、Prompt、Persistence 互相直接调用。通过 AppState 或 feature store 协调。

---

## 13. 性能要求

### 13.1 目标指标

| 场景 | 目标 |
|---|---|
| 打开 5 万字 Markdown | 3 秒内可阅读 |
| 选中文本后显示浮动按钮 | 150ms 内 |
| 保存批注 | 体感即时 |
| Prompt 预览刷新 | 200ms 内 |
| 滚动阅读 | 无明显卡顿 |

### 13.2 性能策略

- Markdown 解析放到后台任务；
- attributed string 构建可以后台完成，UI 更新回主线程；
- PromptBuilder 不重新读文件；
- note list 使用 lazy rendering；
- 长文档高亮避免全量重绘；
- 自动保存 debounce。

---

## 14. 错误与异常

### 14.1 打开失败

原因：

- 文件不存在；
- 权限不足；
- 非 UTF-8 或读取失败；
- 文件过大。

处理：

- 展示明确错误；
- 不清空当前文档；
- 最近文件中可移除失效项。

### 14.2 锚点失效

处理：

- note 状态变为 `anchor_lost`；
- 卡片显示 `定位需确认`；
- Prompt 中标记定位不确定；
- 用户可以重新选择文本绑定 note。

### 14.3 保存失败

处理：

- 内存中的批注不丢失；
- 状态栏显示保存失败；
- 提供另存位置；
- 再次保存成功后清除错误状态。

### 14.4 无有效批注

处理：

- Prompt 预览显示空状态；
- 复制按钮置灰；
- 不生成空 Prompt。

---

## 15. 测试方案

### 15.1 单元测试

必须覆盖：

- Markdown outline 解析；
- SourceMap range 映射；
- TextAnchorResolver 恢复逻辑；
- QuickPrompt 插入规则；
- PromptBuilder 模板输出；
- Sidecar JSON 读写；
- note id 生成；
- includeInPrompt 过滤。

### 15.2 集成测试

核心流程：

1. 打开 Markdown；
2. 解析大纲；
3. 创建批注；
4. 保存 `.review.json`；
5. 关闭并重新打开；
6. 批注恢复到原位置；
7. 复制 Prompt。

### 15.3 UI 测试

覆盖：

- 选中文本后出现 `批注 +`；
- 点击后弹出添加批注框；
- 快捷提示插入文本；
- 保存后右侧新增卡片；
- 关闭 include 开关后 Prompt 预览移除对应 note；
- 顶部和右侧复制按钮可用。

### 15.4 测试样本文档

需要准备：

- 简单中文 PRD；
- 超长 Markdown；
- 包含代码块的文档；
- 包含表格的文档；
- 标题层级复杂的文档；
- 修改后导致 anchor 轻微偏移的文档。

---

## 16. 开发里程碑

### M0 项目初始化

目标：

- 创建 macOS SwiftUI App；
- 建立目录结构；
- 配置 Swift Package；
- 建立基础 AppState；
- 搭出三栏空界面。

验收：

- App 可运行；
- 三栏布局符合 V4 基础结构；
- 能展示静态原型数据。

### M1 文档打开与 Markdown 渲染

目标：

- 打开 `.md` 文件；
- 渲染 Markdown 阅读区；
- 生成左侧大纲；
- 显示文档标题和状态栏。

验收：

- 可打开真实 Markdown；
- 大纲可点击跳转；
- 阅读区可滚动和选择文本。

### M2 选区与批注创建

目标：

- 监听文本选区；
- 显示 `批注 +` 浮动按钮；
- 打开添加批注弹框；
- 支持快捷提示插入；
- 创建 ReviewNote。

验收：

- 选中一句话后可创建批注；
- 右侧新增批注卡片；
- 正文出现批注标记。

### M3 持久化与锚点恢复

目标：

- 保存 `.review.json`；
- 重新打开文档恢复批注；
- 实现基础 AnchorResolver；
- 支持定位失效状态。

验收：

- 关闭重开后批注存在；
- 文档轻微变化后能恢复或提示需确认。

### M4 Prompt 生成

目标：

- 实现 PromptBuilder；
- 实现 Codex 文件修改模板；
- 右侧实时预览；
- 支持复制和保存 `.prompt.md`。

验收：

- 批注变化后 Prompt 更新；
- 复制到剪贴板内容完整；
- 保存 prompt 文件成功。

### M5 交互打磨

目标：

- 优化右侧面板；
- 完成分段控件；
- 完成编辑、删除、排除批注；
- 完成快捷键；
- 完成浅色和深色基础适配。

验收：

- V4 主流程全部可用；
- 没有独立批注管理弹窗；
- 没有独立 Prompt 生成弹窗。

### M6 稳定性与发布准备

目标：

- 性能优化；
- 错误处理；
- 文件权限；
- 单元测试；
- UI 测试；
- 打包签名准备。

验收：

- 5 万字文档可流畅阅读；
- 核心流程测试通过；
- 本地数据不会丢失。

---

## 17. 首版风险点

### 17.1 Markdown 渲染和原文映射

风险：

- 渲染后的文本和原始 Markdown 不是一一对应；
- 加粗、链接、列表编号、代码块会影响 offset；
- 跨 block 选择难以精确映射。

应对：

- V1 先保证 block 级稳定；
- 每条 note 保存 selectedText 和上下文；
- Prompt 中同时包含 selectedText、headingPath、context；
- 精确 offset 是增强信息，不作为唯一定位依据。

### 17.2 TextKit 高亮复杂度

风险：

- 手绘下划线和多段高亮实现成本较高；
- 选区、高亮、滚动同步容易出现边界问题。

应对：

- V1 使用 attributed string underline / background；
- 后续再做更精致的自定义绘制；
- 高亮绘制和数据存储解耦。

### 17.3 文件权限和自动保存

风险：

- macOS sandbox 下文件写入权限复杂；
- sidecar 保存失败会影响用户信任。

应对：

- 明确保存状态；
- 同目录不可写时自动落应用数据目录；
- 使用 security-scoped bookmark；
- 写入失败不丢内存状态。

### 17.4 Prompt 过长

风险：

- 批注过多或包含全文时 Prompt 超长；
- 预览性能下降。

应对：

- 默认不包含全文；
- 只包含选中文本和上下文；
- UI 预览可截断，但复制完整；
- 后续提供压缩模式。

---

## 18. V1 开发完成定义

V1 技术完成需要满足：

- 可以打开本地 Markdown；
- 可以渲染适合阅读的 Markdown；
- 可以选中文本并创建批注；
- 批注可以本地保存和恢复；
- 右侧面板可以管理批注；
- Prompt 预览实时更新；
- 可以复制 Codex 文件修改 Prompt；
- 可以保存 `.prompt.md`；
- 交互符合 V4，不出现独立批注管理弹窗或 Prompt 生成弹窗；
- 所有核心数据默认保存在本地。
