#!/usr/bin/env python3
"""
GPT Image Generation Script
Usage: gen.py "prompt" [output_path] [size] [quality] [count]
Example: gen.py "a cute cat" /workspace/out.png 1024x1024 high 1

Environment variables:
  IMAGE_GEN_API_URL  — OpenAI-compatible images endpoint (required)
  IMAGE_GEN_API_KEY  — API key for Bearer auth (required)
"""

import json
import os
import sys
import base64
import urllib.request
import urllib.error


# API endpoint from environment variable (desensitized — no hardcoded URL)
API_URL = os.environ.get("IMAGE_GEN_API_URL", "")
MODEL = "gpt-image-2"

VALID_SIZES = ["1024x1024", "1536x1024", "1024x1536", "2048x2048"]
VALID_QUALITIES = ["low", "medium", "high"]


def generate_image(prompt, output_path=None, size="1024x1024", quality="high", count=1):
    api_key = os.environ.get("IMAGE_GEN_API_KEY", "")
    if not api_key:
        print("ERROR: 环境变量 'IMAGE_GEN_API_KEY' 未设置，请先设置 API Key")
        sys.exit(1)

    if not API_URL:
        print("ERROR: 环境变量 'IMAGE_GEN_API_URL' 未设置，请先设置 API 端点")
        sys.exit(1)

    if size not in VALID_SIZES:
        print(f"ERROR: 无效尺寸 '{size}'，可选: {', '.join(VALID_SIZES)}")
        sys.exit(1)

    if quality not in VALID_QUALITIES:
        print(f"ERROR: 无效质量 '{quality}'，可选: {', '.join(VALID_QUALITIES)}")
        sys.exit(1)

    if count < 1 or count > 10:
        print("ERROR: count 必须在 1-10 之间")
        sys.exit(1)

    if output_path is None:
        output_path = "/workspace/generated_image.png"

    payload = {
        "model": MODEL,
        "prompt": prompt,
        "size": size,
        "quality": quality,
        "n": count,
    }

    data = json.dumps(payload).encode("utf-8")

    req = urllib.request.Request(
        API_URL,
        data=data,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            # Some API gateways reject Python's default User-Agent (403).
            # Using a standard curl UA as a widely-compatible default.
            "User-Agent": "curl/8.14.1",
        },
        method="POST",
    )

    print(f"正在生成图片: {prompt}")
    print(f"尺寸: {size}, 质量: {quality}, 数量: {count}")
    print("请稍候，图片生成可能需要 30-120 秒...")

    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            body = resp.read().decode("utf-8")
            result = json.loads(body)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"ERROR: HTTP {e.code} - {body}")
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: 请求失败 - {e}")
        sys.exit(1)

    if "data" not in result or not result["data"]:
        if "error" in result:
            print(f"ERROR: API 返回错误 - {result['error']}")
        else:
            print(f"ERROR: 无效的 API 响应 - {json.dumps(result, indent=2)}")
        sys.exit(1)

    # Save each image
    saved_files = []
    for i, item in enumerate(result["data"]):
        if "b64_json" not in item:
            print(f"WARNING: 第 {i+1} 张图片缺少 b64_json，跳过")
            continue

        img_bytes = base64.b64decode(item["b64_json"])

        if count == 1:
            out_file = output_path
        else:
            base, ext = os.path.splitext(output_path)
            out_file = f"{base}_{i+1}{ext}"

        with open(out_file, "wb") as f:
            f.write(img_bytes)

        saved_files.append(out_file)
        print(f"已保存: {out_file} ({len(img_bytes)} bytes)")

    print(f"完成！共生成 {len(saved_files)} 张图片")
    return saved_files


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    prompt = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None
    size = sys.argv[3] if len(sys.argv) > 3 else "1024x1024"
    quality = sys.argv[4] if len(sys.argv) > 4 else "high"
    count = int(sys.argv[5]) if len(sys.argv) > 5 else 1

    generate_image(prompt, output_path, size, quality, count)


if __name__ == "__main__":
    main()
