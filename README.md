# MarkPrompt

MarkPrompt 是一个本地优先的 macOS Markdown 审稿工具。它面向“读文档、标问题、生成可执行修改 Prompt”的工作流：打开 Markdown 后，可以在渲染阅读区选择原文、创建批注、维护批注清单，并把纳入修改范围的批注汇总成可交给 Codex / Claude Code 使用的文件修改 Prompt。

当前仓库已经进入原生 macOS 应用实现阶段，主要代码位于 `app/MarkPrompt`。应用以 Swift Package 形式组织，已具备可运行、可测试和本地打包的基础能力。

## 当前实现状态

- 原生 macOS 应用：`swift run MarkPrompt` 可启动本地应用，`scripts/package_app.sh` 可生成 `build/MarkPrompt.app`。
- Markdown 导入：支持通过打开面板、最近文档、拖拽文件和剪贴板候选路径打开 `.md` / `.markdown`。
- 阅读体验：中间阅读区基于 AppKit / TextKit 渲染 Markdown，支持标题大纲导航、查找、文本选择、批注高亮、当前阅读标题跟踪和宽表横向布局。
- Markdown 渲染覆盖：已覆盖标题、列表、任务列表、代码块、表格、引用、脚注、图片、链接、Front Matter、HTML 表格、数学/mermaid fallback、Obsidian 风格链接与嵌入等常见阅读场景。
- 批注工作流：支持从选区创建批注、快捷提示、右侧卡片编辑、删除、定位、排除或纳入 Prompt，并处理重复选区、空批注、锚点丢失等状态。
- 本地持久化：批注保存为 Markdown 旁侧 `.review.json`，并带有应用数据目录 fallback、损坏 sidecar 备份、自动保存和关闭前保存保护。
- Prompt 生成：右侧 Prompt 面板可实时预览、复制并保存修改 Prompt；复制或保存前会同步当前批注。
- 任务项编辑：阅读区内的 Markdown 任务 checkbox 支持切换状态、撤销和外部修改保护。
- 测试与验收：仓库包含模型、解析渲染、锚点恢复、持久化、Prompt 生成、应用状态流、布局交互和 fixture 快照相关测试。

## Workspace

```text
.
├── app/MarkPrompt/              # Swift Package 版 macOS 应用、MarkPromptKit、测试和打包脚本
├── docs/                        # 产品文档、阅读器验收记录、原型图和渲染快照资产
├── samples/                     # 本地 Markdown 样例和 reader fixture
├── scripts/                     # 仓库级辅助脚本
├── build/                       # 本地打包产物目录
└── .github/                     # GitHub 配置
```

## 运行

要求 macOS 14+ 和 Swift 6 工具链。

```bash
cd app/MarkPrompt
swift run MarkPrompt
```

应用启动后可通过工具栏、`⌘O`、拖拽或最近文档打开 Markdown。可优先试用仓库根目录下的样例：

```text
samples/markdown/sample_prd.md
```

## 测试与本地打包

```bash
cd app/MarkPrompt
swift test
```

```bash
cd app/MarkPrompt
./scripts/package_app.sh
```

打包产物会生成到仓库根目录：

```text
build/MarkPrompt.app
```

阅读区 fixture 快照可用于人工检查浅色和深色阅读效果：

```bash
cd app/MarkPrompt
swift run ReaderFixtureSnapshotTool
swift run ReaderFixtureSnapshotTool --appearance dark --output docs/assets/reader-fixture-snapshots-dark
```

## 参考资料

这些文档保留为产品和技术背景参考，当前状态请优先以 `app/MarkPrompt` 的实现和测试为准。

- [产品需求文档](docs/MarkPrompt_PRD.md)
- [产品交互说明](docs/MarkPrompt_interaction_spec.md)
- [技术开发文档](docs/MarkPrompt_technical_development.md)
- [Workspace 文件规划](docs/MarkPrompt_workspace_plan.md)
- [阅读器基准记录](docs/MarkPrompt_reader_benchmark.md)
- [阅读器 fixture 审计](docs/MarkPrompt_reader_fixture_audit.md)
- [V4 原型图](docs/assets/markprompt_interaction_prototype_v4.png)
