# MarkPrompt Reader Benchmark: Markdown Reader

日期：2026-06-26

## 资料来源与判断边界

主要参考：

- Markdown Reader 官网：https://md-reader.github.io/
- Markdown Reader 隐私政策：https://md-reader.github.io/privacy
- Markdown Reader GitHub 仓库：https://github.com/md-reader/md-reader
- Markdown Reader 默认主题仓库：https://github.com/md-reader/theme

公开页面明确说明 Markdown Reader 是 Chrome、Edge、Firefox 的 Markdown browser extension，可以打开本地与在线 Markdown，把内容渲染为 clean readable web pages，并支持 Mermaid、KaTeX、code highlighting、browser themes、fast navigation、live preview、auto-refresh、Custom CSS、reading width、typography、dark mode 等能力。隐私页说明本地 Markdown 默认在用户设备和浏览器中处理，不上传到 Markdown Reader servers；远程图片、链接和外部资源仍会由浏览器请求对应服务器。

公开页没有完整列出所有快捷键、原文预览入口、TOC 交互细节、emoji/sup/sub/abbr 的逐项插件开关。本文将这些能力按证据强度区分为：

- 明确：官网、FAQ、隐私页或仓库元数据直接说明。
- 推导：从 browser reader 形态、页面文案、截图类 alt 信息、默认主题仓库和常见 Markdown Reader 工作流推导。
- 待实测：需要安装扩展后验证具体 UI、快捷键或插件细节。

## 产品定位差异

Markdown Reader 的核心是浏览器 Markdown viewer：自动接管 `.md`、`.markdown`、README、CHANGELOG、在线 raw Markdown 等内容，把它们转换成漂亮的网页阅读体验。

MarkPrompt 的核心不是通用 Markdown viewer，也不是完整编辑器，而是本地优先的 macOS Markdown 审稿工具。MarkPrompt 中间阅读区必须服务于：

- 可选择文本；
- 可创建批注；
- rendered text 到 source Markdown 的锚点映射；
- 高亮恢复；
- include/exclude 与 `anchor_lost` 状态；
- PromptBuilder 生成可执行修改 Prompt；
- `.review.json` sidecar 持久化。

因此 MarkPrompt 适合吸收 Markdown Reader 的阅读版式、基础 Markdown 呈现、TOC 导航、隐私与本地处理原则；不适合照搬浏览器扩展权限、网页脚本渲染、Custom CSS 完全开放和 WebView 型插件生态。

## 功能清单、优先级与实现建议

