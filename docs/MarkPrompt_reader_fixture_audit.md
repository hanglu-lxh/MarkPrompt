# MarkPrompt Reader Fixture Audit

日期：2026-06-27

本轮新增 `samples/markdown/reader-fixtures/` 下 10 份 Markdown fixture，用来持续检查 MarkPrompt 中间阅读区是否接近 Markdown Reader 的阅读体验，同时不破坏 TextKit 文本选择、批注锚点、高亮和 PromptBuilder 流程。

## Fixture 覆盖

| 文件 | 覆盖场景 | 关键检查 |
|---|---|---|
| `01_headings_inline.md` | H1-H6、Setext H1/H2、heading inline、段落、hard line breaks、bold、italic、inline code、link、strikethrough、mark、insert、superscript、subscript、emoji shortcode、abbreviation、Obsidian tag、literal `_`/`*`/`#`/URL/abbreviation 技术文本、backslash escaped marker | inline marker 不应直接露出，heading inline marker 不应裸露，hard break 保留段落内真实换行，code span 使用中性 token 样式且其中的 `#literal`、URL 和缩写文本不被误当作 Obsidian tag、可点击链接或 abbreviation hint，mark/insert 使用原生属性，上下标使用 TextKit baseline offset，常见 emoji shortcode 转 Unicode，abbr 定义行隐藏且正文缩写带 tooltip，`API_TOKEN`/`snake_case`/`2 * 3` 等普通文本不得被 marker 清理误改，`\*literal\*`、`\[not link](...)`、`\![not image](...)` 等转义符号应显示为字面 Markdown 语法且不触发样式/链接/图片 fallback |
| `02_lists_tasks.md` | unordered/ordered/task/nested lists、ordered start numbers、parenthesized ordered markers、Obsidian custom task statuses、任意非空 task status、indented list continuations、loose list paragraphs、list/definition list Obsidian image embed | 紧凑列表节奏、task marker、有序列表保留作者起始编号和 `10)` marker、Obsidian 常见自定义 task 状态不暴露源码 marker，未定制的非空 task 状态回退为完成态 checkbox，TextKit 嵌套缩进、续行和空行后的列表内段落对齐到 item 正文并保留 source block，列表与 definition list 内本地图片 embed 应显示预览且保留可选 fallback |
| `03_tables_wide.md` | 宽表、窄表、对齐分隔线、表格内 Obsidian image embed | 使用 native TextKit table，不再用字符画边框；表格 cell 内本地图片 embed 应显示预览、短 fallback，并保持表格 source map |
| `04_code_blocks.md` | Swift/JSON/Shell/YAML/Diff fenced code、indented code block | 自然语言标签、浅底代码块、按语言分流的基础语法高亮；4 空格缩进代码块应复用同一 TextKit code block 阅读样式 |
| `05_quotes_footnotes.md` | blockquote、lazy blockquote continuation、nested blockquote marker、GFM/Obsidian callout、nested Obsidian callout、footnote、footnote continuation、blockquote Obsidian image embed | TextKit 引用块、普通段落型 lazy continuation 保持在引用块内、嵌套 `> >` 不暴露原始 marker 且有缩进、callout label 与 colored border、嵌套 callout marker 不暴露且保留缩进、轻量脚注、续行并入 footnote block，引用内本地图片 embed 应显示预览且保留可选 fallback |
| `06_images_links.md` | local/remote image、inline image、regular link、reference-style link/image、autolink、bare URL、Obsidian PDF/audio/video embed fallback | 本地块级图片缩略预览、远程块级图片占位、段落内 direct/reference Markdown 图片显示为可选择文本占位、reference 定义隐藏、autolink 属性；PDF/audio/video embed 应显示类型标签、短文件名/alias，并用 tooltip 保留完整 target |
| `07_math_mermaid_fallback.md` | inline/block math、Mermaid | inline math 使用紧凑公式 token，block math 有轻量公式预览且保留 LaTeX 源码，简单 Mermaid flowchart 有原生预览且保留源码 |
| `08_long_outline.md` | 多级长大纲 | outline 数量、layout 稳定、可见位置到当前章节高亮的推导 |
| `09_frontmatter_html.md` | YAML frontmatter、HTML block fallback、HTML table fallback、inline HTML fallback、HTML link/br/img fallback、thematic break | metadata 轻量块、HTML block 安全 fallback、简单 HTML table 原生表格、`kbd/mark/ins/del/sup/sub/small` 原生 inline 属性、`a href` 链接属性、`br` 段落内换行、`img` 安全文本占位、原生分隔线 |
| `10_review_prd_mix.md` | 综合 PRD 审稿流 | task/table/footnote、Obsidian wikilink 与 Markdown-format internal link、inline/standalone block id、note embed fallback、`.md#anchor` 与 percent-encoded target 显示清理混合渲染 |

## 自动化检查

新增 `ReaderFixtureRenderingTests`：

- fixture 数量必须为 10；
- 每份 fixture 都能被 `MarkdownParser` 解析；
- 每份 fixture 都能在 760pt 和 520pt TextKit 宽度下完成 offscreen layout；
- rendered text 不再包含 `┌` / `└` 字符画表格边框；
- 宽表必须生成 `NSTextTableBlock`；
- task list、nested list、footnote continuation、autolink、bare URL linkify、HTML readable fallback、frontmatter properties、Mermaid fallback 等关键预期必须成立；
- 表格内部选中的 rendered text 必须能映射回 table block 的 source range。
- code、image、metadata、math fallback 等块级内容必须带 TextKit text block 样式，而不是只像普通段落。
- `ReaderFixtureSnapshotTool` 可生成浅色和深色两套 10 份 fixture PNG，并在 `metrics.json` 中记录 `appearance`，用于实际视觉复核主题适配。
- 长大纲 fixture 会检查 TextKit 可见位置能映射到正确 heading id，作为当前章节高亮的数据层回归。
- HTML inline fallback 会检查 `<a href>` 不暴露标签且保留 `.link` 属性、`<br>` 变成段落内真实换行、`<img>` 不联网而是保留可选择 URL 占位。

## 本轮实测发现并修复的问题

1. 宽表字符画边框在窄阅读宽度下会换行错位。
   - 修复：改为 `NSTextTableBlock` native TextKit table，提供 border、padding、表头底色和单元格自动换行。

2. 嵌套列表丢失缩进层级。
   - 修复：`parseListItem` 保留 leading whitespace 并输出基础缩进。

3. footnote definition 的缩进行续行被当成普通段落。
   - 修复：新增 `collectFootnoteDefinition`，把缩进行合并进同一个 footnote block。

4. Markdown autolink `<https://...>` 露出尖括号且没有 link 属性。
   - 修复：inline 渲染时去掉尖括号并添加 `.link`、下划线和蓝色前景色。

5. 文档开头 YAML frontmatter 被渲染成分隔线和正文。
   - 修复：识别开头 `--- ... ---` frontmatter，渲染为轻量 Properties 块。

6. 简单 HTML fallback 直接露出 `<aside>`、`<kbd>` 等标签。
   - 修复：inline fallback 中剥离安全范围内的简单 HTML 标签，保留其文本内容。

7. 裸 URL 仅作为普通文本显示。
   - 修复：对 rendered text 中的 `https?://...` 添加 `.link`、下划线和链接颜色。

8. 表格内选区是否能回到源 Markdown 未被覆盖。
   - 修复：新增 fixture 检查，确认表格单元格文本的 rendered range 可映射回 table block source range。

9. `$$...$$` block math 被当普通段落渲染。
   - 修复：新增 `mathBlock` block kind，把 block math 渲染为 `Formula` fallback 块，去掉外层 `$$`。

10. 代码、图片、metadata、公式 fallback 的背景色只贴在字形后面，不像阅读器块。
    - 修复：增加 TextKit `NSTextBlock` paragraph style，提供块级背景、边框和 padding，同时保持文本可选择。
    - 二次修复：给 `NSTextBlock` 明确 100% 宽度和浅色/深色动态背景，确保真实绘制为整块阅读器样式。

11. 真实宽表虽然已进入 native table，但 8 列内容在 760pt 内仍会把短表头拆成竖向字符。
    - 修复：表格字体改为阅读态系统小号字体，按内容权重分配列宽，数字列右对齐，长文本列在单元格内自然换行。
    - 修复：宽表推荐宽度上限放宽到 880pt；阅读容器在窄面板中可扩到表格推荐宽度并由 `NSScrollView` 承载，普通正文仍以 760pt 为基准。
    - 验证：`ReaderFixtureSnapshotTool` 生成的 `03_tables_wide.png` 不再露出 Markdown 管道符和分隔线，表头完整度明显优于等分列宽版本。

12. 代码块语言标签显示为 `language: swift`，更像内部调试文本而不是阅读器标签。
    - 修复：fenced code 语言显示为 `Swift`、`JSON`、`Bash`、`Mermaid` 等自然标签；代码主体仍是 monospaced 可选择文本。
    - 验证：`04_code_blocks.png` 中代码块具备浅底、边框、padding、自然语言标签和基础语法高亮。

13. 列表 item 之间间距过大，嵌套层级主要依赖前导空格，长文档里会显得松散。
    - 修复：列表改为专门的 attributed string 构建路径，去掉前导空格布局，使用 paragraph indent 表达嵌套层级。
    - 修复：列表行距和段后距收紧，task checkbox marker 使用独立颜色和字重。
    - 验证：`02_lists_tasks.png` 高度从 1481 降到 1271，嵌套 child item 由 TextKit 缩进控制。

14. blockquote 使用可见 `┃` 字符模拟竖线，选中文本时会把装饰符一起选入。
    - 修复：引用正文不再插入 `┃`，改用 `NSTextBlock` 100% 宽度、浅底和左侧 3pt border 表达引用块。
    - 修复：脚注字号和段落间距收紧，续行仍保持在同一个 footnote block 内。
    - 验证：`05_quotes_footnotes.png` 显示为原生引用块，rendered text 不再包含 `┃`。

15. HTML block fallback 被当作普通段落，用户看不出这是未执行的安全 fallback。
    - 修复：新增 `htmlBlock` block kind；块级 HTML 不执行、不使用 WebView，只剥离标签并显示为 `HTML` fallback 块。
    - 验证：`09_frontmatter_html.md` 的 `<aside>...</aside>` 生成独立 `htmlBlock`，内容可选择，source map 仍指向原 HTML block。

16. thematic break 使用 `────────────` 字符串显示，像正文中的装饰文本且宽度不自然。
    - 修复：thematic break 改为 100% 宽度 `NSTextBlock` 分隔线，rendered text 不再包含横线字符。
    - 验证：`09_frontmatter_html.png` 显示为整行浅分隔线，块后正文继续正常排版。

17. inline code 使用亮粉色前景，像代码块语法高亮泄漏到正文里，阅读时过于抢眼。
    - 修复：inline code 改为中性前景色、浅色/深色动态背景和略小号 monospaced 字体，作为 compact token 显示。
    - 验证：`01_headings_inline.png` 中 `inline code` 不再是粉色高亮，仍保持可选择文本和 inline rendered range。

18. 之前只有浅色 fixture 快照，无法系统验证 Markdown Reader 式深色阅读体验。
    - 修复：`ReaderFixtureSnapshotTool` 新增 `--appearance light|dark` 参数；默认保持浅色输出不变，深色输出可写入 `docs/assets/reader-fixture-snapshots-dark/`。
    - 验证：已生成 10 份深色 fixture 快照并人工复核 `01_headings_inline`、`03_tables_wide`、`04_code_blocks`、`09_frontmatter_html`，inline code、表格、代码块、HTML fallback 和分隔线在深色背景下均保持可读。

19. 真实中文长表仍可能退化为源码表格，尤其是“模型/开发方/参数量/架构/开源协议/最低显存/发布时间”这类多列报告表。
    - 修复：新增真实中文模型总览表回归测试，断言其生成 `NSTextTableBlock`，并且 rendered text 不再包含 `|------|` 或 `| **FLUX...` 等 Markdown 表格源码。
    - 验证：对 `AI_图像生成模型_开源闭源全面对比报告_2026.md` 额外生成离屏快照，识别到 19 个 table block；`2.1 模型总览表` 显示为原生带边框表格。

20. footnote reference 和 definition 仍暴露 `[^id]` 源码标记，阅读态不够像 Markdown Reader。
    - 修复：按首次引用顺序为脚注编号，正文引用显示为紧凑上标数字，定义区显示为 `1. ...` / `2. ...`，同时续行仍归入同一个 footnote block。
    - 验证：`05_quotes_footnotes.md` 和 `10_review_prd_mix.md` 不再暴露 `[^local-first]`、`[^anchor]`、`[^mix]` 源码标记。

