#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
build_ico.py — 一张方图生成 Windows 多尺寸 .ico

规格（可用参数覆盖）：
  超椭圆遮罩 |u/R|^n + |v/R|^n <= 1，R = 23%，n = 5，4x 超采样
  底部标签栏：高度 10.16%，填充 rgba(12,12,16,178)
  文字：微软雅黑 Bold，自动缩到 宽 <= 700 且 高 <= 栏高 - 20
  尺寸：256 / 128 / 64 / 48 / 32 / 16；64 及以下只留栏不画字；16 为纯头像

用法：
  python build_ico.py --input app.png --output App.ico --text "App"
  python build_ico.py --input app.png --output App.ico --text "App" --head-x 0.46 --head-y 0.49 --crop 0.72
  python build_ico.py --input app.png --output App.ico --no-bar --no-text
"""

import argparse
import io
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageEnhance, ImageFilter

CANVAS = 1024
BAR_RATIO = 0.1016
BAR_FILL = (12, 12, 16, 178)
MASK_RADIUS = 0.23
MASK_EXP = 5.0
SUPERSAMPLE = 4
TEXT_MAX_WIDTH = 700
SIZES = [256, 128, 64, 48, 32, 16]


def load_font(size: int) -> ImageFont.FreeTypeFont:
    candidates = [
        r"C:\Windows\Fonts\msyhbd.ttc",
        r"C:\Windows\Fonts\msyh.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


def crop_square(img: Image.Image, head_x: float, head_y: float, crop: float) -> Image.Image:
    w, h = img.size
    base = min(w, h)
    crop_side = max(16, int(base * crop))
    cx, cy = int(w * head_x), int(h * head_y)
    left = min(max(0, cx - crop_side // 2), w - crop_side)
    top = min(max(0, cy - crop_side // 2), h - crop_side)
    return img.crop((left, top, left + crop_side, top + crop_side)).resize((CANVAS, CANVAS), Image.LANCZOS)


def fit_font(draw: ImageDraw.ImageDraw, text: str, max_w: int, max_h: int) -> ImageFont.FreeTypeFont:
    size = max_h + 20
    while size > 8:
        font = load_font(size)
        box = draw.textbbox((0, 0), text, font=font)
        tw, th = box[2] - box[0], box[3] - box[1]
        if tw <= max_w and th <= max_h:
            return font
        size -= 2
    return load_font(10)


def add_bar(img: Image.Image, text: str, bar_ratio: float = BAR_RATIO) -> Image.Image:
    """在母版上加底栏与文字；调用方按尺寸决定是否带字"""
    bar_h = int(round(CANVAS * bar_ratio))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rectangle([0, CANVAS - bar_h, CANVAS, CANVAS], fill=BAR_FILL)

    if text:
        max_w = min(TEXT_MAX_WIDTH, CANVAS - 80)
        max_h = bar_h - 20
        font = fit_font(d, text, max_w, max_h)
        box = d.textbbox((0, 0), text, font=font)
        tw, th = box[2] - box[0], box[3] - box[1]
        x = (CANVAS - tw) / 2 - box[0]
        y = CANVAS - bar_h + (bar_h - th) / 2 - box[1]
        d.text((x, y), text, font=font, fill=(255, 255, 255, 255))

    return Image.alpha_composite(img, layer)


def squircle_mask(size: int = CANVAS, radius_ratio: float = MASK_RADIUS, exp: float = MASK_EXP,
                  shape: str = "rounded") -> Image.Image:
    """外轮廓遮罩：默认圆角矩形（半径 23%），shape=superellipse 时用 |u|^n+|v|^n<=1"""
    ss = size * SUPERSAMPLE
    if shape == "rounded":
        m = Image.new("L", (ss, ss), 0)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, ss - 1, ss - 1], radius=int(radius_ratio * ss), fill=255)
    else:
        yy, xx = np.mgrid[0:ss, 0:ss]
        half = ss / 2.0
        u = (xx + 0.5 - half) / half
        v = (yy + 0.5 - half) / half
        inside = (np.abs(u) ** exp + np.abs(v) ** exp) <= 1.0
        m = Image.fromarray((inside * 255).astype(np.uint8), mode="L")
    return m.resize((size, size), Image.LANCZOS)


def apply_mask(img: Image.Image, mask: Image.Image) -> Image.Image:
    out = img.copy()
    alpha = out.split()[3]
    alpha = Image.fromarray((np.asarray(alpha, dtype=np.float32) * (np.asarray(mask, dtype=np.float32) / 255.0)).astype(np.uint8))
    out.putalpha(alpha)
    return out


def make_16(art: Image.Image) -> Image.Image:
    small = art.resize((16, 16), Image.LANCZOS)
    small = ImageEnhance.Contrast(small).enhance(1.15)
    small = small.filter(ImageFilter.UnsharpMask(radius=1.2, percent=35))
    return small


def write_ico(frames: dict, output: str) -> None:
    entries = []
    data_blocks = []
    offset = 6 + 16 * len(frames)
    for size in sorted(frames.keys(), reverse=True):
        raw = io.BytesIO()
        frames[size].save(raw, format="PNG")
        blob = raw.getvalue()
        width = 0 if size >= 256 else size
        height = 0 if size >= 256 else size
        entries.append(struct.pack("<BBBBHHII", width, height, 0, 0, 1, 32, len(blob), offset))
        data_blocks.append(blob)
        offset += len(blob)

    with open(output, "wb") as f:
        f.write(struct.pack("<HHH", 0, 1, len(frames)))
        for e in entries:
            f.write(e)
        for b in data_blocks:
            f.write(b)


def main() -> int:
    ap = argparse.ArgumentParser(description="生成多尺寸 Windows 图标")
    ap.add_argument("--input", required=True, help="源图（建议 1024x1024 PNG）")
    ap.add_argument("--output", required=True, help="输出 .ico")
    ap.add_argument("--text", default="", help="标签栏文字，留空则无字")
    ap.add_argument("--head-x", type=float, default=0.5, help="16px 头像取景中心 X（0-1）")
    ap.add_argument("--head-y", type=float, default=0.45, help="16px 头像取景中心 Y（0-1）")
    ap.add_argument("--crop", type=float, default=1.0, help="主图取景边长占原图短边比例，1.0=整图居中")
    ap.add_argument("--face-crop", type=float, default=0.36, help="16px 头像取景占比，越小脸越大")
    ap.add_argument("--shape", choices=["rounded", "superellipse"], default="rounded", help="外轮廓形状")
    ap.add_argument("--radius", type=float, default=MASK_RADIUS, help="圆角半径占比 / 超椭圆半径比")
    ap.add_argument("--exponent", type=float, default=MASK_EXP, help="超椭圆指数 n（仅 shape=superellipse 生效）")
    ap.add_argument("--bar-ratio", type=float, default=BAR_RATIO, help="标签栏高度占比")
    ap.add_argument("--no-bar", action="store_true", help="不要标签栏")
    ap.add_argument("--no-text", action="store_true", help="不要标签文字")
    ap.add_argument("--emit-png", action="store_true", help="同时输出各尺寸 PNG 便于核对")
    args = ap.parse_args()

    src = Image.open(args.input).convert("RGBA")
    art = crop_square(src, 0.5, 0.5, args.crop)

    if args.no_bar:
        masked = apply_mask(art, squircle_mask(exp=args.exponent, radius_ratio=args.radius, shape=args.shape))
    else:
        text = "" if args.no_text else args.text
        with_text = add_bar(art, text, args.bar_ratio)
        no_text = add_bar(art, "", args.bar_ratio)
        masked = apply_mask(with_text, squircle_mask(exp=args.exponent, radius_ratio=args.radius, shape=args.shape))
        masked_no_text = apply_mask(no_text, squircle_mask(exp=args.exponent, radius_ratio=args.radius, shape=args.shape))

    frames = {}
    head_crop = crop_square(src, args.head_x, args.head_y, args.face_crop)
    for size in SIZES:
        if size == 16:
            frames[size] = make_16(head_crop)
            continue
        if args.no_bar:
            frames[size] = masked.resize((size, size), Image.LANCZOS)
        else:
            use_text = size > 64
            base = masked if use_text else masked_no_text
            frames[size] = base.resize((size, size), Image.LANCZOS)

    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    write_ico(frames, args.output)
    print(f"ico written: {args.output} ({os.path.getsize(args.output)/1024:.0f} KB, {len(frames)} frames)")

    if args.emit_png:
        stem, _ = os.path.splitext(args.output)
        (masked if not args.no_bar else masked).save(f"{stem}_1024.png")
        for size, im in frames.items():
            im.save(f"{stem}_{size}.png")
        print(f"pngs written: {stem}_1024.png + {len(frames)} sizes")

    return 0


if __name__ == "__main__":
    sys.exit(main())
