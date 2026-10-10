---
name: gpt-image-gen
description: 通过 GPT Image API (gpt-image-2) 生成图片。当用户提到"生成图片"、"画一张图"、"GPT 图片"、"image generation"、或需要 AI 绘图时触发此 skill。使用环境变量 $IMAGE_GEN_API_KEY 作为 API Key，调用 OpenAI 兼容的图片生成接口。
---

# GPT Image Generation Skill

通过 GPT Image API 生成高质量图片。

## Quick Workflow

1. 检查环境变量 `$IMAGE_GEN_API_KEY` 和 `$IMAGE_GEN_API_URL` 是否已设置
2. 构造 prompt 并确定尺寸
3. 直接运行 bundled 脚本 `scripts/gen.py`
4. 将输出图片保存到 workspace 并展示

## Environment Setup

### 必需环境变量

```bash
export IMAGE_GEN_API_KEY="sk-xxx"                              # API Key
export IMAGE_GEN_API_URL="https://your-api.example.com/v1/images/generations"  # API 端点
```

### Check API Key

```bash
echo $IMAGE_GEN_API_KEY | head -c 10
```

如果为空，提示用户设置环境变量。

## Bundled Scripts

运行脚本（无额外依赖，仅用 Python 标准库）：

```bash
python3 <skill-path>/gpt-image-gen/scripts/gen.py "prompt" [output_path] [size] [quality] [count]
```

参数说明：
- `prompt` — 图片描述（必填）
- `output_path` — 输出文件路径，默认 `/workspace/generated_image.png`
- `size` — 图片尺寸，可选 `1024x1024` / `1536x1024` / `1024x1536` / `2048x2048`，默认 `1024x1024`
- `quality` — 质量，可选 `low` / `medium` / `high`，默认 `high`
- `count` — 生成数量 1-10，默认 `1`

示例：
```bash
python3 <skill-path>/gpt-image-gen/scripts/gen.py "一位年轻漂亮的中国小红书女博主，时尚穿搭，精致妆容" /workspace/out.png 1024x1536 high 1
```

## Step-by-Step

当用户请求生成图片时：

1. **理解需求** — 确定 prompt、尺寸偏好、风格
2. **检查环境变量** — `echo $IMAGE_GEN_API_KEY | head -c 10`
3. **运行脚本** — 传入参数调用 `gen.py`
4. **展示结果** — 用 `![caption](omnibot://workspace/generated_image.png)` 展示
5. **复制下载** — 按需额外 copy 到 `/storage/emulated/0/Download/`

## API Reference

- **Endpoint**: 由环境变量 `$IMAGE_GEN_API_URL` 指定，需兼容 OpenAI Images API 格式
- **Auth**: `Authorization: Bearer $IMAGE_GEN_API_KEY`
- **Model**: `gpt-image-2`
- **Response**: JSON with `data[0].b64_json` (base64 encoded PNG)
- **Sizes**: `1024x1024`, `1536x1024` (横屏), `1024x1536` (竖屏), `2048x2048`
- **Qualities**: `low`, `medium`, `high`

## 网关兼容性说明

部分 API 网关（如 New API）会拒绝 Python `urllib` 的默认 User-Agent，返回 403。脚本已内置 `curl/8.14.1` 的 UA 头来规避此问题。如仍有兼容性问题，可修改 `scripts/gen.py` 中的 `User-Agent` 头。

## Troubleshooting

| Issue | Cause & Fix |
|-------|-------------|
| `IMAGE_GEN_API_KEY` 未设置 | 提示用户先 `export IMAGE_GEN_API_KEY=sk-xxx` |
| `IMAGE_GEN_API_URL` 未设置 | 提示用户设置 API 端点 |
| HTTP 401/403 | Key 无效或过期，或 User-Agent 被网关拒绝 |
| HTTP 429 | 频率限制，稍等重试 |
| HTTP 502/524 | 上游服务不可用或超时，稍等重试 |
| 超时 | 图片生成较慢，timeout 设 300 秒 |
| 返回非图片内容 | API 返回异常 JSON，检查 error 字段 |