21. GFM table separator 的 `:---` / `:---:` / `---:` 对齐声明没有被保留，表格只能靠内容猜测数字列右对齐。
    - 修复：`collectTable` 在丢弃 separator 源码显示前提取列对齐信息，并传给 native `NSTextTableBlock` 的 paragraph alignment。
    - 验证：新增单测直接检查 left/center/right 三种声明落到 TextKit paragraph style；`|:---|---:|` 这类表格不再只依赖数字列推断。

22. 表格单元格里的 inline Markdown 被提前 `stripInlineMarkdown` 洗平，`**bold**`、`[link](...)`、``code``、`~~strike~~` 无法在 native table 中保留阅读态样式。
    - 修复：`collectTable` 保留 cell 原始 inline Markdown；表格测宽使用显示文本，绘制 cell 时复用 inline attributed 渲染管线。
    - 验证：`03_tables_wide.md` 加入 bold/link/inline code/strikethrough cell；测试确认源码标记不暴露，且 bold font、`.link`、inline code background、strikethrough 属性都存在于 `NSTextTableBlock` 内。

23. inline math 仍以 `$E = mc^2$` 源码形式出现在正文中，阅读态不够接近 Markdown Reader。
    - 修复：新增保守 inline math 识别，只处理明显公式形态的 `$...$`，去掉美元定界符并以 compact formula token 样式显示。
    - 风险控制：价格文本如 `$19.99/month`、`$0.04 per render` 不满足公式模式，继续按普通正文保留。
    - 验证：`07_math_mermaid_fallback.md` 更新 inline math 和价格场景；新增测试确认公式不暴露 `$...$` 定界符、价格不被误伤，并且公式 token 有独立背景样式。

24. Markdown Reader 支持的 superscript/subscript 扩展语法此前仍按源码显示，如 `x^2^`、`H~2~O`。
    - 修复：新增有限的 `^text^` 和 `~text~` 识别，渲染时去掉定界符，用 TextKit baseline offset 和小号字体表达上下标。
    - 风险控制：`~~strike~~` 不会被 subscript 规则拆开；inline math 中的 `mc^2` 不会被误判为 superscript。
    - 验证：`01_headings_inline.md` 加入 `H~2~O` / `x^2^`，测试确认 rendered text 为 `H2O` / `x2`，并分别带负/正 baseline offset。
    - 附带修复：inline 样式定位从“搜索 inner text”改为“Markdown 源前缀映射 display range”，避免多个 inline marker 都包含相同文本时样式落到第一个匹配位置。

25. emoji shortcode 仍按源码显示，如 `:rocket:`、`:warning:`，没有接近 Markdown Reader 的扩展语法体验。
    - 修复：新增白名单短码转换，覆盖 `:rocket:`、`:sparkles:`、`:warning:`、`:white_check_mark:` 等常见审稿/文档符号。
    - 风险控制：只替换完整 `:name:` 白名单，不做全量词库和 fuzzy 匹配，避免误伤普通冒号文本。
    - 验证：`01_headings_inline.md` 和 `03_tables_wide.md` 加入 emoji shortcode，测试确认正文和 native table cell 中源码短码不暴露，Unicode emoji 正常出现。

26. HTML entity 仍按源码显示，如 `&amp;`、`&lt;`、`&#9731;`，阅读态不像 Markdown Reader，也会让表格单元格显得像原文预览。
    - 修复：在剥离真实 inline HTML tag 后解码常见 named entity 与 decimal/hex numeric entity，正文和 native table cell 共享同一条 inline display text 路径。
    - 风险控制：解码发生在 HTML tag stripping 之后，避免把 `&lt;kbd&gt;` 先还原成真实 tag 再误删；不引入 WebView 或不可选择附件。
    - 验证：`01_headings_inline.md` 加入 `A &amp; B &lt; C`，`03_tables_wide.md` 加入 `Selection &amp; anchor`；测试确认 rendered text 显示为 `A & B < C`、`Selection & anchor` 和 `☃`，源码 entity 不暴露。

27. 代码块高亮没有语言上下文，YAML、Diff、Shell、Mermaid 和 Swift/JSON 共用一套规则，审稿中常见配置 diff 看起来仍偏普通纯文本。
    - 修复：code block 高亮入口接收语言标签；新增 YAML key、Diff added/deleted/hunk、Shell 变量/注释、Mermaid keyword 等保守规则，并识别 `diff`/`patch` fence 为 `Diff` 标签。
    - 风险控制：只改 TextKit foreground attributes，不插入额外文本，不改变 code block source range；代码主体仍是可选择 monospaced 文本。
    - 验证：`04_code_blocks.md` 增加 YAML 与 Diff block；测试确认 `YAML`、`Diff` 自然标签出现，fence 源码不暴露，YAML key/string 和 Diff added/deleted/context 行使用不同 foreground color。

28. 本地图片和远程图片都只有文本占位，距离 Markdown Reader 的图片阅读体验仍有明显差距。
    - 修复：`MarkdownParser` 将 Markdown 文件目录传入 renderer；存在的本地图片会生成缩放后的 TextKit thumbnail 附件，同时保留 `Image: alt` 和原始路径文本。
    - 风险控制：远程 URL 不自动下载，避免本地优先审稿工具悄悄发网络请求；图片附件只作为预览，alt/url 文本仍是可选择、可映射回 image block 的 anchor 主体。
    - 验证：`06_images_links.md` 的本地图片路径改为真实存在的 workspace 相对路径；测试确认本地图片和 reference 本地图片都会生成 `NSTextAttachment`，本地 alt 文本和远程图片 URL 都能通过 source map 回到 `.image` block。

29. abbreviation 扩展语法没有阅读态支持，`*[API]: ...` 这类定义要么会被当普通段落显示，要么正文里的缩写没有任何提示。
    - 修复：扫描 `*[term]: definition` 定义行并从阅读流隐藏；段落、引用、列表和表格 cell 的 inline 渲染会给匹配缩写加 dotted underline 与 `.toolTip`。
    - 风险控制：不把 definition 插入正文，缩写本身仍保持原始 rendered text，减少批注 selectedText 和 PromptBuilder 的漂移风险；link 样式在后续应用，避免缩写样式覆盖链接下划线。
    - 验证：`01_headings_inline.md` 加入 `API` abbreviation；测试确认 rendered text 不包含 `Application Programming Interface` 定义行，正文 `API` 保持可选并带 tooltip 和 dotted underline。

30. Mermaid 只有源码 fallback，距离 Markdown Reader 的 diagram 阅读体验仍有距离。
    - 修复：对简单 `flowchart TD` / `graph` 链式图生成轻量原生 `NSImage` 预览附件，节点和箭头由 AppKit 绘制；源码块仍完整显示并继续走 TextKit 语法高亮。
    - 风险控制：只覆盖简单 flowchart，复杂 Mermaid 不猜测渲染；预览只是辅助，源码文本仍是可选择、可映射回 `.codeBlock` 的 anchor 主体，不使用 WebView。
    - 验证：`07_math_mermaid_fallback.md` 继续保留 Mermaid 源码；测试确认文档新增 1 个预览 attachment，`flowchart TD` 有 code block 样式，源码行 `A[Open Markdown] --> B[Select Text]` 可映射回 `.codeBlock`。

31. block math 虽然有 `Formula` fallback，但仍只是源码块，距离 Markdown Reader/KaTeX 的公式阅读体验较远。
    - 修复：为常见 LaTeX block math 生成轻量原生 `NSImage` 公式预览，支持 `\int`、`\frac`、数字上下标和少量常见符号转换；原始 LaTeX 源码仍完整显示。
    - 风险控制：不尝试完整 KaTeX 兼容，不隐藏源码；预览只是辅助，源码文本仍是可选择、可映射回 `.mathBlock` 的 anchor 主体。
    - 验证：`07_math_mermaid_fallback.md` 的 `\int_0^1 x^2 dx = \frac{1}{3}` 现在生成公式 preview attachment；测试确认 math+Mermaid 共 2 个 attachment，LaTeX 源码行可映射回 `.mathBlock`。

32. 公式和 Mermaid 预览附件最初是固定浅色 bitmap，在深色阅读模式里虽然可读但不像原生 dark reader。
    - 修复：预览附件改为 AppKit 动态绘制 `NSImage`，绘制时读取当前 drawing appearance，并使用独立浅色/深色 preview palette。
    - 风险控制：只改变附件绘制，不改变 rendered text、source map、源码 fallback 或批注 anchor 主体；仍不使用 WebView。
    - 验证：`07_math_mermaid_fallback.md` 的两个预览 attachment 均使用 `NSCustomImageRep` 动态绘制；浅色/深色快照可分别复核主题适配。

33. 左侧大纲只有点击瞬间高亮，滚动阅读时无法像 Markdown Reader 一样提示当前章节。
    - 修复：`NSScrollView` bounds 变化时由 TextKit 计算当前可见 character location，再通过 heading render ranges 推导当前 heading id；`AppState` 去重保存 `currentReadingHeadingID`，左侧 outline 显示稳定的当前章节指示条。
    - 风险控制：滚动事件只异步发布 heading id，不修改 text storage，不清空 selection，不设置 scroll target；点击 heading 仍走显式 scroll target，消费后异步清空。
    - 验证：新增 AppState 测试确认 visible heading 更新不改变 selection / scroll target / document hash；`08_long_outline.md` fixture 测试确认可见位置能映射到正确 heading。

34. 当前章节高亮后，长文档滚动到后半段时左侧目录可能仍停在旧位置，缺少 Markdown Reader 式目录跟随。
    - 修复：左侧大纲改为 `ScrollViewReader`，每个 heading row 使用稳定 heading id；`currentReadingHeadingID` 变化时只滚动 outline 自己到当前章节附近。
    - 风险控制：目录跟随发生在左栏 ScrollView，不设置正文 scroll target，不影响正文 selection、批注按钮或 TextKit 布局。
    - 验证：`swift build` 覆盖 SwiftUI API 与 target 兼容性；数据层已有当前章节推导和 AppState 去重测试。

35. 选区很长、贴近视口边缘或跨复杂块时，`批注 +` 浮动按钮容易贴边或远离当前可见选区。
    - 修复：批注按钮定位抽成 `annotationButtonRect`，优先锚定可见选区片段右侧，右侧空间不足时转到左侧，并把按钮矩形夹在视口安全边距内。
    - 风险控制：只改变浮动按钮 overlay 坐标，不改变 selectedText、renderedRange、sourceRange、TextKit selection 或批注 anchor 持久化。
    - 验证：新增单测覆盖普通选区、靠右选区、靠底选区和超大选区，确认按钮保持在 viewport 内。

36. 运行中的阅读区可能保留旧的普通文本表格样式，即使新的 renderer 已经生成 `NSTextTableBlock`。
    - 修复：`MarkdownTextViewRepresentable` 的更新判断从纯字符串比较改为 render signature，签名覆盖文本、段落样式、TextKit table block、链接、附件和 inline 样式结构。
    - 风险控制：批注高亮仍单独用 highlight signature 判断；selection-only update 不会重写 text storage，表格结构变化才触发布局更新。
    - 验证：新增单测确认同样的可见字符串在变成 native table block 后签名不同；对真实 `AI_图像生成模型_开源闭源全面对比报告_2026.md` 重新生成离屏快照，确认 `2.1 模型总览表` 为原生表格而非源码管道表格。

37. Markdown Reader 类阅读器常见的 `==mark==` 和 `++insert++` inline 扩展此前会按源码显示，阅读态仍像原文预览。
    - 修复：新增保守单行 mark/insert 识别，渲染时去掉定界符；mark 使用动态黄色背景，insert 使用动态绿色前景和下划线。
    - 风险控制：只添加 `NSAttributedString` 属性，不插入附件或子视图；`C++` 等没有成对定界符的文本不会被转换，批注仍选择真实 rendered text。
    - 验证：`01_headings_inline.md` 加入 `==highlighted decisions==` 和 `++inserted wording++`；核心 inline 测试与 fixture 测试确认源码标记不暴露，背景和下划线属性存在。

38. inline HTML 此前只是剥离标签保留文字，`<kbd>`、`<mark>`、`<sub>` 等阅读态不像 Markdown Reader/浏览器渲染。
    - 修复：新增安全 inline HTML 属性 fallback，覆盖 `<kbd>` keycap、`<mark>` 高亮、`<ins>/<u>` 插入下划线、`<del>/<s>` 删除线、`<sup>/<sub>` 上下标和 `<small>` 次要文本。
    - 风险控制：不执行 HTML、不加载外部资源、不使用 WebView；只处理单行文本内容，仍保留 selectable TextKit 文本和 block source map fallback。
    - 验证：`09_frontmatter_html.md` 扩展 inline HTML 场景；核心 parser 测试和 fixture 测试确认标签不暴露，并且背景、下划线、删除线、上下标和次要前景属性存在。

