# MarkPrompt Reader Fixture Audit

日期：2026-06-26

本轮新增 `samples/markdown/reader-fixtures/` 下 10 份 Markdown fixture，用来持续检查 MarkPrompt 中间阅读区是否接近 Markdown Reader 的阅读体验，同时不破坏 TextKit 文本选择、批注锚点、高亮和 PromptBuilder 流程。

## Fixture 覆盖

| 文件 | 覆盖场景 | 关键检查 |
|---|---|---|
| `01_headings_inline.md` | H1-H6、Setext H1/H2、heading inline、段落、hard line breaks、bold、italic、inline code、link、strikethrough、mark、insert、superscript、subscript、emoji shortcode、abbreviation、literal `_`/`*` 技术文本、backslash escaped marker | inline marker 不应直接露出，heading inline marker 不应裸露，hard break 保留段落内真实换行，code span 使用中性 token 样式，mark/insert 使用原生属性，上下标使用 TextKit baseline offset，常见 emoji shortcode 转 Unicode，abbr 定义行隐藏且正文缩写带 tooltip，`API_TOKEN`/`snake_case`/`2 * 3` 等普通文本不得被 marker 清理误改，`\*literal\*`、`\[not link](...)`、`\![not image](...)` 等转义符号应显示为字面 Markdown 语法且不触发样式/链接/图片 fallback |
| `02_lists_tasks.md` | unordered/ordered/task/nested lists、ordered start numbers、parenthesized ordered markers、indented list continuations、loose list paragraphs | 紧凑列表节奏、task marker、有序列表保留作者起始编号和 `10)` marker、TextKit 嵌套缩进、续行和空行后的列表内段落对齐到 item 正文并保留 source block |
| `03_tables_wide.md` | 宽表、窄表、对齐分隔线 | 使用 native TextKit table，不再用字符画边框 |
| `04_code_blocks.md` | Swift/JSON/Shell/YAML/Diff fenced code、indented code block | 自然语言标签、浅底代码块、按语言分流的基础语法高亮；4 空格缩进代码块应复用同一 TextKit code block 阅读样式 |
| `05_quotes_footnotes.md` | blockquote、lazy blockquote continuation、nested blockquote marker、GFM callout、footnote、footnote continuation | TextKit 引用块、普通段落型 lazy continuation 保持在引用块内、嵌套 `> >` 不暴露原始 marker 且有缩进、callout label 与 colored border、轻量脚注、续行并入 footnote block |
| `06_images_links.md` | local/remote image、inline image、regular link、reference-style link/image、autolink、bare URL | 本地块级图片缩略预览、远程块级图片占位、段落内 direct/reference Markdown 图片显示为可选择文本占位、reference 定义隐藏、autolink 属性 |
| `07_math_mermaid_fallback.md` | inline/block math、Mermaid | inline math 使用紧凑公式 token，block math 有轻量公式预览且保留 LaTeX 源码，简单 Mermaid flowchart 有原生预览且保留源码 |
| `08_long_outline.md` | 多级长大纲 | outline 数量、layout 稳定、可见位置到当前章节高亮的推导 |
| `09_frontmatter_html.md` | YAML frontmatter、HTML block fallback、HTML table fallback、inline HTML fallback、HTML link/br/img fallback、thematic break | metadata 轻量块、HTML block 安全 fallback、简单 HTML table 原生表格、`kbd/mark/ins/del/sup/sub/small` 原生 inline 属性、`a href` 链接属性、`br` 段落内换行、`img` 安全文本占位、原生分隔线 |
| `10_review_prd_mix.md` | 综合 PRD 审稿流 | task/table/footnote 混合渲染 |

## 自动化检查

新增 `ReaderFixtureRenderingTests`：

- fixture 数量必须为 10；
- 每份 fixture 都能被 `MarkdownParser` 解析；
- 每份 fixture 都能在 760pt 和 520pt TextKit 宽度下完成 offscreen layout；
- rendered text 不再包含 `┌` / `└` 字符画表格边框；
- 宽表必须生成 `NSTextTableBlock`；
- task list、nested list、footnote continuation、autolink、bare URL linkify、HTML readable fallback、frontmatter metadata、Mermaid fallback 等关键预期必须成立；
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
   - 修复：识别开头 `--- ... ---` frontmatter，压缩为轻量 metadata 行。

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

## 仍需人工视觉复核

- `NSTextTableBlock` 在真实 App 窗口中的跨单元格选择体验；
- 表格内跨单元格选择时真实 selection rect 片段是否符合用户预期；
- 真实窗口连续滚动时当前章节高亮的节奏、outline 自动跟随是否过于频繁、以及长文档性能；
- 图片附件附近的真实 selection rect 片段是否符合用户预期；
- HTML block 目前是 readable text fallback，后续可评估是否展示轻量 block label；
- bare URL 已自动 linkify，后续需人工确认右键/打开链接交互；
- block math 目前已有轻量公式预览并保留 LaTeX 源码；后续可评估复杂公式覆盖范围；
- Mermaid 轻量预览在复杂图和真实窗口 selection rect 下的表现；
- block math 轻量预览在复杂 LaTeX 和真实窗口 selection rect 下的表现。