| Markdown Reader 能力 | 证据 | MarkPrompt 是否需要 | 优先级 | 原生 macOS 实现建议 | 锚点/选择/Prompt 风险 |
|---|---|---:|---|---|---|
| 本地 Markdown 打开 | 明确。官网 FAQ 提到拖拽、`file://`、`.md`/`.markdown`、README、CHANGELOG | 需要 | V1 | 保持 `NSOpenPanel`、Finder 打开、拖拽文件，继续由 `DocumentLoader` 读取本地文本 | 低。现有 source hash 和 sidecar 流程匹配 |
| 在线 Markdown 打开 | 明确。官网提到 direct Markdown URL、raw README URL | 暂不作为核心 | V2 | 可增加“从 URL 临时打开”并保存为本地缓存副本，仍由本地 parser 渲染 | 中。远程内容无稳定本地路径，sidecar 命名、隐私和 hash 生命周期需设计 |
| clean readable page | 明确 | 需要 | V1 | TextKit 使用居中正文宽度、舒适行高、段距、标题层级、浅/深色动态 NSColor | 低。只改 attributes 和 container inset 时风险可控 |
| 居中阅读宽度 | 明确。官网提 Custom CSS 可调 reading width，页面主题也体现居中布局 | 需要 | V1 | `NSTextView` 全宽承载，`textContainerInset.width` 按列宽计算，把正文限制到约 720-780pt | 低。不要改成图片/HTML，避免破坏 selection |
| 自动 TOC / 多级目录导航 | 推导。官网提 fast navigation，Markdown reader 常见模式；MarkPrompt 已有 outline | 需要 | V1 | 继续用 `OutlineBuilder` 生成左栏树，点击后通过 rendered heading range 滚动 | 中。点击跳转不能清空用户选区或引发 scroll reset |
| 当前章节高亮 | 推导 | 需要 | V1.5 | 已监听 `NSScrollView` visible range，经 TextKit character location 推导当前 heading，只更新左侧 outline 高亮状态，并用 `ScrollViewReader` 让目录自动跟随当前章节 | 中。滚动监听需持续去重，避免 SwiftUI warning、跳动或选区丢失 |
| ATX / Setext headings | 基础 Markdown | 需要 | V1 | 已支持 `# Heading` 与 `Heading` + `===/---` 两种标题语法；标题正文走 inline 渲染，大纲标题隐藏常见 inline marker | 中。Setext source range 覆盖两行，点击目录和批注 anchor 需映射到同一 heading block |
| live preview / auto-refresh | 明确 | 有选择支持 | V1.5 | 用 file presenter / dispatch source 监听文件变化，提示或自动重新解析；默认保守刷新 | 高。重新解析会改变 rendered ranges，需要先解析、resolve anchors、保留 scroll/selection |
| 浅色 / 深色主题 | 明确 | 需要 | V1 | 使用动态 `NSColor.labelColor`、`textBackgroundColor`、`controlBackgroundColor`，避免硬编码单色 | 低。attributes 更新不应重置 text storage |
| 自定义 CSS | 明确 | 不照搬 | V2 或不做 | 原生端改成有限“阅读设置”：字体大小、正文宽度、行高、代码主题 | 高。任意 CSS 不适用于 TextKit，也可能破坏可选文本和锚点稳定性 |
| Typography 设置 | 明确/推导 | 需要有限支持 | V1.5 | 阅读设置面板提供 body font size、monospace size、line height | 中。font size 变化会影响 scroll position，但不应影响 rendered text |
| GFM 基础支持 | 明确/推导 | 需要 | V1 | 保持 `swift-markdown` 解析入口，行扫描补齐表格、task list、strikethrough | 中。GFM 扩展渲染后 plain text 改变时，旧 anchor 需用 source range/text fallback |
| 表格 | 明确 | 需要 | V1 | TextKit V1 使用 `NSTextTableBlock` 渲染 native text table；宽表在单一 `NSTextView` 中自动换行；GFM separator 允许小幅列数漂移，避免真实报告表退回 raw pipe 文本；后续可评估 per-table horizontal scrolling | 中。AppKit 子视图表格会破坏连续文本选择；TextKit text block 相对更稳，但仍需持续实测 selection/anchor |
| task lists / list continuations | 明确 | 需要 | V1 | `- [x]`/`- [ ]` 渲染为可选文本 checkbox marker；有序列表保留作者起始编号和 `10)` 这类 CommonMark marker；紧贴缩进续行和空行后的缩进段落并入同一个 list block，并对齐到 item 正文 | 中。续行并入会扩大 list source range；需确保选区仍映射回 list/task/ordered block，而不是 loose paragraph，也不能误吞后续普通段落 |
| blockquotes | 基础 Markdown/阅读器常见 | 需要 | V1 | 已用 TextKit block border/background 渲染引用块；支持 marked blank line、多段引用、普通段落型 lazy continuation 和 nested `> >` marker 的可读缩进 | 中。lazy continuation 只并入普通段落行，避免误吞 heading/list/table/code 等后续结构；仍以 blockquote source range 回落 |
| footnotes | 明确 | 需要基础支持 | V1 | footnote definition 渲染为紧凑脚注块，inline reference 做 baseline offset | 中。脚注跳转暂缓，避免滚动和选区互相打架 |
| definition lists | Markdown-it/扩展阅读器常见 | 需要基础支持 | V1.5 | 已支持 `Term` + `: definition` 的紧凑原生 TextKit 展示，term 加粗、definition 缩进并隐藏冒号控制标记 | 中。控制标记隐藏会改变 rendered range；仍以 block source map 回落，避免破坏批注恢复 |
| GFM callouts / alerts | GitHub/现代 Markdown 阅读器常见 | 需要基础支持 | V1.5 | 已支持 `> [!NOTE]` / `> [!WARNING]` 等 blockquote callout，隐藏控制标记并显示 readable label 与 colored border | 中。仍作为 blockquote block 参与 source map；不做可折叠/交互式 alert |
| hard line breaks | 基础 Markdown/阅读器常见 | 需要 | V1 | 已支持行尾两个空格和行尾反斜杠，把段落内 hard break 渲染为真实换行；普通软换行仍合并为空格 | 中。段落内 rendered text 出现 `\n` 会改变 selectedText 形态，anchor 仍依赖 block source map 和文本 fallback |
| emoji | 明确/扩展语法 | 需要基础支持 | V1.5 | macOS 字体支持 Unicode emoji；已对白名单短码如 `:rocket:`、`:warning:`、`:white_check_mark:` 做基础转换 | 低到中。短码转换会改变 rendered text；当前不做完整 emoji 插件词库 |
| superscript/subscript | 明确/扩展语法 | 需要基础支持 | V1.5 | 已用 TextKit baseline offset 支持有限语法 `^text^`、`~text~` | 中。语法转换会改变 plain text 和 selection length；目前不覆盖完整 markdown-it 扩展集合 |
| abbreviations | 待实测 | 需要基础支持 | V1.5 | 已支持 `*[API]: ...` 定义行隐藏，并对正文缩写加 dotted underline 与 tooltip；不改变正文 rendered text | 中。NSTextView tooltip 与 selection/highlight 叠加需要处理，定义行隐藏后旧 range 需依赖 source map fallback |
| inline bold/italic/code/link/strikethrough | 明确/基础 Markdown | 需要 | V1 | 正则或 AST span 转 NSAttributedString attributes，plain text 只去掉成对 Markdown marker；普通 `API_TOKEN`、`snake_case`、`2 * 3` 等技术文本保持原样；backslash escaped marker 如 `\*literal\*` 显示为字面 `*literal*` 且不触发样式 | 中。inline marker 去除会让 source/rendered 非一一对应，需要 block source map fallback；marker 清理必须避免误删真实正文字符；转义符号隐藏后 selectedText 与源码长度会不同 |
| reference-style links/images | 基础 Markdown/常见长文档写法 | 需要 | V1 | 已支持 `[label][id]`、`[label][]`、`![alt][id]`，定义行从阅读流隐藏；链接保持 TextKit `.link`，图片沿用本地预览/远程占位策略 | 中。定义行隐藏和 label 替换会改变 rendered/source 偏移；未解析 reference 保留原文以避免内容消失 |
| mark/insert inline 扩展 | 推导自 Markdown-it/Markdown Reader 扩展生态 | 需要基础支持 | V1.5 | 已支持 `==mark==` 黄色背景和 `++insert++` 插入下划线，仍保持 TextKit 可选文本 | 中。定界符去除会改变 rendered range；当前只处理单行非空内容，避免误伤比较符号和 `C++` |
| HTML entity 解码 | 基础 Markdown/HTML 阅读预期 | 需要基础支持 | V1 | 在剥离真实 inline HTML tag 后解码常见 named/numeric entities，如 `&amp;`、`&lt;`、`&#9731;` | 中。解码会改变 rendered length；必须通过 source map 与 anchor fallback 兜底 |
| 安全 inline HTML 样式 | 浏览器/Markdown Reader 阅读预期 | 需要基础 fallback | V1.5 | 已对 `<kbd>`、`<mark>`、`<ins>`、`<del>`、`<sup>`、`<sub>`、`<small>` 做 TextKit 属性渲染，不执行 HTML | 中。只支持单行文本内容；标签去除后 source/rendered 非一一对应，依赖 block source map 和 anchor fallback |
| 安全 inline HTML 语义 | 浏览器/Markdown Reader 阅读预期 | 需要基础 fallback | V1.5 | 已对 `<a href>` 添加 TextKit `.link`/tooltip，`<br>` 渲染为段落内真实换行，`<img src alt>` 渲染为可选择文本占位并保留 URL linkify；不执行 HTML、不下载远程图片 | 中。HTML 标签去除会改变 rendered range；图片不作为真实媒体插入，避免网络请求和不可选内容破坏批注锚点 |
| HTML table fallback | 浏览器/Markdown Reader 常见兼容行为 | 需要基础支持 | V1.5 | 已对简单静态 `<table><tr><th>/<td>` 解析为 native `NSTextTableBlock`，复用表格列宽、边框和 inline 渲染管线 | 中到高。必须避免执行 HTML、加载资源或误吞未闭合 table；source map 以整块 table 回落 |
| 代码块语言标签 | 明确/推导 | 需要 | V1 | 从 fence info string 提取 language，在 code block 顶部显示轻量 label | 低到中。新增 label 改变 code block rendered range，需依赖 source range fallback |
| indented code blocks | 基础 Markdown/旧文档常见 | 需要 | V1 | 已支持 4 空格或 tab 缩进代码块，移除前 4 列代码缩进并复用 native TextKit code block 样式 | 中。只在块级位置识别，避免抢走 list continuation；深层缩进需保留以便代码 selectedText 准确 |
| 代码块语法高亮 | 明确 | 需要基础架构 | V1.5 | 已接入按语言分流的轻量 TextKit regex highlighter，覆盖 Swift/JSON/YAML/Shell/Diff/Mermaid 等常见审稿块；V2 可替换为 Tree-sitter 或 Splash | 中。只改 attributes 风险低；插入 token 文本风险高 |
| Mermaid diagrams | 明确 | 有限支持 | V1.5/V2 | 已对简单 `flowchart` 链式图生成轻量原生动态 `NSImage` 预览附件，跟随浅色/深色 appearance，并保留 Mermaid 源码块；复杂 Mermaid 仍走源码 fallback，V2 再接更完整 renderer | 高。图像不可选，必须保留源码作为 anchor 主体，不能用 WebView |
| KaTeX / LaTeX 数学 | 明确 | 有限支持 | V1.5/V2 | inline math 已有 compact token；block math 对常见 `\int`、`\frac`、上下标做轻量原生动态 preview attachment，跟随浅色/深色 appearance，并保留 LaTeX 源码块；V2 再评估完整公式 renderer | 高。公式图形化会牺牲文本选择和 Prompt 精确引用，必须保留源码作为 anchor 主体 |
| 图片预览 | 明确/浏览器默认 | 需要基础策略 | V1/V1.5 | 已对存在的本地块级图片生成 TextKit thumbnail 附件，并保留 alt/url 可选文本；远程块级图片默认不请求网络，继续显示文本占位；段落内 direct/reference Markdown 图片显示为 `Image: alt (url)` 可选择文本，HTTP URL 继续 linkify | 中到高。附件会影响 glyph range、selection rect 和 anchor text，因此必须保留文本 anchor 主体；行内图片暂不插附件以避免扰乱段落行高和 selection rect |
| 媒体预览 | 推导 | 不作为核心 | V2 或不做 | 保留链接占位；不内嵌音视频播放器 | 高。审稿工具不应承担媒体播放器复杂度 |
| 原文预览 | 待实测 | 有价值但非 V1 | V1.5 | 增加只读 source preview toggle 或右侧 debug popover；不改主阅读区 | 中。用户在 source preview 选区与 rendered selection 的映射需明确 |
| 快捷键 | 待实测 | 需要 MarkPrompt 自己的 | V1.5 | `Cmd+O`、创建批注、切换 Prompt/批注、跳转下一个批注等 | 低到中。快捷键调用 AppState 时避免发布循环 |
| 隐私与本地渲染 | 明确 | 需要 | V1 | 保持本地文件读取、本地 sidecar、本地 Prompt 生成；不上传内容 | 低。远程图片/URL 功能必须提示网络请求 |
| 浏览器扩展权限 | 明确 | 不适合 | 不做 | 不需要 `file://` extension permission、tab permission、extension storage | 无。macOS app 权限模型不同 |
| 浏览器安装/商店/账号/Pro | 明确 | 不适合当前产品 | 不做 | MarkPrompt 不引入账号、订阅、浏览器商店分发逻辑 | 无到低。会稀释本地审稿定位 |