39. GFM/现代 Markdown reader 常见的 `> [!NOTE]`、`> [!WARNING]` callout 此前会把控制标记原样显示为普通引用文本。
    - 修复：blockquote 收集阶段识别 NOTE/TIP/IMPORTANT/WARNING/CAUTION marker，渲染为 readable label，并按类型设置 TextKit 左边框颜色。
    - 风险控制：callout 仍是 `.blockquote` block，不引入折叠控件或 SwiftUI 子视图；正文文本仍可选择，source map 仍指向原始引用块。
    - 验证：`05_quotes_footnotes.md` 加入 NOTE/WARNING；核心 parser 测试和 fixture 测试确认 `[!NOTE]` / `[!WARNING]` 不暴露，label 加粗着色，正文可映射回 blockquote source range。

40. 表格 cell splitter 在增强全角竖线/Unicode 横线兼容时没有在分隔符后清空当前 cell，可能导致后续列文本累积、列对齐错误，真实中文宽表更容易退化出源码感。
    - 修复：统一 `tableCells` 分割逻辑，支持 `｜`、常见 Unicode 横线和 `\|` 单元格内竖线；每次遇到表格分隔符后立即清空当前 cell。
    - 风险控制：仍渲染为连续 TextKit `NSTextTableBlock`，不引入 AppKit 子表格视图；转义竖线只影响 cell 内显示，不破坏整块 source map。
    - 验证：新增宽容表格单测覆盖全角竖线、em dash separator、右对齐和 escaped pipe；`03_tables_wide.md` 加入中文“模型/开发方/参数量/架构/开源协议/最低显存/发布时间”表，fixture 测试确认不再暴露 `| 模型`、`|------|`。

41. Markdown Reader/markdown-it 生态中常见的 definition list 此前没有完整接入，枚举已加入但渲染 switch 未补齐，会导致编译失败或冒号控制标记泄漏。
    - 修复：识别 `Term` + `: definition` 结构，渲染为 term 加粗、definition 缩进的原生 TextKit 文本块，并保留 inline code/bold/link 等属性处理。
    - 风险控制：definition list 作为单独 `.definitionList` block 参与 source map；不使用子视图或图片化渲染，选中文本仍能映射回原始块。
    - 验证：`02_lists_tasks.md` 加入 definition list；核心 parser 和 fixture 测试确认冒号标记不暴露，`anchors` inline code 背景存在，definition 文本可映射回 `.definitionList`。

42. Setext heading (`Heading` + `===/---`) 是基础 Markdown 语法，但此前不会进入左侧大纲，阅读区也容易把标题行当普通段落、把 underline 当分隔线。
    - 修复：`OutlineBuilder` 增加 Setext heading lookahead；阅读区把 Setext 渲染为 `.heading` block，source range 覆盖标题和 underline 两行；标题文本走 inline attributed 渲染。
    - 风险控制：只处理单行标题 + underline 的保守形态；真正独立的 `---` 仍作为 thematic break；heading block 仍是连续 TextKit 文本，不引入子视图。
    - 验证：`01_headings_inline.md` 加入 Setext H1/H2 与 heading inline code/link；核心 parser 和 fixture 测试确认大纲标题隐藏 marker，rendered text 不暴露 `===/---` underline，标题选区可映射回 `.heading`。

43. 长文档常见的 reference-style link/image 此前会把 `[label][id]` 和定义行原样显示，图片也无法走本地预览策略。
    - 修复：扫描 `[id]: destination "title"` 定义并从阅读流隐藏；段落、标题、列表、引用、表格和 definition list 的 inline 渲染支持 `[label][id]` 与 `[label][]`；独立图片行支持 `![alt][id]`。
    - 风险控制：只解析 full/collapsed reference，不启用 shortcut `[label]`，避免误伤普通方括号文本；未解析 reference 保留原文；图片仍保留 alt/url 文本主体，本地预览只是附件。
    - 验证：`06_images_links.md` 加入 reference link、collapsed reference 和 reference 本地图片；核心 parser 和 fixture 测试确认定义行不暴露、链接属性存在、本地 reference 图片生成附件且选区仍能映射回 `.image` block。

44. 列表项的缩进续行此前会脱离列表块，渲染成 loose paragraph，阅读节奏不像 Markdown Reader，也会让批注 source block 落在段落而不是原列表。
    - 修复：`collectList` 识别紧跟 list item 的缩进非空续行，并入当前 list block；渲染时续行不显示 bullet，但使用 TextKit paragraph indent 对齐到 item 正文。
    - 风险控制：只处理缩进续行，不吞掉 heading、table、definition list、image、footnote、HTML block、blockquote、math block、thematic break 或新的 list item；不实现完整 loose list，以降低误吞后续段落的风险。
    - 验证：`02_lists_tasks.md` 加入普通列表续行、task 续行和 nested child 续行；核心 parser 与 fixture 测试确认续行 marker/原始空格不暴露，inline link/code 属性保留，选区分别映射回 `.unorderedList` 和 `.taskList` block。

45. 空行后的缩进列表内段落此前仍会断开成普通段落，长 README/PRD 中的解释性列表读起来不连续。
    - 修复：在 list item 后遇到空行时，只有下一行仍满足缩进续行规则才并入同一个 list block；该 loose 段落使用额外段前距，视觉上比紧贴续行更像 Markdown Reader 的列表内段落。
    - 风险控制：空行后若是普通未缩进段落、下一个 list item 或其他块级结构，列表立即结束；未实现列表内嵌表格/代码块，避免把复杂块错误归入 list source range。
    - 验证：`02_lists_tasks.md` 加入普通 list 与 task list 的 loose paragraph；核心 parser 测试确认 loose paragraph 映射回 `.unorderedList`，后续未缩进 `Outside paragraph` 仍映射为 `.paragraph`。

46. 简单 HTML table 此前会退化为普通 HTML fallback 文本，阅读态看不到表格边框和列结构。
    - 修复：在 generic HTML fallback 前识别闭合的 `<table>`，提取静态 `tr/th/td` cell 文本，并交给现有 `NSTextTableBlock` 表格渲染管线；script/style 内容被丢弃。
    - 风险控制：不执行 HTML、不加载外部资源、不使用 WebView；只有找到闭合 `</table>` 且至少两列时才升级为 native table，未闭合或复杂 HTML 仍回到安全 HTML fallback。
    - 验证：`09_frontmatter_html.md` 加入 HTML table；核心 parser 和 fixture 测试确认 `<table>/<td>` 标签不暴露，生成 native TextKit table，`HTML table fallback` 选区映射回 `.table` block。

47. 段落内 Markdown hard line break 此前会被 `collectParagraph` 合并成普通空格，地址、诗句或手工换行说明不像 Markdown Reader。
    - 修复：段落收集保留行尾两个空格和行尾反斜杠两种 hard break 信号；hard break 渲染为段落内真实 `\n`，普通软换行仍合并为空格。
    - 风险控制：只影响 paragraph block 内部拼接，不新增子视图或 block kind；行尾反斜杠会从 rendered text 隐藏，source map 仍覆盖原始段落。
    - 验证：`01_headings_inline.md` 加入反斜杠 hard break；核心 parser 测试同时覆盖两个空格和反斜杠 hard break，并确认普通软换行仍合并为空格。

48. 浏览器/Markdown Reader 会自然渲染的 `<a href>`、`<br>`、`<img>` 此前只会被安全剥离标签，链接语义、换行和图片信息容易丢失。
    - 修复：inline HTML fallback 新增安全语义转换：`<a href>` 显示 label 并添加 TextKit `.link`/tooltip，`<br>` 保留为段落内真实换行，`<img src alt>` 显示为 `Image: alt (url)` 文本占位。
    - 风险控制：不执行 HTML、不加载远程图片、不使用 WebView；HTML 图片只是可选择文本占位，URL 仍可通过现有 bare URL linkify 获得链接属性，paragraph source map 不变。
    - 验证：`09_frontmatter_html.md` 加入 HTML link/br/img；核心 parser 和 fixture 测试确认标签不暴露，HTML link 与 image URL 有 `.link` 属性，`Next HTML line...` 选区仍映射回 `.paragraph` block。

49. inline marker 清理此前在最后阶段全局删除 `*` 和 `_`，会把普通技术文本如 `API_TOKEN`、`snake_case`、`a_b_c`、`2 * 3` 改写掉，严重影响阅读内容保真和批注 selectedText。
    - 修复：`stripInlineMarkdown` 改为只移除成对的 Markdown emphasis marker；下划线 italic 采用更保守的非单词边界规则，避免匹配 snake_case 内部；`applyInlineStyle` 写属性前确认目标 display range 与匹配文本一致，防止 false positive 样式落偏。
    - 风险控制：仍支持 `**bold**`、`*italic*`、`_italic_` 等基础样式；普通星号/下划线保留为真实正文，不改变 source map 或 block 类型。
    - 验证：核心 parser 测试加入 `API_TOKEN`、`snake_case`、`a_b_c`、`2 * 3` 并确认未被改写；`01_headings_inline.md` fixture 加入同类文本，fixture 测试确认 rendered text 保真。

50. 段落内 Markdown 图片此前会退化成纯 alt 文本，`![Build badge](https://...)` 里的 URL 信息丢失，阅读态不像 Markdown Reader，也不利于批注和 Prompt 指向具体资源。
    - 修复：inline Markdown 图片新增安全文本占位：direct image 和 reference-style image 都渲染为 `Image: alt (url)`；HTTP URL 继续通过现有 bare URL linkify 获得 `.link` 属性。
    - 风险控制：只处理段落内文本，不插入附件、不下载远程资源；块级图片仍沿用本地缩略图/远程占位策略，行内图片仍映射回 `.paragraph` block。
    - 验证：`06_images_links.md` 加入 direct inline badge 和 reference inline icon；核心 parser 与 fixture 测试确认源码图片语法不暴露，alt/url 均保留，HTTP 图片 URL 有 link 属性，选区可映射回 paragraph。

51. Markdown backslash escape 此前没有进入 inline 渲染模型，`\*not italic\*` 这类用户想显示字面 Markdown 符号的文本可能被误渲染成样式，或在阅读态残留反斜杠。
    - 修复：行内强调、删除线、mark/insert、上下标、link、reference link、inline image 的正则都忽略被反斜杠转义的起始符号；display text 最后只移除 Markdown 允许转义标点前的反斜杠。
    - 风险控制：不删除普通路径中的反斜杠；转义后的链接/图片语法保持字面文本，不触发 `.link` label 样式或 image fallback，URL 本身仍可能被现有 bare URL 策略识别。
    - 验证：核心 parser 测试加入 `\*literal asterisks\*`、`\_literal underscores\_`、`\[not link](...)`、`\![not image](...)`；`01_headings_inline.md` fixture 加入同类文本，测试确认反斜杠不暴露且不会误上 italic/link/image fallback。

52. 真实报告中的宽 GFM 表格如果掉回 raw pipe 文本，会出现类似源码表格在窄列中换行、横线和竖线错位的问题，阅读体验明显不符合 Markdown Reader。
    - 修复：表格起始识别从“表头列数必须完全等于 separator 列数”放宽为小幅列数漂移仍升级为 native table，并拒绝把 separator 行误当表头；标准真实报告表仍走同一 `NSTextTableBlock` 渲染路径。
    - 风险控制：只在表头和 separator 都至少两列时生效；渲染仍是连续 TextKit 文本表格，不引入 WebView、子视图或图片化表格，批注锚点仍以整块 `.table` source range 回退。
    - 验证：新增中文模型总览表 separator 列数漂移单测；对真实 `AI_图像生成模型_开源闭源全面对比报告_2026.md` 生成离屏快照，确认 `2.1 模型总览表` 为 native table block 而非 raw pipe 文本。

53. CommonMark/Markdown Reader 可读列表里常见的非 `1.` 起始编号和 `1)` marker 此前会被解析遗漏或统一改写成 `n.`，导致阅读态不保留作者编号语义。
    - 修复：`parseListItem` 支持 `\d+[.)]`，并把原始有序 marker 传到渲染层；`collectList` 不再重建 `n.`，`listMarkerRange` 也识别 `10)` 这类 marker 以保持列表 marker 样式。
    - 风险控制：仍使用 TextKit paragraph indent 和可选择文本，不引入原生 `NSTextList` 自动编号，避免 selection/plain text 与 source map 不可控漂移。
    - 验证：`02_lists_tasks.md` 加入 `3.` 起始和 `10)`/`11)` marker；核心 parser 与 fixture 测试确认 `10)` 不被规范化成 `10.`，并且选区仍映射回 `.orderedList` block。

54. CommonMark blockquote 支持 lazy continuation 和嵌套 `> >` marker，但此前 MarkPrompt 只吃连续 `>` 行，续行会掉成普通段落，嵌套引用会露出内部 `>`。
    - 修复：新增 blockquote 行解析器，支持多级 `>` marker；普通段落型 lazy continuation 会并入当前引用块，嵌套层级用 TextKit paragraph indent 表达，不再暴露原始 `>`。
    - 风险控制：lazy continuation 只接受普通段落行；heading、table、definition list、image、footnote、HTML、list、code fence、math 和 thematic break 都会停止引用，避免误吞后续结构块。
    - 验证：`05_quotes_footnotes.md` 加入 lazy continuation、多段引用和 nested quote；核心 parser 与 fixture 测试确认续行/嵌套文本仍映射回 `.blockquote`，nested 行缩进更深，inline emphasis 仍保留。

