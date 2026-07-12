#!/usr/bin/env python3
"""Generates the CompressX app icon: cyan->violet gradient tile with four
bold arrows converging to the center (an implicit X). Writes Android
mipmaps, Linux PNGs and the Windows .ico."""
import math

from PIL import Image, ImageDraw, ImageFilter

CYAN = (0, 212, 255)
VIOLET = (124, 58, 237)


def gradient(size):
    img = Image.new('RGB', (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = tuple(
                round(CYAN[i] + (VIOLET[i] - CYAN[i]) * t) for i in range(3))
    return img


def arrow_layer(size):
    """Four arrows pointing inward from the corners, with a soft shadow."""
    layer = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(layer)
    s = size
    shaft_w = round(s * 0.085)
    inv = 1 / math.sqrt(2)
    for sx in (1, -1):
        for sy in (1, -1):
            def pt(v):
                x, y = v
                return (s * (0.5 + sx * (x - 0.5)), s * (0.5 + sy * (y - 0.5)))

            tip = pt((0.455, 0.455))
            base = pt((0.455 - 0.115 * inv, 0.455 - 0.115 * inv))
            start = pt((0.24, 0.24))
            d.line([start, base], fill=255, width=shaft_w)
            # rounded shaft end at the corner side
            r = shaft_w / 2
            d.ellipse([start[0] - r, start[1] - r, start[0] + r, start[1] + r],
                      fill=255)
            # arrowhead
            hw = s * 0.105
            perp = (-sy * inv * hw, sx * inv * hw)
            d.polygon([
                tip,
                (base[0] + perp[0], base[1] + perp[1]),
                (base[0] - perp[0], base[1] - perp[1]),
            ], fill=255)
    return layer


def make_icon(size, super_sample=4):
    s = size * super_sample
    img = gradient(s).convert('RGBA')
    arrows = arrow_layer(s)
    # soft dark shadow for depth, offset slightly down
    shadow = arrows.filter(ImageFilter.GaussianBlur(s * 0.02))
    dark = Image.new('RGBA', (s, s), (10, 20, 60, 110))
    img.paste(dark, (0, round(s * 0.012)), shadow)
    img.paste((255, 255, 255, 255), (0, 0), arrows)
    # rounded-square mask
    mask = Image.new('L', (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, s - 1, s - 1], radius=s * 0.22, fill=255)
    img.putalpha(mask)
    return img.resize((size, size), Image.LANCZOS)


mips = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
for dpi, size in mips.items():
    make_icon(size).save(
        f'android/app/src/main/res/mipmap-{dpi}/ic_launcher.png')
make_icon(512).save('assets/icon/smart_compress.png')
make_icon(256).save('assets/icon/smart_compress_256.png')
make_icon(256).save(
    'windows/runner/resources/app_icon.ico',
    sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128),
           (256, 256)])
print('icons written')