## MarkPrompt V1 阅读区目标

V1 应做到：

- 正文居中，阅读宽度舒适，而不是铺满中间列；
- body、heading、blockquote、code、table 的行高、间距、字体层级清楚；
- ATX 和 Setext 标题都进入大纲与阅读区，标题中的 inline marker 不裸露；
- 支持浅色/深色基础动态色；
- inline bold、italic、inline code、link、strikethrough、mark、insert；
- 普通星号/下划线技术文本内容保真，例如 `API_TOKEN`、`snake_case`、`2 * 3` 不应被 inline marker 清理误删；
- Markdown backslash escape 内容保真，例如 `\*literal\*`、`\[not link](...)`、`\![not image](...)` 应显示为字面语法而不触发样式、链接 label 或图片 fallback；
- reference-style links/images 定义隐藏与正文链接化；
- 段落内 Markdown 图片保留 alt 与 URL 信息，作为可选择文本占位而不是只剩 alt；
- 常见 HTML entity 在阅读态解码；
- `<kbd>`、`<mark>`、`<ins>`、`<del>`、`<sup>`、`<sub>` 等安全 inline HTML 标签做原生属性 fallback；
- `<a href>`、`<br>`、`<img src alt>` 做安全 inline HTML 语义 fallback，保留链接、换行和图片 URL 信息但不执行 HTML 或请求远程图片；
- 简单 HTML table 使用原生 TextKit table fallback；
- abbreviation 定义隐藏与正文 tooltip 提示；
- GFM callout marker 隐藏并展示 readable label；
- Markdown hard line break 保留为段落内真实换行；
- task list、list continuation、definition list、footnote definition、本地图片缩略预览与远程图片占位；
- 表格可读，有边框、有列对齐；
- 代码块显示语言标签；
- 选区、批注浮动按钮、右侧卡片跳转不引发顶部跳回；
- 不把主阅读区替换成 WebView、不可选图片或 SwiftUI Text 拼块。