55. 旧 README 和纯 Markdown 文档常见的 4 空格 indented code block 此前没有块级入口，会被普通段落渲染，代码背景、monospace、source block 都不对。
    - 修复：新增 indented code block 起始判断和收集逻辑，移除每行前 4 列代码缩进，保留更深层缩进和块内空行，并复用现有 `.codeBlock` TextKit 背景/边框/语法高亮 fallback。
    - 风险控制：只在块级位置识别缩进代码；列表内缩进行仍由 `collectList` 处理，避免把 list continuation 误判为独立代码块。
    - 验证：`04_code_blocks.md` 加入 indented shell/code 示例；核心 parser 与 fixture 测试确认原始 4 空格不暴露、深层缩进保留、选区映射回 `.codeBlock`，并生成 full-width TextKit block。

56. 批注入口此前优先放在选区上方或下方，短选区会遮住邻近正文，长选区和靠边选区也没有利用选区侧边空隙，手感不像审阅工具的浮动批注入口。
    - 修复：`annotationButtonRect` 改为优先贴在可见选区右侧，右侧空间不足时转到左侧；两侧都不足时再回退到选区上方或下方，并继续夹在 viewport 安全边距内。
    - 修复：浮动入口文案统一为 `批注 +`，与空态提示保持一致，accessibility label 改为“添加批注”。
    - 风险控制：只改变 overlay 坐标和按钮文案，不修改 `selectedText`、`renderedRange`、`sourceRange`、TextKit selection 或批注持久化模型。
    - 验证：更新批注按钮定位单测，覆盖普通选区、靠右选区、靠顶/靠底选区、长选区、超大选区，以及两侧空隙不足时回退到上方；完整 `ReaderFixtureRenderingTests` 继续覆盖 10 份 fixture 和滚动后重发选区。

57. Obsidian 笔记库常见的 `[[wikilink]]`、`![[embed]]`、`#tag`、`%%comment%%` 和段末 `^block-id` 此前会按源码显示，阅读态不像 Obsidian，也会污染批注 selectedText。
    - 修复：inline 渲染新增 Obsidian Flavored Markdown 安全 fallback：内部链接显示为标题或 alias 并添加 `.link`/tooltip；嵌入显示为 `Embed: ...` 可选文本占位；nested tag 保留为带背景的轻量 token；comment 和段末 block id 在阅读态隐藏。
    - 风险控制：不解析 vault 文件、不内嵌其他 note 内容、不加载外部资源；embed 只做可选文本占位，内部链接使用本地 `obsidian://...` 标识，source map 仍回到原 paragraph block。
    - 验证：新增核心 parser 单测覆盖 wikilink、alias、embed、tag、comment、block id；`10_review_prd_mix.md` 加入 Obsidian review notes 综合场景；fixture 测试确认源码标记不暴露、内部链接和 token 属性存在、选区仍映射回 `.paragraph` block。
    - 实际运行：重新生成浅色和深色 `ReaderFixtureSnapshotTool` 10 份快照，人工抽查 `10_review_prd_mix.png`，确认 Obsidian 段落在两种 appearance 下可读，comment/block id 不显示。

58. Obsidian callout 支持的类型、别名、自定义标题和 `+/-` 折叠标记此前覆盖不足，`[!todo]+`、`[!faq]-`、`[!bug]` 等会裸露源码或把折叠符号带进标题。
    - 修复：callout parser 支持 Obsidian 常见类型与别名，包括 `todo`、`question/help/faq`、`bug`、`success/check/done`、`failure/fail/missing`、`danger/error`、`abstract/summary/tldr`、`quote/cite` 等；`+/-` 折叠标记被隐藏，自定义标题直接作为 readable title。
    - 风险控制：callout 仍然是 `.blockquote` block，继续使用 TextKit blockquote 样式和 source map，不引入折叠交互或 SwiftUI 子视图；正文仍保持可选择、可批注。
    - 验证：核心 parser 测试覆盖 `todo` 自定义标题、`faq` alias 和 `bug` 类型；`05_quotes_footnotes.md` 加入综合 callout 场景；fixture 测试确认源码标记/折叠符号不暴露，标题加粗着色，选区仍映射回 `.blockquote` block。
    - 实际运行：重新生成浅色和深色 `ReaderFixtureSnapshotTool` 10 份快照，人工抽查 `05_quotes_footnotes.png`，确认新增 callout 在两种 appearance 下可读。

59. Obsidian 多行 `%% ... %%` block comment 此前会先进入 paragraph/list/block 收集，尤其包含 list marker 或空行时会把 reviewer scratchpad 渲染出来，污染阅读态和批注 selectedText。
    - 修复：block 扫描阶段新增独立 Obsidian comment block 跳过逻辑；paragraph、list continuation 和 blockquote lazy continuation 遇到 comment 起始行会停止，让主循环负责隐藏整段 comment。
    - 风险控制：行内 `%%comment%%` 仍由既有 inline fallback 处理；跳过逻辑只针对以 `%%` 开头的独立 comment block，不改变可见正文的 source map block kind。
    - 验证：新增核心 parser 测试覆盖带 list marker 和空行的多行 comment；`10_review_prd_mix.md` 加入 reviewer-only TODO scratchpad；fixture 测试确认隐藏内容不出现在 rendered text，comment 后正文仍映射回 `.paragraph` block。

60. Obsidian inline footnote `^[...]` 此前会按源码显示，阅读态会把 reviewer context 直接混进正文和批注 selectedText。
    - 修复：inline 渲染新增 Obsidian inline footnote 支持，按全局脚注出现顺序替换为紧凑上标编号，并把 footnote 内容保存在 TextKit `.toolTip` 中。
    - 风险控制：不新增 footnote block、不把 inline footnote 内容追加到 rendered text；段落仍保持 `.paragraph` block，source map 仍覆盖原始 Markdown 段落，批注选区只拿到可见正文和上标。
    - 验证：新增核心 parser 测试覆盖 `^[...]` 不暴露、上标有 baseline offset 和 tooltip；`10_review_prd_mix.md` 加入 inline reviewer context，fixture 测试确认编号与普通脚注共用全局顺序，且选区仍映射回 `.paragraph` block。

61. Obsidian 图片 embed `![[local-image.png]]` 此前只显示为 `Embed: ...` 文本 token，距离 Obsidian Reading view 的图片预览仍有明显差距。
    - 修复：段落 inline 渲染在遇到本地图片型 Obsidian embed 时，会在 `Embed: ...` 可选文本前插入缩略图 `NSTextAttachment`；相对路径使用当前 Markdown 文件目录解析。
    - 风险控制：远程 URL、data URL、缺失文件和非图片 embed 仍保持安全文本 token；`Embed: ...` 文本继续保留，source map 仍回到原 `.paragraph` block，批注 anchor 不依赖图片附件。
    - 验证：新增核心 parser 测试覆盖本地 PNG embed 生成 1 个 attachment 且保留可选 fallback；`10_review_prd_mix.md` 将 embed 指向真实本地 PNG，fixture 测试确认附件存在、源码 embed 不暴露、fallback 可映射回 `.paragraph`。

62. Obsidian 图片 embed 尺寸语法 `![[local-image.png|220]]` 此前会被误当成 alias，阅读态显示 `Embed: 220`，图片仍按默认缩略图尺寸渲染，既不接近 Obsidian，也会破坏批注选区语义。
    - 修复：inline embed 解析区分展示 alias 与图片尺寸 alias；`220`、`220x120`、`220×120` 被视为预览尺寸，回退文本仍显示真实 target，非数字 alias 继续作为 readable title。
    - 风险控制：尺寸只影响本地图片 `NSTextAttachment` 的绘制尺寸，不改变远程/缺失/非图片 embed 的安全文本 token；尺寸值有上限，避免异常 Markdown 撑爆 TextKit 布局。
    - 验证：核心 parser 测试覆盖 `|220` 不暴露 `Embed: 220`、attachment 宽度约为 220px、fallback 仍映射回 `.paragraph`；`10_review_prd_mix.md` fixture 使用真实图片尺寸语法，fixture 测试覆盖同一路径。

63. Obsidian 图片 embed 此前只有普通 paragraph 路径能拿到当前文件目录，列表项和引用块中的 `![[local-image.png|180]]` 会退化成纯 `Embed: ...` token，没有预览，审稿证据图挂在 checklist/quote 下时阅读体验割裂。
    - 修复：list 和 blockquote 的 TextKit inline 渲染路径传递 `baseURL`，复用既有本地图片 preview、尺寸 alias 和 fallback 文本逻辑。
    - 风险控制：不改变 list/blockquote 收集、缩进、callout 或 source map 逻辑；附件仍插在可选 `Embed: ...` 文本前，批注 anchor 继续落在原 list/blockquote block。
    - 验证：核心 parser 测试覆盖 list item 与 blockquote 内两个本地图片 embed 生成 2 个 attachment，尺寸分别为 180px/160px，且不暴露尺寸 alias；`02_lists_tasks.md` 和 `05_quotes_footnotes.md` 加入真实 fixture，fixture 测试确认附件、source map 和源码隐藏都成立。

64. inline Obsidian 图片 embed 插入在句子中间时，`NSTextAttachment` 会和前置文字共享同一行 baseline，视觉上像图片压在文字上方，列表项和引用块里的审稿证据图尤其明显。
    - 修复：本地图片 embed preview 插入前会检查 fallback token 前是否已有同一行文本；如果有，则先插入换行，让图片作为独立预览行出现，再保留下一行 `Embed: ...` 可选 fallback。
    - 风险控制：纯行首 embed 不额外加空行；只调整 attachment 前的 display spacing，不改变源 Markdown、source map、尺寸 alias 或远程/缺失图片 fallback 策略。
    - 验证：核心 parser 测试覆盖 paragraph、list item、blockquote 中的图片 embed 字符串结构均为 `文字\n附件\nEmbed: ...`，防止回退到同一 baseline 布局；后续快照复核浅色/深色真实 fixture。

65. 图片 fallback `Embed: ...` 仍作为可选文本留在正文流中，后续普通句子会接在同一行，例如 `Embed: path should stay...`，阅读态不够像独立媒体块，批注 selectedText 也会混入不自然的行内拼接。
    - 修复：本地图片 embed fallback 后会把后续横向空白替换成换行；若后面紧跟句号、逗号、问号等标点，则标点保留在 fallback 行，后续正文从下一行继续。
    - 风险控制：只处理当前 display line 内的空白/轻量标点，不吞掉真实后续文本；行尾 embed 不额外加空行，远程/缺失图片仍保持原安全文本 fallback。
    - 验证：核心 parser 测试覆盖 `![[image]] continues` 和 `![[image]]. Next`，确认结构为 `文字\n附件\nEmbed: path\n正文` 与 `文字\n附件\nEmbed: path.\nNext`；fixture 测试覆盖列表项和引用块中的同类场景。

66. 本地图片 fallback 继续显示完整相对路径，例如 `Embed: ../../../docs/assets/markprompt_interaction_prototype_v4.png`，比 Obsidian Reading view 更嘈杂；批注 selectedText 也会带入很长的路径字符串，降低审稿摘要可读性。
    - 修复：只有在本地图片解析并成功生成 preview 时，把 fallback 文本降噪为短文件名，例如 `Embed: markprompt_interaction_prototype_v4.png`；完整 target 迁移到 tooltip，仍可作为批注定位和排查上下文。
    - 风险控制：远程 URL、data URL、缺失文件和非图片 embed 不进入该分支，继续显示原安全 fallback；source map 仍覆盖短 fallback 所在 block，列表/引用/段落中的批注锚点继续可回到源 Markdown。
    - 验证：核心 parser 测试覆盖本地图片、尺寸 alias、后续正文断行、列表和引用中的短 fallback；fixture 测试确认 `02_lists_tasks.md`、`05_quotes_footnotes.md`、`10_review_prd_mix.md` 的正文不再暴露长路径，tooltip 保留完整 target，source map 回查仍成立。

67. Obsidian callout 的 `+/-` 折叠状态此前被完全隐藏；虽然不再污染标题，但阅读态也看不出 `[!todo]+` 是默认展开、`[!faq]-` 是默认折叠，和 Obsidian Reading view 的 disclosure 心智不一致。
    - 修复：callout parser 保留折叠状态到渲染 attributes；TextKit 渲染第一行标题时用 `▾` 表示默认展开、`▸` 表示默认折叠，并在 glyph 上提供 tooltip，原始 `+/-` 仍不进入阅读文本。
    - 风险控制：不引入真实折叠交互或 SwiftUI 子视图，callout 继续是 `.blockquote` block；正文仍可选择、可批注，source map 仍回到原始引用块。
    - 验证：核心 parser 测试覆盖 `todo+` 与 `faq-` 的 disclosure glyph、tooltip 和源码 marker 隐藏；fixture 测试确认 `05_quotes_footnotes.md` 的两个 callout 标题显示 `▾/▸`，并保持标题颜色/blockquote source map。

