# 示例 PRD

## 1. 产品概述

MarkPrompt 是一个用于 Markdown 审稿的本地 Mac 工具。用户可以在文档上直接选择文本并添加批注，然后生成可交给 Codex 执行的修改 Prompt。

## 2. 核心价值

它让用户不需要在对话里反复描述文档位置，而是直接通过画线和批注表达修改意图。

## 3. 关键流程

- 打开 Markdown；
- 选择需要修改的文本；
- 添加批注意见；
- 生成 Prompt；
- 交给 AI 修改原文。

## 4. 技术要求

应用需要保持本地优先，默认不上传用户文档。

```swift
struct ReviewNote {
    var id: String
    var comment: String
}
```

| 模块 | 责任 |
|---|---|
| Reader | 阅读和选择文本 |
| Annotation | 创建和管理批注 |
| Prompt | 生成修改指令 |