## V1.5 建议

- 文件变更监听和保守 live preview：检测到原 Markdown 改动后提示刷新，确认后解析、resolve anchors、保持 scroll origin；
- 当前章节高亮和 outline 自动跟随基础版已接入；后续继续实测真实窗口中的滚动节奏、长文档性能和目录跟随是否过于频繁；
- 阅读设置：字体大小、阅读宽度、行高、代码字号；
- 代码高亮 provider 抽象：先保留轻量 regex，后续替换为更可靠 engine；
- 本地图片缩略图：占位文本始终保留，图片作为附加预览，不作为唯一内容；
- 原文只读预览：用于排查 source mapping 和辅助 Prompt，不进入编辑器定位。

## V2 建议

- Mermaid：已对简单 flowchart 做轻量原生动态预览；复杂图仍保留源码块，后续再评估完整 renderer；预览不可作为 anchor 主体；
- KaTeX/LaTeX：已对常见 block math 做轻量动态 preview；复杂公式仍保留源码，后续再评估完整公式 renderer；
- 更完整 GFM/Markdown-it 插件兼容层：需要在 AST/source map 层设计，不应只用正则堆叠；
- URL 打开：引入缓存文件、来源提示、网络隐私提示和 sidecar 命名策略；
- 高级 typography/theme：有限配置，不做任意 CSS 注入。