68. Obsidian 允许自定义 callout type，未定制时会回退到 note 风格；此前 `[!review]`、`[!design-review]-` 这类审稿常用自定义 callout 会被当作普通引用，源码 marker 直接进入阅读文本和批注 selectedText。
    - 修复：callout parser 对未知 type 使用 `.note` 样式 fallback；无自定义标题时把 type identifier 转成 readable title（如 `review-check` -> `Review Check`），有自定义标题时继续优先展示自定义标题，并保留 `+/-` disclosure 状态。
    - 风险控制：不引入自定义 CSS 或 vault 主题解析；未知 callout 只改变阅读态 marker 隐藏和 note 样式 fallback，source map 仍是 `.blockquote`，正文仍可选择、可批注。
    - 验证：核心 parser 测试覆盖 `[!review]` 默认标题、`[!design-review]-` 自定义标题/折叠 glyph 和源码隐藏；`05_quotes_footnotes.md` fixture 加入 `[!review]- Needs reviewer follow-up`，fixture 测试确认源码不暴露且选区回到 blockquote。

69. Obsidian wikilink 到 heading 或 block 时，无 alias 的阅读文本此前会把 `#Review checklist` / `#^accepted` 截掉，只剩 note 名；批注 selectedText 会丢失具体跳转目标，阅读体验也不像 Obsidian 的 internal links。
    - 修复：`obsidianDisplayTitle` 保留无 alias wikilink 的 `#Heading` 和 `#^block-id` 部分，同时继续把路径目录折叠为 note 文件名；alias 仍优先作为显示文本。
    - 风险控制：不改变 `.link` target、tooltip、source map 或 vault 跳转策略；只修正可见文本，内部链接仍使用本地 `obsidian://...` 标识。
    - 验证：核心 parser 测试覆盖 `[[Prompt Quality#Review checklist]]`、`[[Decision Log#^accepted]]` 和带 alias 的 anchored link；`10_review_prd_mix.md` fixture 加入 heading/block anchor links，fixture 测试确认渲染文本、link attr 和 paragraph source map 均成立。

70. YAML frontmatter 此前被压成 `Metadata: key=value` 单行，既不像 Obsidian Properties，也会让批注 selectedText 混入源码式噪声；数组 tags 还会被压成普通逗号文本，缺少 token 化阅读感。
    - 修复：frontmatter summary 改为多行 `Properties` 块，key 以 title case 展示，列表值用可读间距展开；`Tags:` 行的值加轻量 token 背景与强调色，形成接近 Obsidian Properties 的阅读信号。
    - 风险控制：仍是轻量 YAML summary，不引入可编辑 properties 面板或完整 YAML parser；metadata source map 保持 `.metadata`，批注定位继续回到原 frontmatter block。
    - 验证：新增核心 parser 测试覆盖 `Properties` 前缀、title-cased key、tags token 背景和 `.metadata` source map；`09_frontmatter_html.md` fixture 测试确认不再暴露 `Metadata:`/`---`，并覆盖 tags token 样式。

71. Obsidian 本地图片 embed 已支持段落、列表和引用块，但 definition list 内 `![[image|150]]` 仍退化成长路径 fallback；术语解释里放审稿证据图时，阅读态割裂，批注 selectedText 也会带入完整路径。
    - 修复：definition list 渲染路径传递 `baseURL`，复用既有本地图片 preview、尺寸 alias、短 fallback 和 tooltip 逻辑。
    - 风险控制：不改变 definition list 收集规则、缩进样式或 source map；附件和短 fallback 仍处于 `.definitionList` block 内，批注 anchor 继续回到原定义块。
    - 验证：新增核心 parser 测试覆盖 definition list 内 150px 本地图片 preview、短 fallback、tooltip 和 `.definitionList` source map；`02_lists_tasks.md` fixture 加入真实 definition list 证据图，fixture 测试确认列表 180px 与定义 150px 两个附件都存在。

72. 表格 cell 内的 Obsidian 图片 embed 仍不能预览，且 `![[image|140]]` 的尺寸竖线会被表格 parser 当作列分隔符；审稿矩阵中放截图证据时，native table 会出现错列、长路径 fallback 和不可读 selectedText。
    - 修复：table cell splitter 识别 `[[...]]` 区间，不再把 Obsidian wikilink/embed 内部 `|` 当作表格分隔符；table renderer 传递 `baseURL` 到 inline renderer，复用本地图片 preview、短 fallback、尺寸 alias 和 tooltip。
    - 风险控制：仍保留 `NSTextTableBlock` 原生表格，不引入子视图；表格 source map 保持 `.table`，批注 anchor 继续落回整块 Markdown table。
    - 验证：新增核心 parser 测试覆盖表格内 140px 本地图片 preview、短 fallback、tooltip、native table 和 `.table` source map；`03_tables_wide.md` fixture 加入真实 evidence table，fixture 测试确认图片附件存在且不暴露长路径或源码 embed。

73. 非图片 Obsidian file embed 仍统一显示为 `Embed: ...`，PDF/audio/video 没有类型信号；带目录的 target 还会把长路径带进阅读文本和批注 selectedText。
    - 修复：按 target 扩展名给 PDF/audio/video 生成 `PDF:`、`Audio:`、`Video:` 类型 fallback；无 alias 时显示短文件名，有 alias 时显示 alias，完整 target 写入 tooltip。
    - 风险控制：不加载、不播放、不预览非图片媒体；仍是可选择的 TextKit inline token，source map 保持原段落，避免引入 WebView 或 AVKit 子视图打断批注选区。
    - 验证：新增核心 parser 测试覆盖 PDF/audio/video 三类 fallback、短文件名、alias、tooltip 和 paragraph source map；`06_images_links.md` fixture 加入真实组合场景，fixture 测试确认源码 embed 与长路径不暴露。

74. Obsidian note embed / excerpt `![[Review Appendix#Findings]]` 此前和未知文件一样显示为 `Embed: ...`；阅读态缺少“这是笔记引用”的信号，批注 selectedText 也容易带入泛化且含路径的占位文本。
    - 修复：无扩展名或 `.md` 的 Obsidian embed 改为 `Note: ...` 安全占位；alias 优先显示，未提供 alias 时保留笔记标题与 heading/block anchor，完整 target 写入 tooltip。
    - 风险控制：不加载 vault 文件、不做真实 transclusion、不解析 excerpt 内容；仍是可选择的 TextKit inline token，source map 保持原段落，避免跨文件内容影响批注 anchor。
    - 验证：新增核心 parser 测试覆盖 note embed、alias、anchor、tooltip、隐藏源码和 paragraph source map；`10_review_prd_mix.md` fixture 加入 review appendix 场景，fixture 测试确认不再显示 `Embed:` 或原始 `![[...]]`。

75. Obsidian 关闭 Wikilinks 后会用标准 Markdown link 表达内部链接，例如 `[review checklist](Prompt%20Quality.md#Review%20checklist)`；此前 MarkPrompt 虽然隐藏了 Markdown 源码，但 `.link` 仍是普通相对 URL，缺少和 `[[Prompt Quality#Review checklist]]` 一致的本地链接语义与 tooltip。
    - 修复：regular/reference/HTML link 共用的 link attribute 入口识别无 scheme 的 `.md` 目标和同文档 `#heading` / `#^block` 目标；解码 `%20`、去掉 `.md` 后复用 `obsidian://...` internal link 属性与 tooltip。
    - 风险控制：`https://`、`mailto:`、`file:` 等显式 scheme 不进入该分支，普通外部链接仍保持系统蓝色链接；只改 link attributes，不改变 rendered text、source map 或批注选区范围。
    - 验证：新增核心 parser 测试覆盖 `.md#heading`、嵌套目录 `.md#anchor`、same-note block anchor、外部链接不回归；`10_review_prd_mix.md` fixture 加入 Markdown-format internal link，fixture 测试确认 `.link`、tooltip 和 paragraph source map 均成立。

76. Obsidian Markdown-format internal link 还允许省略 `.md`，例如 `[Three laws](Three%20laws%20of%20motion)`；此前 MarkPrompt 只识别带 `.md` 的目标，无扩展名 note link 会退化成普通相对 URL，点击/tooltip 语义和 wikilink 不一致。
    - 修复：无 scheme、无文件扩展名的相对 Markdown link 也归一为 Obsidian note target；保留目录和 heading/block anchor，继续解码 `%20` 并复用 `obsidian://...` internal link 属性与 tooltip。
    - 风险控制：带显式 scheme 或非 Markdown 文件扩展名的目标不进入该分支，避免把 `https://...`、`diagram.png`、`brief.pdf` 误当 note；只改 link attributes，不改变 rendered text 或 source map。
    - 验证：扩展核心 parser 测试覆盖 extensionless note、extensionless anchored note、外部链接不回归；`10_review_prd_mix.md` fixture 加入 extensionless retro link，fixture 测试确认 `.link`、tooltip 和 paragraph source map 均成立。

77. Obsidian callout 支持嵌套 callout，但此前只有 blockquote 的第一行会解析 `[!type]` marker；`> > [!tip]- Nested reviewer hint` 会把 `[!tip]-` 源码显示在阅读态，污染批注 selectedText，也不像 Obsidian 的嵌套 callout。
    - 修复：blockquote 收集阶段对非首行的 nested callout marker 做安全 fallback，显示为带 `▾/▸` disclosure 的可读标题，并继续用现有 nesting prefix 驱动 TextKit 缩进；嵌套 disclosure glyph 也带默认展开/折叠 tooltip。
    - 风险控制：不创建真正的子 callout block、不增加折叠/展开交互、不改变 source map；嵌套内容仍作为同一个 `.blockquote` block 的可选择文本，批注 anchor 继续回到原引用块。
    - 验证：新增核心 parser 测试覆盖嵌套 `[!tip]-` marker 隐藏、`▸ Nested reviewer hint` 显示、缩进和 `.blockquote` source map；`05_quotes_footnotes.md` fixture 加入嵌套 callout，fixture 测试确认源码不暴露、tooltip/缩进/source map 均成立。

78. Obsidian 手工 block ID 除了段末 `^block-id`，也常以独占一行出现；此前空行分隔的 `^accepted-decision` 会被主 block 扫描当成普通 paragraph，阅读态和批注 selectedText 都会混入锚点源码。
    - 修复：block 扫描主循环新增 standalone Obsidian block ID 跳过逻辑；段末 block ID 仍沿用 inline 清洗，内部链接到 `#^block-id` 的可见文本和 `.link` 属性不受影响。
    - 风险控制：只跳过整行精确匹配 `^A-Za-z0-9_-` 的锚点行，不处理普通正文中的 caret 文本；source map 不新增空 block，后续可见段落仍保持原 paragraph source range。
    - 验证：新增核心 parser 测试覆盖空行分隔的 standalone block ID 隐藏、后续 `[[Decision Log#^accepted-decision]]` 链接保留；`10_review_prd_mix.md` fixture 加入独占 block ID，fixture 测试确认源码不暴露。

79. Obsidian wikilink 和 note embed 指向真实 Markdown 文件并带 heading/block anchor 时，`[[Research/Prompt Notes.md#Methods]]` / `![[Research/Review Appendix.md#Risks]]` 此前会把 `.md` 后缀带进可见文本，阅读态不够像 Obsidian，也会让批注 selectedText 混入文件扩展名噪声。
    - 修复：`obsidianDisplayTitle(from:)` 在生成可见标题时先取末级 note 名，再去掉大小写不敏感的 `.md` 后缀，最后拼回 anchor；`.link` 属性和 tooltip 继续保留原始 target。
    - 风险控制：仅调整显示标题，不改变 vault target、URL encoding、tooltip、source map 或 note embed 的安全 placeholder 策略；真实 vault 解析与 transclusion 仍不在本轮处理。
    - 验证：扩展核心 parser 测试覆盖 `.md#anchor` wikilink 与 note embed 的可见文本、link 和 tooltip；`10_review_prd_mix.md` fixture 加入 `.md#Risks` note embed，并确认不再暴露 `.md` 后缀或原始 `[[...]]` 源码。

