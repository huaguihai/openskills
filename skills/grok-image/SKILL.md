---
name: grok-image
description: |
  AI image generation and editing using Grok Imagine models. Use this skill for ANY
  request to create, generate, draw, design, or edit an image — regardless of whether
  the user mentions "grok". This includes:
  - Creating images from text descriptions in any language (中文/English)
  - Editing existing images (changing backgrounds, style transfer, 二次元化)
  - Generating logos, banners, illustrations, concept art, avatars
  - Quick sketches and fast generation mode
  - Delivering generated images to Feishu/Lark/Telegram
  Trigger on ANY of these patterns: "生成图片", "画一张", "画个", "帮我画",
  "AI画图", "出一张图", "来一张", "grok 生图", "grok image", "generate image",
  "make an image", "draw me", "create a picture", "design a logo", "换背景",
  "风格转换", "二次元化", "hero banner", or /grok-image.
  Do NOT trigger for: image compression/resizing/format conversion, OCR/text extraction,
  screenshot capture, analyzing existing images, or writing image generation code/API calls.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - AskUserQuestion
---

# Grok Image Generation Skill

## Workflow

1. **Receive description** — the user describes what they want in any language
2. **Craft prompt** — translate to English, add style-appropriate quality keywords
3. **Pick model** — choose variant based on need (see Model Selection below)
4. **Generate** — run the script; it handles provider discovery and failover
5. **Display** — Read the output image file to show the user
6. **Deliver** (optional) — send to Feishu if the user asks

## Commands

### Generate

```bash
bash ${CLAUDE_SKILL_DIR}/bin/generate.sh "<english_prompt>" [size] [model]
```

| Parameter | Required | Default | Options |
|-----------|----------|---------|---------|
| prompt | yes | — | English text |
| size | no | 1024x1024 | 1024x1024, 1024x1792, 1792x1024 |
| model | no | grok-imagine-1.0 | grok-imagine-1.0, grok-imagine-1.0-fast, grok-imagine-1.0-edit |

The script:
- Reads providers from `~/clawd/proxy/config.json`
- Tries each matching provider, falling back to other grok-imagine variants
- Skips auth errors (401/403), retries on rate limits (429) and timeouts
- Outputs image path to stdout on success, exits 1 on failure

### Send to Feishu

```bash
bash ${CLAUDE_SKILL_DIR}/bin/send-feishu.sh <image_path>
```

Reads config from `~/.claude-to-im/config.env`, auto-handles token + upload + send.

## Model Selection

- **grok-imagine-1.0** — best quality, use by default for most requests
- **grok-imagine-1.0-fast** — faster but slightly lower quality, good when speed matters
- **grok-imagine-1.0-edit** — for image modification concepts

## Prompt Crafting

Translate the user's idea to fluent English, then add keywords matching the style:

- **Photo / Portrait**: cinematic photography, ultra realistic, soft bokeh, golden hour lighting
- **Illustration / Cartoon**: digital illustration, vibrant colors, detailed, trending on artstation
- **Concept Art**: concept art, highly detailed, dramatic lighting, 8k resolution

Keep the user's creative intent intact — enhance, don't override.

## Example

User: "画一张赛博朋克风格的城市夜景"

1. Prompt: `"A cyberpunk cityscape at night, neon lights reflecting on wet streets, towering skyscrapers with holographic ads, flying vehicles, cinematic photography, ultra realistic, 8k resolution"`
2. `bash ${CLAUDE_SKILL_DIR}/bin/generate.sh "A cyberpunk cityscape..." "1024x1024"`
3. Read the output file to display
4. If asked: `bash ${CLAUDE_SKILL_DIR}/bin/send-feishu.sh /tmp/grok_image_xxx.jpg`

## Notes

- Generation takes 5-30 seconds depending on provider and model
- Images save to `/tmp/grok_image_<timestamp>.jpg` (cleaned on reboot)
- If all providers fail, suggest trying again later
