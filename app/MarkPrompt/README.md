# MarkPrompt macOS App

这里用于存放 MarkPrompt 原生 macOS 应用代码。

计划技术栈：

- SwiftUI：窗口、侧边栏、右侧检查器；
- AppKit / TextKit：Markdown 阅读区、文本选择、选区坐标和批注高亮；
- swift-markdown：Markdown 解析；
- 本地 JSON：批注 sidecar 保存；
- NSPasteboard：复制 Prompt。

当前目录已创建 Swift Package 版 macOS App。V1 支持：

- 打开本地 Markdown；
- 生成左侧标题大纲；
- 在中间阅读区选择文本；
- 通过 `批注 +` 创建批注；
- 在右侧面板编辑、删除、排除批注；
- 正文高亮已保存批注；
- 自动保存和恢复 `.review.json`；
- 实时预览、复制并保存 Codex 文件修改 Prompt。

运行：

```bash
cd app/MarkPrompt
swift run MarkPrompt
```

本地打包测试：

```bash
cd app/MarkPrompt
./scripts/package_app.sh
```

打包产物会生成到仓库根目录的 `build/MarkPrompt.app`。

生成 DMG：

```bash
cd app/MarkPrompt
./scripts/package_dmg.sh
```

DMG 会生成到仓库根目录的 `build/MarkPrompt-1.0.dmg`。

运行后可通过工具栏或 `⌘O` 打开：

```text
samples/markdown/sample_prd.md
```

测试：

```bash
cd app/MarkPrompt
swift test
```

阅读区 fixture 快照验收：

```bash
cd app/MarkPrompt
swift run ReaderFixtureSnapshotTool
swift run ReaderFixtureSnapshotTool --appearance dark --output docs/assets/reader-fixture-snapshots-dark
```

快照覆盖 `samples/markdown/reader-fixtures/` 下 10 份 Markdown，用于人工检查浅色和深色阅读效果。默认浅色输出在 `docs/assets/reader-fixture-snapshots/`，深色输出在 `docs/assets/reader-fixture-snapshots-dark/`。每个目录都会生成 `metrics.json`，其中记录 fixture、block kinds、快照尺寸和主题。