80. Obsidian 链接或 embed 从 URI/Markdown link 复制过来时常包含 percent-encoded 空格，例如 `[[Research/Prompt%20Notes.md#Method%20Plan]]` 和 `![[Research/Review%20Appendix.md#Risk%20Map]]`；此前阅读态和 tooltip 会直接显示 `%20`，批注 selectedText 也会带入编码噪声。
    - 修复：新增 Obsidian target 的显示解码 helper，`obsidianDisplayTitle`、embed filename、internal link tooltip 和 embed tooltip 共用；可见文本显示为 `Prompt Notes#Method Plan` / `Note: Review Appendix#Risk Map`，内部 `.link` URL 仍统一输出为 encoded `obsidian://...`。
    - 风险控制：只处理 Obsidian target 的 percent decoding，不改变普通外链、Markdown-format internal link 识别、source map 或本地图片文件解析路径；无法解码的 target 继续按原字符串展示。
    - 验证：核心 parser 测试覆盖 encoded wikilink 与 encoded note embed 的显示、link 和 tooltip；`10_review_prd_mix.md` fixture 加入 encoded note embed，fixture 测试确认 `%20` 不进入 rendered text，tooltip/source map 仍成立。

81. Obsidian/Tasks 工作流里常见 `[-]`、`[/]`、`[!]` 等自定义 task 状态；此前这些行不会被识别成 task list，而是显示为普通列表正文 `• [-] ...`，阅读态不像 Obsidian，也会让批注 selectedText 混入源码 marker。
    - 修复：task marker 解析扩展为单字符状态，并将常见状态映射为静态阅读 glyph：`[-]` -> `☒`、`[/]` -> `◩`、`[!]` -> `⚠`；列表 marker 样式同步识别这些 glyph。
    - 风险控制：只做静态阅读态，不引入 checkbox 点击切换或状态写回；未知单字符状态仍以单字符 glyph 保留语义，source map 继续指向原 task list block。
    - 验证：核心 parser 测试覆盖自定义 task 状态不暴露源码 marker；`02_lists_tasks.md` fixture 加入 rejected/in-progress/important 三类任务，fixture 测试确认 rendered text 与 `.taskList` source map 均成立。

82. Obsidian tag styling 此前会在 inline code / kbd 等等宽 token 里继续匹配 `#literal`，例如 `` `#not-a-tag` `` 会被改成 tag token，代码语义被覆盖，也会让批注 selectedText 附近的视觉语义变混乱。
    - 修复：`applyObsidianTagStyle` 在应用 tag 属性前检查命中位置的字体；如果当前范围已经是 fixed-pitch inline code/kbd，就跳过 tag styling，真正的正文 `#reader/tag` 仍按 Obsidian tag token 显示。
    - 风险控制：只跳过已有等宽字体的 inline 范围，不改变 tag 匹配规则、code span 文本、source map 或普通正文 tag 的样式；代码块本身不走 inline tag styling。
    - 验证：核心 inline 测试覆盖 `#reader/tag` 与 `` `#not-a-tag` `` 同时出现时的样式区别；`01_headings_inline.md` fixture 加入同类场景，fixture 测试确认正文 tag 有 token 背景、code tag 保持 fixed-pitch。

83. bare URL / autolink linkify 此前会覆盖 inline code 里的 URL，例如 `` `https://example.com/code-url` `` 会带 `.link` 属性；同时 bare URL 匹配会把句末逗号等标点吞进链接范围，阅读交互和批注语义都不够像 Obsidian。
    - 修复：URL styling 应用前检查命中位置是否已有 fixed-pitch code 字体，code span 内 URL 不再 linkify；bare URL 也不会覆盖已有 autolink 属性，并在加 `.link` 前裁掉末尾常见标点。
    - 风险控制：正文 bare URL 和 `<https://...>` autolink 继续可点击；code span 文本仍保持原样，`<https://...>` 不再被当作 HTML tag 清掉；source map 不变。
    - 验证：核心 inline 测试覆盖正文 bare/autolink URL、code URL 和 code autolink 的链接属性区别；`01_headings_inline.md` fixture 加入正文 URL 与 code URL，fixture 测试确认正文 URL 可点击、code URL 保持 fixed-pitch 且无 `.link`。

84. abbreviation hint 此前会覆盖 inline code 里的缩写，例如 `` `API()` `` 会带 `Application Programming Interface` tooltip 和 dotted underline；代码 token 的语义被提示层打断，批注时也容易误判为正文缩写。
    - 修复：`applyAbbreviationStyle` 在应用 tooltip / dotted underline 前检查命中位置是否已有 fixed-pitch code 字体，code span 内缩写不再应用 abbreviation hint。
    - 风险控制：正文里的 `API design` 仍保留 tooltip 和 dotted underline；只跳过已有等宽字体范围，不改变 abbreviation 定义解析、source map 或普通正文匹配规则。
    - 验证：核心 abbreviation 测试覆盖正文 `API` 和 code `API()` 的属性区别；`01_headings_inline.md` fixture 加入 code `API()`，fixture 测试确认正文缩写有提示、code 缩写保持 fixed-pitch 且无 tooltip/underline。

85. Obsidian task list 允许 bracket 内任意非空字符表示 completed task；此前未定制状态如 `[a]` 会在阅读态直接显示为 `a Arbitrary...`，不像 checkbox，也会让批注 selectedText 混入源码状态字符。
    - 修复：`taskGlyph(for:)` 对未定制的非空 task marker 回退为完成态 `☑`；`[-]`、`[/]`、`[!]` 等已定制状态继续使用取消、进行中和重要 glyph。
    - 风险控制：只改变未知 marker 的可见 glyph，不改变 task block 解析、列表缩进、续行收集或 source map；`[ ]` 仍是未完成 checkbox。
    - 验证：核心 reader extension 测试加入 `[a] Arbitrary completed task`；`02_lists_tasks.md` fixture 加入 `[a] Arbitrary completed review task`，fixture 测试确认源码 marker 不暴露、可见文本是完成态 checkbox，且选区仍映射回 `.taskList`。

86. 完成态 task 此前只有 checkbox glyph 变成 `☑`，正文仍和未完成任务一样饱和；扫读 checklist 时 done / todo 层级不够清楚，也不够接近 Obsidian Reading view 的任务完成态。
    - 修复：list rendering 在识别到 `☑` marker 时，只给 marker 后面的任务正文添加单线 strikethrough；checkbox glyph 本身仍保持原有颜色和字重。
    - 风险控制：只作用于 `☑` 行正文，不影响 `☐` 未完成、`◩` 进行中、`⚠` 重要和 `☒` 取消任务；不改变 rendered text、列表缩进、续行、source map 或批注选区定位。
    - 验证：核心 reader extension 测试确认 `Checked task` 和任意非空完成态任务有 strikethrough，而 `Open task`、`In-progress task`、`Important task` 没有；`02_lists_tasks.md` fixture 测试覆盖真实完成态与未完成/进行中/重要任务的属性区别。

87. 完成态 task 的缩进续行此前没有继承完成态视觉，例如 `- [x] Confirm...` 下方的说明行仍像普通正文；批注时容易把说明行误读成仍待处理内容。
    - 修复：list block 收集阶段为 `☑` task 的普通 continuation 和 loose continuation 写入内部完成态 continuation 前缀；渲染阶段识别后给可见续行正文加 strikethrough。
    - 风险控制：内部前缀会在渲染前剥离，不进入 rendered text；未完成 task 的续行不加删除线；列表缩进、source map、批注锚点和续行正文内容保持不变。
    - 验证：核心 reader extension 测试加入 `Completed continuation should look done.` 并确认其有 strikethrough 且仍映射到 `.taskList`；`02_lists_tasks.md` fixture 加入 `Done evidence should inherit the completed state.`，fixture 测试确认完成态续行继承样式，未完成任务续行不误上删除线。

88. task checkbox glyph 此前只有视觉样式，没有携带精确的源 Markdown marker range；后续若要实现 Obsidian 式点击 checkbox 写回，只能靠 block-level source map 和文本搜索，容易在同一 task list 中误改 `[ ]` / `[x]`。
    - 修复：list 收集阶段为 task marker 写入内部 metadata 前缀，渲染阶段剥离该前缀，并把 `MarkPromptTaskMarkerSourceRange` 与 `Toggle task status` tooltip 挂到可见 checkbox glyph 上。
    - 风险控制：metadata 不进入 rendered text；属性只挂在 checkbox glyph 上，任务正文和 continuation 不携带该 range；`MarkdownReaderLayoutMetrics.renderSignature` 纳入该属性，确保源 range 变化时 NSTextStorage 会刷新。
    - 验证：核心 reader extension 测试确认 `☑ Checked task` / `☐ Open task` glyph 上的 source range 精确指向原文 `[x]` / `[ ]`，正文不带该属性；`02_lists_tasks.md` fixture 测试确认真实 checkbox glyph 有 source range 和 tooltip。

89. task checkbox glyph 已有精确 source range 后仍不能像 Obsidian Reading view 一样直接点击切换；用户必须回源文本编辑 `[ ]` / `[x]`，而且 checkbox 点按和正文选择/批注热区容易互相干扰。
    - 修复：`ReaderTextView` 增加只命中 checkbox glyph 的 task marker hit-test 和点击回调；`MarkdownReaderView` 将回调接到 `AppState.toggleTaskMarker(sourceRange:)`；AppState 以精确 3 字符 marker range 写回 Markdown 文件、重解析 reader model，并保留当前 document id 和批注 session 解析。
    - 风险控制：不做 block 内文本搜索，只接受真实 `[?]` marker range；鼠标点必须落在 checkbox glyph 的小范围内，任务正文仍可正常选择和批注；写文件失败时不更新内存文档，并在阅读区显示“保存未完成”banner；重解析后优先找回原可见 heading，避免长文 outline 状态跳回顶部。
    - 验证：新增 AppState flow 测试覆盖 `[ ] -> [x] -> [ ]` 文件写回、reader model 刷新、sourceHash 变化、无效 range no-op 和可见 heading 保留；新增 Reader fixture rendering 测试覆盖 checkbox glyph 字符/点位命中且正文不命中；新增 ReaderStatusBanner 测试覆盖 task marker 保存失败可见。

90. checkbox 写回刚接通后仍有一个数据安全边界：如果 Markdown 文件在打开后被外部编辑器改动，MarkPrompt 点击 checkbox 会用内存里的旧 rawMarkdown 整体写回，可能覆盖外部新增行。
    - 修复：`AppState.toggleTaskMarker(sourceRange:)` 在写入前重新读取磁盘 Markdown，并要求磁盘内容与当前内存文档完全一致；若检测到外部修改，拒绝写回并显示“保存未完成”reader banner。
    - 风险控制：只保护 task marker 写回路径，不改变文档打开、批注 autosave 或 prompt 保存；失败时保持内存文档和磁盘外部版本各自不变，避免静默合并造成 anchor/source map 不一致。
    - 验证：新增 AppState flow 测试模拟外部进程新增任务行，确认 checkbox toggle 返回 false、磁盘外部版本未被覆盖、当前文档仍保持原内存版本，并显示 task 保存失败 banner。

91. checkbox 已可点击后仍缺少 macOS 原生可发现性：鼠标移到 checkbox glyph 上时没有手型 cursor，用户很难意识到 Reading view 中这个字符是可操作控件，而正文区域又应该继续保持文本选择语义。
    - 修复：`ReaderTextView` 抽出 `taskMarkerHitRect(atCharacterIndex:)` / `taskMarkerHitRects()` 作为 checkbox 热区的单一计算来源，点击命中和 `resetCursorRects()` 共用该热区；SwiftUI/AppKit bridge 在文本或布局重排后刷新 cursor rect。
    - 风险控制：cursor rect 只覆盖带 `MarkPromptTaskMarkerSourceRange` 的 checkbox glyph 小范围，不扩展到任务正文、续行或批注选择区域；hit rect 仍由 TextKit glyph bounds 派生，避免和点击命中漂移。
    - 验证：扩展 Reader fixture rendering 测试，确认 checkbox glyph 的 hit rect 包含 glyph 中心、不包含正文方向偏移点，正文字符没有 hit rect，并且当前 fixture 只产出一个 checkbox hit rect。

92. checkbox 已有鼠标点击和 hover cursor，但键盘路径仍缺失；对于偏键盘工作流或辅助操作，用户无法把焦点/选区落在 checkbox glyph 后用空格切换，和 macOS checkbox 控件及 Obsidian Reading view 的交互预期不一致。
    - 修复：`ReaderTextView` 增加 `taskMarkerSourceRangeForKeyboardToggle()`，只在当前插入点或单字符选区落在 checkbox glyph 上时返回 task marker source range；`keyDown` 捕获空格键并复用已有 `onTaskMarkerClick` 写回路径。
    - 风险控制：多字符选区或任务正文选区不会触发 toggle，避免用户选择正文准备批注时误改 Markdown；非空格键继续交给 `NSTextView`，不改变查找、复制或普通选择行为。
    - 验证：新增 Reader fixture rendering 测试覆盖 checkbox 单字符选区、checkbox 插入点、正文选区和多字符选区四种键盘 toggle 判定。

