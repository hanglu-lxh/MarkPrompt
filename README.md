# MarkPrompt

MarkPrompt 是一个本地优先的 macOS Markdown 审稿工具。它用于打开 Markdown 文档，在渲染后的阅读区选中文本、画线、添加批注，并把这些批注生成可交给 Codex / Claude Code 执行的精准修改 Prompt。

当前仓库处于产品和技术准备阶段，已包含 PRD、交互说明、高保真原型和技术开发方案。后续原生 macOS 应用代码会放在 `app/MarkPrompt` 下。

## 当前文档

- [产品需求文档](docs/MarkPrompt_PRD.md)
- [产品交互说明](docs/MarkPrompt_interaction_spec.md)
- [技术开发文档](docs/MarkPrompt_technical_development.md)
- [Workspace 文件规划](docs/MarkPrompt_workspace_plan.md)
- [V4 原型图](docs/assets/markprompt_interaction_prototype_v4.png)

## Workspace

```text
.
├── app/                         # 原生 macOS 应用代码
├── docs/                        # 产品、交互、技术文档和原型资产
├── samples/                     # 本地测试 Markdown 样例
├── scripts/                     # 后续开发、构建、检查脚本
└── .github/                     # GitHub 配置
```

## 当前开发原则

- 产品以 V4 一窗三栏交互为基准；
- 首版采用 SwiftUI + AppKit/TextKit；
- 批注和 Prompt 数据默认保存在本地；
- 不引入独立批注管理弹窗或独立 Prompt 生成弹窗；
- 用户批注意见优先于快捷提示和系统推断。

