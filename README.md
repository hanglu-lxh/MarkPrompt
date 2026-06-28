# MarkPrompt

MarkPrompt 是一个本地优先的 macOS Markdown 审稿工具。打开 Markdown 后，你可以直接在阅读区选择原文、添加批注，并把需要修改的意见汇总成一份可复制的修改 Prompt。

![MarkPrompt 添加批注](docs/assets/readme/markprompt-add-annotation.png)

## 下载

最新版本：V1.1

[下载 MarkPrompt-1.1.dmg](https://github.com/hanglu-lxh/MarkPrompt/releases/download/v1.1/MarkPrompt-1.1.dmg)

要求 macOS 14+。

## 安装

1. 下载 `MarkPrompt-1.1.dmg`。
2. 双击打开 DMG。
3. 将 `MarkPrompt.app` 拖入 `Applications`。
4. 从 `Applications` 打开 MarkPrompt。
5. 首次打开时，如果 macOS 提示无法验证开发者，可以在 Finder 中右键 `MarkPrompt.app`，选择“打开”，再确认打开。

MarkPrompt 默认在本地读取和保存文件，不会上传你的 Markdown 文档。

## 使用方法

1. 点击左上角“打开”，或按 `⌘O`，选择一个 `.md` / `.markdown` 文件。
2. 在中间阅读区阅读 Markdown，左侧大纲可以快速跳转标题。
3. 用鼠标选中需要修改的原文。
4. 点击选区旁的“批注 +”，输入修改意见，也可以使用“润色”“重写”“扩写”“缩短”等快捷批注。
5. 在右侧“批注”面板确认哪些批注需要纳入 Prompt。
6. 切换到“Prompt”面板，预览自动生成的修改 Prompt。
7. 点击“复制 Prompt”，粘贴到你常用的 AI 工具中继续修改原文。

## 功能亮点

- 本地优先：默认不上传文档内容。
- Markdown 阅读：支持标题大纲、查找、文本选择、批注高亮和宽表阅读。
- 快速批注：选中文本后即可添加修改意见，也可以使用内置快捷批注。
- Prompt 生成：把勾选的批注整理成一份结构化修改 Prompt。
- 本地保存：批注和 Prompt 会保存到本机，便于下次继续审稿。

## 说明

MarkPrompt V1.1 是早期 macOS 版本，目前未做 Apple notarization。首次打开时可能需要通过右键菜单确认打开。