93. checkbox 写回已经像 Obsidian Reading view 一样可点击/可键盘切换，但切错后没有撤销入口；在本地 Markdown 文件被立即写回的场景里，缺少 undo 会让轻微误触变成真实文件变更。
    - 修复：`AppState` 增加单步 task marker undo snapshot，成功 toggle 后记录切换前的 Markdown、document id、文件 URL 和当前 heading 参考；`undoLastTaskMarkerToggle()` 写回上一版 Markdown、重建 reader model，并保留 document id 与阅读位置。
    - 风险控制：只覆盖 task marker 写回路径，不接管 NSTextView 内部 undo；撤销前仍检查磁盘内容等于当前内存文档，避免在外部编辑后用旧快照覆盖文件；打开新文档会清掉旧 task undo。
    - 验证：新增 AppState flow 测试覆盖 toggle 后 `canUndoTaskMarkerToggle` 变为 true、撤销后文件和 reader model 回到未完成 checkbox、document id 保持不变、saveState 为 saved，并且单步 undo 被消费。

94. 单步 task undo 存在后仍不够原生：App 菜单和 Cmd-Z 只向响应链发送 `undo:`，而阅读区没有把这个标准 AppKit action 接到 task marker undo，导致用户切错 checkbox 后仍需要非自然入口才能撤销。
    - 修复：`ReaderTextView` 增加 `onTaskMarkerUndo` 和标准 `undo:` action；`MarkdownTextViewRepresentable` 将该闭包传入 TextKit view，`MarkdownReaderView` 接到 `AppState.undoLastTaskMarkerToggle()`，因此现有“撤销”菜单和 Cmd-Z 在阅读区聚焦时会复用同一条撤销路径。
    - 风险控制：只有 task marker undo 成功时才消费 `undo:`；若闭包返回 false，ReaderTextView 会继续把 action 转发给 nextResponder，避免吞掉响应链里的其他原生撤销机会；不新增低层 keyDown 抢键逻辑。
    - 验证：新增 Reader fixture rendering 测试直接发送 `undo:`，确认成功时调用 task undo handler，失败时继续转发给 nextResponder；同时复跑 AppState task toggle/undo flow 测试确认文件写回撤销链仍保持一致。

95. task checkbox 的撤销接入 Cmd-Z 后仍只有单步历史；连续勾选多个任务时，用户只能撤回最后一次写入，第二次 Cmd-Z 无法继续回到更早的 Markdown 状态，不符合长任务列表里的原生撤销预期。
    - 修复：`AppState` 将单个 `TaskMarkerUndo` 快照升级为栈式 `taskMarkerUndoStack`；每次 task marker 成功写回后追加快照，`undoLastTaskMarkerToggle()` 只在磁盘写回和 reader model 重建成功后弹出最后一项。
    - 风险控制：外部修改保护仍在每次 undo 前检查磁盘内容；失败时保留撤销栈，避免把用户可重试的历史静默丢掉；打开新文档继续清空 task undo stack，避免跨文档撤销。
    - 验证：新增 AppState flow 测试连续切换两个 checkbox 后连续撤销两次，确认文件和 reader model 逐步回到每次写入前的 Markdown；复跑单步撤销、外部修改保护和 Reader `undo:` 响应链测试。

96. `02_lists_tasks.md` 已覆盖 `[-]`、`[/]`、`[!]` 等 Obsidian 风格 task 状态，但阅读区此前只能通过左键做二态 toggle；想把任务标为取消、进行中或重要，仍要回源 Markdown 改 marker，批注阅读流会被打断。
    - 修复：`AppState` 增加 `setTaskMarker(sourceRange:markerCharacter:)`，可精确写入指定单字符 task marker，并复用现有磁盘一致性检查、undo stack、reader model 重建和 heading 保留；`ReaderTextView` 在 checkbox glyph 热区提供右键“任务状态”菜单，包含待办、完成、取消、进行中、重要五种状态，并通过 SwiftUI/AppKit bridge 接到 AppState。
    - 风险控制：左键/空格仍保持现有二态 toggle，不改变 Obsidian 常见基础点击语义；状态菜单只在 checkbox glyph 的 hit rect 内出现，任务正文区域继续走 `NSTextView` 默认菜单；指定状态写回仍只接受真实 3 字符 marker range，且同状态选择 no-op，避免制造空撤销记录。
    - 验证：新增 AppState flow 测试确认 `[ ]` 可通过指定状态写成 `[/]`、磁盘和 reader model 渲染为 `◩`，且 undo 可恢复；新增 Reader fixture rendering 测试确认 checkbox 右键菜单只在 glyph 热区出现、菜单项完整，并能把 source range 与目标 marker `/` 传给回调。

97. 右键 task 状态菜单能写入自定义状态后，菜单本身仍没有当前状态反馈：看到 `◩` / `⚠` glyph 时，右键菜单不会勾选“进行中/重要”，也不会置灰当前项，用户容易重复选择当前状态或误判当前 Markdown marker。
    - 修复：task list 渲染的内部 metadata 从仅携带 source range 扩展为 source range + 原始 marker 字符，并把 `MarkPromptTaskMarkerCharacter` 挂到 checkbox glyph；`ReaderTextView` 生成状态菜单时读取该字符，为当前状态菜单项加 checkmark 并禁用。`MarkdownReaderLayoutMetrics.renderSignature` 也纳入 marker 字符，确保同一 source range 从 `[/]` 改成 `[!]` 时 TextKit storage 会刷新菜单状态。
    - 风险控制：旧的 range-only metadata payload 仍可解析，缺 marker 字符时菜单只是不显示当前项，不影响 hit-test 或写回；`[a]` 这类非标准完成态不会被误标成标准 `[x]` 当前项；当前项禁用后不会制造 no-op undo 记录。
    - 验证：扩展 MarkdownParser 测试确认 `☐` / `◩` glyph 带有原始 marker 字符且任务正文不带该属性；扩展 Reader fixture rendering 测试确认进行中 checkbox 的右键菜单会勾选并禁用“标记为进行中”，并且选择“标记为重要”仍会传出 `!` marker。

98. task 写回遇到外部文件修改时已经会拒绝覆盖，但恢复路径仍断在错误文案：用户需要自己去“打开 Markdown...”重新选同一文件，阅读/批注上下文被迫中断。
    - 修复：`ReaderStatusBannerPresentation` 为“任务状态保存失败：文件已在外部修改...”这类可恢复失败提供“重新载入文件”动作；`ReaderStatusBannerView` 显示小号原生按钮；`MarkdownReaderView` 将按钮接到 `AppState.reloadCurrentDocumentFromDisk()`，该方法复用 `openDocument(at:)`，因此仍会执行批注 autosave flush、sidecar load、anchor resolve、recent document 和 scroll target 初始化。
    - 风险控制：只有打开文档且错误明确包含“文件已在外部修改”时才显示 reload action，权限错误等不可通过 reload 修复的 task 保存失败不显示按钮；reload 仍复用现有打开文档保护，不绕过批注保存失败阻断；成功 reload 后 task undo stack 会随打开逻辑清空，避免用旧文档快照撤销新磁盘内容。
    - 验证：扩展 AppState flow 测试，模拟外部进程追加 task 后点击 checkbox 被拒绝，确认 banner 带“重新载入文件”，调用 reload 后当前 document/rawMarkdown/render model 读回外部版本、saveState 回到 loaded、task undo 清空；扩展 task 保存失败 banner 测试确认普通权限失败不显示 reload action。

99. task checkbox 已经支持左键、空格、右键状态菜单和 Cmd-Z 撤销，但 hover tooltip 仍只写着 `Toggle task status`；真实阅读中用户很难从原生提示知道右键还能选择取消、进行中、重要等状态。
    - 修复：task marker glyph 的 tooltip 改为“点击或空格切换；右键选择任务状态。”，把二态切换和右键状态菜单都暴露在 checkbox 本身的可发现层。
    - 风险控制：tooltip 仍只挂在带 `MarkPromptTaskMarkerSourceRange` 的 checkbox glyph 上，不扩展到任务正文或 continuation；不改变 rendered text、source map、点击/键盘命中、状态菜单写回或批注选区。
    - 验证：核心 Markdown renderer 测试覆盖普通 task glyph tooltip；`02_lists_tasks.md` fixture 测试覆盖真实任务列表中的 checkbox glyph tooltip，确保 fixture 中的右键状态入口可通过 hover 文案被发现。

100. task checkbox 虽然已有空格键路径，但它仍不是一个标准 macOS responder command；用户无法通过菜单/快捷键触发“切换当前任务状态”，也不利于后续接入更完整的键盘工作流。
    - 修复：`ReaderTextView` 增加 `toggleTaskMarkerStatus:` responder action，只在当前插入点或单字符选区落在 checkbox glyph 上时复用现有精确 source range 写回路径；App 菜单新增“任务 → 切换任务状态”，快捷键为 `⌘L`。checkbox tooltip 同步更新为“点击、空格或⌘L切换；右键选择任务状态。”。
    - 风险控制：命令只消费真实 checkbox glyph 选区；正文选区、空文档或写回失败会继续转发 responder chain，避免吞掉其他 AppKit 行为；不改变右键状态菜单、鼠标点击、空格键或批注选区判断。
    - 验证：新增 Reader fixture rendering 测试通过 `toggleTaskMarkerStatus:` selector 验证 checkbox 选区会调用 task toggle handler、非 checkbox 情况会转发给 next responder；核心 Markdown renderer 与 `02_lists_tasks.md` fixture 同步验证 tooltip 中的 `⌘L` 提示。

101. checkbox 空格切换接入后，`keyDown` 只看 `charactersIgnoringModifiers == " "`；如果 AppKit 把 `⌘Space`、`⌥Space` 或 `⌃Space` 送到阅读区，可能误把系统搜索、输入法或辅助快捷键当成 task toggle，从而直接写回 Markdown。
    - 修复：`ReaderTextView.keyDown` 改为只处理没有 Command/Option/Control 的空格事件；带这些修饰键的空格继续交给 `NSTextView`/响应链，普通空格仍复用现有 checkbox source range 写回路径。
    - 风险控制：不改变鼠标点击、`⌘L` 菜单命令、右键状态菜单或 checkbox 选区判定；只收窄低层空格键的触发条件，避免系统级组合键造成误写文件。
    - 验证：新增 Reader fixture rendering 测试构造真实 `NSEvent.keyDown`，确认普通空格会触发一次 task toggle，而 `⌘Space`、`⌥Space`、`⌃Space` 不会增加 toggle 次数；复跑 keyboard toggle、`⌘L` command 和右键状态菜单聚焦测试。

102. `⌘L`/“任务 → 切换任务状态”已有 responder action 后，菜单验证仍沿用默认行为；正文选区或多字符选区时菜单看起来可用，但 action 实际会转发/无效，原生菜单反馈不够可信。
    - 修复：`ReaderTextView.validateUserInterfaceItem(_:)` 对 `toggleTaskMarkerStatus:` 单独验证，只在当前插入点或单字符选区落在 checkbox glyph 上时启用；其它菜单项继续交给 `NSTextView` 默认 validation。
    - 风险控制：只影响 task toggle command 的 enabled 状态，不改变实际点击、空格、`⌘L` 执行路径、右键状态菜单或 undo；正文选区继续保留文本选择和批注语义。
    - 验证：新增 Reader fixture rendering 测试确认 checkbox glyph 选区时 command item enabled，正文选区和多字符选区时 disabled；复跑 task keyboard、`⌘L` command、validation 和右键状态菜单聚焦测试。

103. task checkbox 已支持键盘切换，但键盘用户仍要先手动把插入点/选区落到 checkbox glyph 上；长任务列表里无法像原生可达控件一样在任务之间快速移动焦点。
    - 修复：`ReaderTextView` 增加 `selectNextTaskMarker:` / `selectPreviousTaskMarker:` responder actions，按文档顺序在 checkbox glyph 之间移动单字符选区并支持首尾循环；“任务”菜单新增“下一个任务”(⌘⌥J) 和“上一个任务”(⌘⌥K)，命中后用户可继续用空格或 `⌘L` 切换当前任务。
    - 风险控制：导航只枚举带 `MarkPromptTaskMarkerSourceRange` 的真实 checkbox glyph，不会选中任务正文或 continuation；无 task 时命令转发响应链且菜单 validation 置为 disabled；不改变任务写回、右键状态菜单或批注选区语义。
    - 验证：新增 Reader fixture rendering 测试覆盖三个 checkbox 之间的 next/previous 选区移动、首尾循环、从正文选区跳到下一个 checkbox，以及有/无 task 时导航菜单 validation；复跑 task keyboard、`⌘L` command、navigation、validation 和右键状态菜单聚焦测试。

