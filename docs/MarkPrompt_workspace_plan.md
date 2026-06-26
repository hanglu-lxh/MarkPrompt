# MarkPrompt Workspace 文件规划

> 目标：把当前文档型项目整理成可持续开发的本地 workspace，并为后续原生 macOS App 开发预留清晰边界。

---

## 1. 根目录规划

```text
MarkPrompt/
├── README.md
├── .gitignore
├── .gitattributes
├── .editorconfig
├── app/
├── docs/
├── samples/
├── scripts/
└── .github/
```

### 1.1 `app/`

用于存放原生 macOS 应用工程。

当前预留：

```text
app/MarkPrompt/
├── Sources/
├── Tests/
└── Resources/
```

后续创建 Xcode 工程或 Swift Package 时，应用代码按技术文档中的模块拆分：

- App；
- Features；
- Core；
- Tests。

### 1.2 `docs/`

用于存放产品和工程文档。

当前文档：

- `MarkPrompt_product_thinking.md`：原始产品思考；
- `MarkPrompt_PRD.md`：产品需求文档；
- `MarkPrompt_interaction_spec.md`：产品交互说明；
- `MarkPrompt_technical_development.md`：技术开发文档；
- `MarkPrompt_workspace_plan.md`：workspace 文件规划。

资产目录：

- `docs/assets/`：当前有效资产，只保留 V4 原型；
- `docs/old_documents/`：旧稿和归档资产。

### 1.3 `samples/`

用于存放本地测试 Markdown 样例，覆盖：

- 普通 PRD；
- 长文档；
- 表格；
- 代码块；
- 标题层级复杂文档；
- 批注锚点恢复测试文档。

### 1.4 `scripts/`

用于存放后续开发脚本，例如：

- Markdown fixture 生成；
- 本地质量检查；
- 文档链接检查；
- 构建辅助脚本。

### 1.5 `.github/`

用于存放 GitHub 配置，例如：

- issue 模板；
- pull request 模板；
- CI workflow。

V1 未创建自动 CI，因为当前还没有真实 Swift 工程。

---

## 2. Git 约定

### 2.1 默认分支

默认分支使用 `main`。

### 2.2 Commit 风格

建议使用简洁动作式提交：

```text
docs: add product and technical planning
app: scaffold macOS workspace
core: implement anchor resolver
prompt: add codex template builder
```

### 2.3 分支命名

建议：

```text
feature/reader-selection
feature/prompt-builder
fix/anchor-restore
docs/update-prd
```

---

## 3. 本地数据约定

MarkPrompt 运行时可能生成：

```text
*.review.json
*.prompt.md
```

这些通常是本地审稿产物，默认不进入 Git。若需要把样例审稿数据纳入仓库，应放到 `samples/` 下。

---

## 4. 下一步工程化动作

建议顺序：

1. 创建原生 macOS Xcode 工程；
2. 引入 `swift-markdown`；
3. 搭建三栏主窗口；
4. 实现 Markdown 读取和阅读区；
5. 实现文本选区和批注锚点；
6. 实现 PromptBuilder；
7. 补测试和打包配置。