## 不适合 MarkPrompt 直接照搬的能力

- WebView/HTML/CSS 渲染主阅读区：会让 NSTextView selection、glyph range、批注高亮、source map、PromptBuilder 全部复杂化。
- 任意 Custom CSS：TextKit 不是 CSS box model，开放 CSS 会导致不可控布局差异。
- 浏览器扩展权限与自动接管网页：MarkPrompt 是本地 macOS app，不应监听用户浏览器页面。
- 账号/Pro/远程服务绑定：当前目标是本地优先审稿工具。
- Mermaid/KaTeX 直接图像替代源码：图像不可选择，anchor 无法稳定落在正文文本上。
- 完整 Markdown 编辑器：会把精力从审稿批注和 Prompt 生成移走。

## 风险分析

### 批注锚点

阅读区变漂亮时最容易破坏的是 rendered plain text。MarkPrompt 的 anchor 当前依赖 `selectedText`、`sourceRange`、`renderedRange`、heading path、context before/after 和 document hash。任何去除 Markdown marker、新增语言标签、合并段落、替换 task marker 的行为，都可能让旧 `renderedRange` 不再精确。

控制策略：

- 继续保持 block-level source map；
- 旧 hash 命中但 rendered range 文本不一致时，回退到 source range 所在 block 内搜索 selectedText；
- 避免把可审稿正文换成附件、图片或多控件拼装；
- 对新增渲染能力补测试，确保 selectedText 仍出现在 renderedPlainText。