104. 上/下一个任务菜单命令接入后，checkbox glyph 的 hover tooltip 仍只提示点击、空格、`⌘L` 和右键状态菜单；用户即使发现 checkbox 可交互，也不一定知道可以用 `⌘⌥J/K` 在任务之间跳转。
    - 修复：task marker tooltip 更新为“点击、空格或⌘L切换；⌘⌥J/K跳转任务；右键选择任务状态。”，把任务间键盘导航入口和切换/状态菜单放在同一个原生可发现层。
    - 风险控制：只改 checkbox glyph 的 `.toolTip` 属性，不扩展到任务正文或 continuation；不改变 rendered text、source map、导航 action、写回、右键状态菜单或批注选区。
    - 验证：核心 Markdown renderer 测试和 `02_lists_tasks.md` fixture 测试同步断言 tooltip 包含 `⌘⌥J/K` 导航提示；聚焦测试先确认真实 fixture 仍返回旧 tooltip，再更新 renderer 后转绿。

105. task checkbox 已经有鼠标、键盘、菜单和 tooltip 入口，但辅助技术仍只能把 `☐/☑` 当作普通文本读出；VoiceOver 用户缺少“这是任务 checkbox、当前状态、可按下切换”的原生语义。
    - 修复：`ReaderTextView` 从带 `MarkPromptTaskMarkerSourceRange` 的 checkbox glyph 生成 `NSAccessibilityElement` 子元素，role 为 checkbox，label 使用当前任务首行正文，value 使用勾选布尔值，help 暴露当前任务状态、按下切换、右键状态菜单和 `⌘⌥J/K` 任务跳转。
    - 风险控制：accessibility child 只来源于真实 task marker glyph，不改变 rendered text、source map、鼠标/键盘命中、状态菜单、写回、undo 或批注选区；press 动作复用现有 `onTaskMarkerClick` 闭包，因此仍走同一条磁盘一致性保护。
    - 验证：新增 Reader fixture rendering 单测先确认当前 `ReaderTextView.accessibilityChildren()` 没有 checkbox 元素，再实现后验证两个 task marker 暴露为 checkbox、label/value/help 正确，且 `accessibilityPerformPress()` 会调用既有 task toggle handler。

106. checkbox 已暴露为 accessibility checkbox 后，辅助技术用户仍只能执行“按下切换”的二态动作；取消、进行中、重要等 Obsidian 风格任务状态仍藏在鼠标右键菜单里。
    - 修复：`TaskMarkerAccessibilityElement` 增加 `NSAccessibilityCustomAction` 列表，复用右键菜单的五种任务状态，但过滤当前状态；每个 custom action 通过现有 `onTaskMarkerStatusChange` 写入指定 marker 字符。
    - 风险控制：只扩展 accessibility custom actions，不改变视觉渲染、右键菜单、普通 press/toggle、任务导航、undo、source map 或批注选区；状态写回仍复用 AppState 的磁盘一致性和 undo 栈路径。
    - 验证：新增 Reader fixture rendering 单测先确认 checkbox accessibility element 没有 custom actions，再实现后验证当前“进行中”任务只提供待办/完成/取消/重要四个动作，并确认执行“标记为重要”会把 source range 和 `!` marker 传给既有状态写回 handler。

107. task 写回/撤销遇到外部修改时已经安全拒绝并提供重新载入，但 banner 仍只说“文件已在外部修改”；用户不知道磁盘版本是新增了一行、删了一段，还是完全重写，容易不敢决定是否 reload。
    - 修复：`AppState` 在检测到磁盘 Markdown 与当前打开 Markdown 不一致时，生成轻量行级摘要并写入 task 保存失败文案，例如“外部版本新增 1 行”；切换和撤销 task 状态两条路径都复用同一摘要。
    - 风险控制：摘要只用于 reader banner 文案，不自动合并、不覆盖磁盘、不改变 reload action、undo 栈保留、render model、source map、批注保存或 prompt 保存；普通权限/IO 错误仍走原错误文案。
    - 验证：先更新外部修改切换测试看到旧文案红灯，再实现摘要后转绿；随后为撤销 task 时的外部修改新增红灯测试，确认撤销失败不消费 undo 栈、不覆盖磁盘外部版本，并显示同样的新增行摘要。

108. 外部修改摘要第一版能提示新增/移除行，但单行内容被外部编辑时仍显示为“新增 1 行、移除 1 行”，也没有告诉用户从哪里开始变；这不像真实 diff，也会让用户误以为结构变化比实际更大。
    - 修复：`MarkdownLineChangeSummary` 将重叠的新增/移除行先归并为“外部版本修改 n 行”，剩余净变化再显示为新增或移除，并在摘要前增加首个变化行号，例如“第 3 行起，外部版本修改 1 行”。
    - 风险控制：只改变 task 外部修改 banner 的摘要字符串，不改变磁盘保护、reload action、undo 栈、自动保存、source map、reader rendering 或批注上下文；仍不尝试自动合并。
    - 验证：新增 AppState flow 红灯测试，模拟外部编辑仅修改 task 正文一行，确认旧实现显示“新增 1 行、移除 1 行”且无行号；实现后确认 banner 改为“第 3 行起，外部版本修改 1 行”，并复跑纯新增切换/撤销外部修改测试，确认新增摘要也带“第 4 行起”且不回归。

109. task checkbox 已暴露为 accessibility checkbox 且有 custom actions，但 `accessibilityValue` 仍只是布尔值；对 `[/]` 进行中、`[!]` 重要、`[-]` 取消等 Obsidian 风格状态，辅助技术很难直接读出当前状态名。
    - 修复：`TaskMarkerAccessibilityElement` 保留原生 checkbox 布尔 `accessibilityValue`，同时设置 `accessibilityValueDescription` 为“待办 / 完成 / 取消 / 进行中 / 重要”等状态名，让 VoiceOver 类工具既能理解 checkbox 状态，也能读出 Obsidian 风格 marker 语义。
    - 风险控制：只扩展 accessibility metadata，不改变视觉 glyph、TextKit rendered text、source map、鼠标/键盘/菜单写回、undo、状态 custom actions 或批注选区。
    - 验证：扩展 Reader fixture rendering accessibility 测试，先确认旧实现的 `accessibilityValueDescription()` 为 nil 红灯；实现后验证待办/完成/进行中 checkbox 分别暴露“待办”“完成”“进行中”，且 custom action 写回路径不回归。

110. Obsidian inline footnote 已经会隐藏 `^[...]` 源码并把内容放进 tooltip，但上标只像普通蓝色编号；用户不一定能发现它可悬停查看 reviewer context，批注时也难区分普通引用编号与有附加说明的 hover target。
    - 修复：脚注引用上标统一增加 dotted underline 和低调 underline color，和 abbreviation hover hint 使用同一 TextKit 可发现性语言；inline footnote 继续把说明内容放在 `.toolTip`，普通脚注引用也获得更明确的可探索样式。
    - 风险控制：只改变上标属性，不改变 rendered text、脚注编号、footnote block、tooltip 内容、source map、批注 selectedText 或图片/链接 inline 渲染；不新增 hover popover 或交互控件。
    - 验证：先扩展核心 parser 测试，确认旧实现 `¹` 的 underline style/color 为 nil 红灯；实现后确认 inline footnote 上标带 dotted underline 和 tooltip。扩展 `10_review_prd_mix.md` fixture 断言真实样本文档中的 `²` 上标也带同样 hover hint 样式。

111. 普通 `[^id]` footnote 引用此前虽然显示为上标编号，并在文末渲染定义 block，但悬停上标没有定义预览；长文审阅时用户需要离开当前位置去文末找 footnote，批注上下文容易被打断。
    - 修复：渲染入口预收集 footnote definition tooltip，普通引用上标复用 inline footnote 的 `.toolTip` 路径显示清洗后的定义文本；续行定义会合并成一句 tooltip，定义内的基础 inline Markdown 会先降噪成可读文本。
    - 风险控制：只新增 footnote 引用上标的 tooltip，不改变编号、文末 footnote block、source map、批注 selectedText、inline footnote 行为、图片预览、链接样式或表格布局；没有定义或空定义时不上 tooltip。
    - 验证：新增核心 parser 红灯断言，确认普通 `[^note]` 的 `¹` 旧实现 tooltip 为 nil；实现后验证 tooltip 为 `Footnote text with formatting.`。扩展 `05_quotes_footnotes.md` fixture，确认 `¹` 显示单行定义 tooltip、`²` 合并续行定义 tooltip。

112. Obsidian 官方 footnote 示例允许定义续行只缩进 2 个空格；此前 MarkPrompt 只把 4 个空格或 tab 识别为 footnote continuation，2-space 续行会掉成普通 paragraph，文末脚注 block 和引用 tooltip 都会漏掉后续说明。
    - 修复：`isFootnoteContinuation(_:)` 放宽为非空行 leading spaces >= 2 或 tab；空行续行行为保持不变，`collectFootnoteDefinition` 与 footnote tooltip 收集自动复用同一判定。
    - 风险控制：只在已经进入 footnote definition 收集之后应用 2-space continuation，不改变普通段落/list/blockquote 起始解析、inline footnote、脚注编号、source map 或批注选区；未缩进后续段落仍会结束 footnote。
    - 验证：新增核心 parser 红灯测试，确认 2-space 续行旧实现渲染为 paragraph 且 tooltip 只含第一行；实现后确认续行并入 `.footnote` block、rendered text 合并两行，并且引用上标 tooltip 同步包含两行内容。

## 仍需人工视觉复核

- `NSTextTableBlock` 在真实 App 窗口中的跨单元格选择体验；
- 表格内跨单元格选择时真实 selection rect 片段是否符合用户预期；
- 新版侧边批注入口在真实 App 窗口内与 popover 箭头、滚动条、窄列布局的组合手感；
- Obsidian 内部链接目前支持 wikilink 和 Markdown-format internal link 的本地标识与样式，后续如需真实 vault 跳转，需要设计文件解析、缺失链接状态和路径安全策略；
- Obsidian `![[embed]]` 目前只有段落、列表项、引用块、definition list 和表格内本地图片会生成预览并支持基础尺寸参数；PDF/audio/video 目前只有安全类型标签 fallback，不提供真实预览/播放；note excerpt 目前只有安全 `Note:` placeholder，不加载真实 vault 内容或 excerpt；
- Obsidian callout 折叠状态和嵌套 callout 目前显示为 `▾/▸` 阅读态信号，但不提供真实折叠/展开交互或独立子 callout block；如后续增加交互，需要确保 NSTextView selection 和批注入口不被子视图打断；
- Obsidian 自定义 callout 目前只 fallback 到 note 样式，不读取 vault CSS 或自定义 icon；
- Obsidian footnote 和 inline footnote 目前使用 tooltip 承载引用说明，且上标已有 dotted underline hover hint；后续需在真实窗口里复核 tooltip 触发手感，并评估是否需要类似 Obsidian 的 hover popover；
- Obsidian task list checkbox 现在支持基础二态点击写回、手型 hover 热区、普通空格键切换判定且避开 Command/Option/Control + Space 系统组合键、`⌘L` 菜单命令与 checkbox 选区菜单 validation、上/下一个任务 checkbox 菜单导航、右键写入取消/进行中/重要等自定义状态、右键菜单当前项勾选/置灰、阅读区 Cmd-Z/menu 多步撤销，并会拒绝覆盖打开后被外部修改的 Markdown；外部修改失败时 reader banner 会给出首个变化行号以及修改/新增/移除行数摘要，并可就地重新载入当前文件；checkbox tooltip 也会提示点击/空格/`⌘L` 切换、`⌘⌥J/K` 跳转任务和右键状态菜单；TextKit 阅读区会把 checkbox glyph 暴露为原生 accessibility checkbox 子元素，提供待办/完成/进行中等 value description，并通过 accessibility custom actions 选择非当前任务状态。后续需在真实窗口用 VoiceOver 复核读出顺序、焦点环和 custom action 菜单呈现、更完整的键盘焦点导航文案/快捷键合理性、SwiftUI Commands 菜单 enabled 状态是否完全跟随 AppKit validation、tooltip/右键状态菜单发现性，以及外部修改后的完整差异查看/合并入口；
- YAML frontmatter 目前是只读轻量 Properties summary，不支持 Obsidian 式属性编辑器、类型图标、日期/checkbox property 或完整 YAML 嵌套结构；
- 真实窗口连续滚动时当前章节高亮的节奏、outline 自动跟随是否过于频繁、以及长文档性能；
- 图片附件附近的真实 selection rect 片段是否符合用户预期；
- 图片 preview 强制独立成行后，仍需在真实窗口复核长图、多图连续出现时的段落间距和批注入口位置；
- 图片 fallback 已降噪为短文件名但仍作为可选文本可见；后续可评估让 fallback 更安静或改为辅助属性，同时不破坏批注选区和 source map；
- HTML block 目前是 readable text fallback，后续可评估是否展示轻量 block label；
- bare URL 已自动 linkify，后续需人工确认右键/打开链接交互；
- block math 目前已有轻量公式预览并保留 LaTeX 源码；后续可评估复杂公式覆盖范围；
- Mermaid 轻量预览在复杂图和真实窗口 selection rect 下的表现；
- block math 轻量预览在复杂 LaTeX 和真实窗口 selection rect 下的表现。
