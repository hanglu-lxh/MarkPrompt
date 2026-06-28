# MarkPrompt macOS App

这里是 MarkPrompt 原生 macOS 应用的 Swift Package。

## 要求

- macOS 14+
- Swift 6 工具链

## 运行

```bash
cd app/MarkPrompt
swift run MarkPrompt
```

启动后可以通过工具栏或 `⌘O` 打开 Markdown 文件。仓库里有一个可用于试用的样例：

```text
samples/markdown/sample_prd.md
```

## 测试

```bash
cd app/MarkPrompt
swift test
```

## 本地打包

生成 `.app`：

```bash
cd app/MarkPrompt
./scripts/package_app.sh
```

生成 `.dmg`：

```bash
cd app/MarkPrompt
./scripts/package_dmg.sh
```

当前 V1.1 打包产物会生成到仓库根目录：

```text
build/MarkPrompt.app
build/MarkPrompt-1.1.dmg
```

`build/` 是本地构建输出目录，不提交到 Git。