### 文本选择

NSTextView 是 MarkPrompt 的核心资产。表格、图片、Mermaid、KaTeX 如果以 AppKit 子视图或图片替代文本，会破坏跨块选择、selection rect 和批注按钮定位。

控制策略：

- V1 表格使用 TextKit native text table，避免宽表字符边框换行错位；
- V1 图片使用文本占位；
- V2 图表/公式以“源码文本 + 预览附件”的双轨方式做；
- 批注按钮锚定可见选区片段并在视口内左右避让，避免长选区和边缘选区把入口推离阅读上下文；
- render signature 覆盖 TextKit table block、段落样式、链接和附件，避免只看纯文本导致旧表格样式残留；
- selection-only update 不重设 textStorage，不重排 layout。

### 滚动体验

SwiftUI 状态发布和 TextKit layout 容易互相影响。风险点包括选区变化清空 scroll target、右侧卡片选中触发 highlight 更新、TextView 宽度变化导致 frame height 重算。

控制策略：

- 只有 render 或 highlight signature 变化时更新 textStorage；
- 只有 render 或 width 变化时更新 layout；
- explicit scroll target 被消费后异步清空；
- selection 相同值不重复发布；
- visible heading 相同值不重复发布，只更新 outline 高亮，不改 text storage；
- 无 explicit target 时恢复 scroll origin。

### Prompt 生成

PromptBuilder 应继续读取 source Markdown 和 review session，而不是读取渲染视图。渲染增强只能影响用户选择和 anchor resolution，不应改变 Prompt 模板语义。

控制策略：

- `ReviewNote.anchor.selectedText` 保留用户选择的 rendered text；
- `sourceRange` 可用时用于更稳定定位；
- `anchor_lost` 状态继续进入 Prompt warning；
- include/exclude 不和视觉高亮耦合。

## 本轮实现映射

本轮 V1 已覆盖：

- 阅读区正文宽度收窄到更舒适的 reader 宽度；
- body、heading、blockquote、code、table 间距与字体优化；
- ATX/Setext heading 渲染与大纲同步；
- inline bold、italic、inline code、link、strikethrough、mark、insert；
- 普通 `_` / `*` 技术文本保真，不把非 Markdown marker 当控制符删除；
- backslash escaped inline marker 显示为字面符号，不误触发 emphasis/link/image；
- reference-style links/images 定义隐藏、链接属性和本地 reference 图片预览；
- 段落内 direct/reference Markdown 图片安全文本占位；
- 常见 HTML entity 解码；
- 安全 inline HTML 标签属性 fallback；
- 安全 inline HTML 链接、换行和图片文本占位 fallback；
- 简单 HTML table 原生表格 fallback；
- abbreviation 定义隐藏与正文 tooltip 提示；
- GFM callout / alert 基础展示；
- Markdown hard line break；
- task list 与列表缩进续行可读展示；
- definition list 基础展示；
- footnote definition 和 inline reference 基础展示；
- 本地图片缩略预览，且保留图片 alt/url 文本占位；
- 表格改用 `NSTextTableBlock`，提供 native border、padding、表头底色与单元格自动换行；
- code fence 语言标签；
- 按语言分流的轻量代码语法高亮架构；
- selection/scroll target 的无效发布减少；
- textStorage 更新时保留选区；
- 新增 Markdown 渲染测试覆盖。
