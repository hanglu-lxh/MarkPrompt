# Reader Fixture: Wide Tables

## Model Overview

| Model | Developer | Release | Parameters | Architecture | License | Minimum VRAM | Notes |
|---|---|---:|---:|---|---|---:|---|
| **FLUX.2 [dev]** (4bit) | Black Forest Labs | 2025.11 | 32B | MMDiT + VLM | Non-commercial free / commercial license required | ~20GB | Very wide row that should wrap inside a native table cell instead of breaking table borders |
| FLUX.1 [schnell] (4bit) | Black Forest Labs | 2024.08 | 12B | MMDiT distilled | [Apache 2.0](https://www.apache.org/licenses/LICENSE-2.0) | ~12GB | Fast local `generation` |
| Qwen-Image-2512 (4bit) | Alibaba | 2025.08 | 20B | MMDiT | Apache 2.0 | ~16GB | Strong text rendering |
| SD 3.5 Large | Stability AI | 2024.10 | 8.1B | MMDiT | Community under $1M revenue | ~16GB | Baseline open model |
| HunyuanDiT | Tencent | 2024 | -- | DiT | Open | ~12GB | :warning: ~~Needs careful license review~~ |

## Chinese Model Overview

| 模型 | 开发方 | 参数量 | 架构 | 开源协议 | 最低显存 | 发布时间 |
|------|--------|--------|------|----------|----------|----------|
| **FLUX.2 [dev]** | Black Forest Labs | 32B | MMDiT + VLM | 非商用免费/商用需授权 | ~20GB (4bit) | 2025.11 |
| **FLUX.1 [schnell]** | Black Forest Labs | 12B | MMDiT (蒸馏) | **Apache 2.0** ✅ | ~12GB (4bit) | 2024.08 |
| **Qwen-Image-2512** | 阿里巴巴 | 20B | MMDiT | **Apache 2.0** ✅ | ~16GB (4bit) | 2025.08 |

## Narrow Table

| Key | Value |
|---|---|
| Status | Expected to render as a native TextKit table |
| Risk | Selection &amp; anchor mapping must still work |

## Evidence Table

| Evidence | Preview | Status |
|---|---|---|
| Screenshot | ![[../../../docs/assets/markprompt_interaction_prototype_v4.png|140]] | Ready for annotation |
