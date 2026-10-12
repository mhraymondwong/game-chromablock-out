#!/usr/bin/env python3
"""Generate ORIGINAL cheerful kids cartoon UI art for Color Block Escape.
No scraped commercial art — all procedural PIL drawing.
Outputs under assets/ui/
"""
from __future__ import annotations

import math
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "ui"
OUT.mkdir(parents=True, exist_ok=True)

BTN_COLORS = {
    "undo": (110, 170, 245),
    "reset": (245, 150, 100),
    "hint": (255, 210, 70),
    "map": (120, 205, 130),
    "rules": (190, 160, 240),
}

GATE_COLORS = {
    "red": (235, 90, 100),
    "blue": (80, 150, 240),
    "green": (90, 200, 120),
    "yellow": (250, 200, 60),
    "purple": (180, 120, 230),
    "orange": (255, 150, 70),
}


def save(im: Image.Image, name: str) -> Path:
    path = OUT / name
    im.save(path, "PNG")
    print(f"  wrote {path.relative_to(ROOT)} ({im.size[0]}x{im.size[1]})")
    return path


def soft_circle(draw, xy, r, fill, outline=None, width=1):
    x, y = xy
    draw.ellipse([x - r, y - r, x + r, y + r], fill=fill, outline=outline, width=width)


def round_rect(draw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def draw_icon(draw: ImageDraw.ImageDraw, kind: str, cx: int, cy: int, s: int) -> None:
    white = (255, 255, 255, 255)
    w = max(4, s // 9)
    if kind == "undo":
        r = int(s * 0.32)
        draw.arc([cx - r, cy - r, cx + r, cy + r], 50, 320, fill=white, width=w)
        ang = math.radians(320)
        tipx = cx + r * math.cos(ang)
        tipy = cy + r * math.sin(ang)
        tang = ang - math.pi / 2
        hx, hy = math.cos(tang), math.sin(tang)
        px, py = -hy, hx
        ah, aw = s * 0.18, s * 0.12
        draw.polygon(
            [
                (tipx + hx * ah * 0.2, tipy + hy * ah * 0.2),
                (tipx - hx * ah + px * aw, tipy - hy * ah + py * aw),
                (tipx - hx * ah - px * aw, tipy - hy * ah - py * aw),
            ],
            fill=white,
        )
    elif kind == "reset":
        r = int(s * 0.32)
        draw.arc([cx - r, cy - r, cx + r, cy + r], -140, 130, fill=white, width=w)
        ang = math.radians(-140)
        tipx = cx + r * math.cos(ang)
        tipy = cy + r * math.sin(ang)
        tang = ang + math.pi / 2
        hx, hy = math.cos(tang), math.sin(tang)
        px, py = -hy, hx
        ah, aw = s * 0.18, s * 0.12
        draw.polygon(
            [
                (tipx + hx * ah * 0.2, tipy + hy * ah * 0.2),
                (tipx - hx * ah + px * aw, tipy - hy * ah + py * aw),
                (tipx - hx * ah - px * aw, tipy - hy * ah - py * aw),
            ],
            fill=white,
        )
    elif kind == "hint":
        r = int(s * 0.26)
        soft_circle(draw, (cx, cy - 6), r, white)
        bw = int(s * 0.18)
        draw.rounded_rectangle([cx - bw, cy + r - 10, cx + bw, cy + r + int(s * 0.1)], 4, fill=white)
        for ang_d in (-55, -20, 20, 55):
            rad = math.radians(ang_d - 90)
            x0 = cx + math.cos(rad) * (r + 3)
            y0 = cy - 6 + math.sin(rad) * (r + 3)
            x1 = cx + math.cos(rad) * (r + 14)
            y1 = cy - 6 + math.sin(rad) * (r + 14)
            draw.line([(x0, y0), (x1, y1)], fill=white, width=max(3, s // 14))
    elif kind == "map":
        sz = int(s * 0.36)
        draw.rounded_rectangle([cx - sz, cy - sz + 6, cx + sz, cy + sz + 6], 8, fill=white)
        for i, dy in enumerate([-8, 0, 8, 16]):
            soft_circle(draw, (cx - 10 + i * 6, cy + dy), 3, (80, 170, 90, 220))
        soft_circle(draw, (cx, cy - 8), max(6, s // 9), (255, 80, 90, 255))
        draw.polygon([(cx, cy + 10), (cx - 7, cy - 2), (cx + 7, cy - 2)], fill=(255, 80, 90, 255))
    elif kind == "rules":
        soft_circle(draw, (cx, cy), int(s * 0.36), (255, 255, 255, 30), outline=white, width=w)
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", max(28, s // 2))
        except Exception:
            font = ImageFont.load_default()
        bbox = draw.textbbox((0, 0), "?", font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        draw.text((cx - tw // 2 - 1, cy - th // 2 - 6), "?", font=font, fill=white)


def make_button(name: str, size: int = 128, pressed: bool = False) -> Image.Image:
    face = BTN_COLORS[name]
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im, "RGBA")
    pad = 6
    cy_off = 4 if pressed else 0
    if not pressed:
        soft_circle(draw, (size // 2 + 2, size // 2 + 5), size // 2 - pad, (0, 0, 0, 55))
    soft_circle(draw, (size // 2, size // 2 + cy_off), size // 2 - pad, (255, 255, 255, 255))
    fr = size // 2 - pad - 7
    face_col = tuple(max(0, c - (30 if pressed else 0)) for c in face)
    soft_circle(draw, (size // 2, size // 2 + cy_off), fr, (*face_col, 255))
    soft_circle(
        draw,
        (size // 2 - fr // 3, size // 2 - fr // 2 + cy_off),
        max(8, fr // 3),
        (255, 255, 255, 70 if not pressed else 40),
    )
    draw_icon(draw, name, size // 2, size // 2 + cy_off, size - 28)
    return im


def make_background(w: int = 1280, h: int = 720) -> Image.Image:
    im = Image.new("RGBA", (w, h))
    px = im.load()
    for y in range(h):
        t = y / max(1, h - 1)
        for x in range(w):
            tw = 0.5 + 0.5 * math.sin(x / w * math.pi * 2)
            r = int(195 + 35 * tw * (1 - t) + 25 * t)
            g = int(225 - 5 * t + 10 * tw)
            b = int(255 - 25 * t)
            px[x, y] = (min(255, r), min(255, g), min(255, b), 255)

    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer, "RGBA")

    def cloud(cx, cy, s, a=160):
        col = (255, 255, 255, a)
        for ox, oy, rr in [(0, 0, 0.55), (-0.45, 0.08, 0.42), (0.5, 0.05, 0.48), (0.1, -0.25, 0.38), (-0.2, -0.15, 0.32)]:
            soft_circle(d, (int(cx + ox * s), int(cy + oy * s)), int(s * rr), col)

    m = min(w, h)
    cloud(int(w * 0.14), int(h * 0.10), int(m * 0.12), 170)
    cloud(int(w * 0.42), int(h * 0.07), int(m * 0.09), 150)
    cloud(int(w * 0.78), int(h * 0.12), int(m * 0.13), 165)
    cloud(int(w * 0.92), int(h * 0.05), int(m * 0.08), 140)
    cloud(int(w * 0.55), int(h * 0.18), int(m * 0.07), 120)

    balloons = [
        (int(w * 0.07), int(h * 0.28), (255, 120, 150), int(m * 0.035)),
        (int(w * 0.11), int(h * 0.38), (120, 190, 255), int(m * 0.028)),
        (int(w * 0.05), int(h * 0.48), (255, 210, 90), int(m * 0.025)),
        (int(w * 0.92), int(h * 0.30), (170, 230, 130), int(m * 0.032)),
        (int(w * 0.96), int(h * 0.42), (255, 160, 200), int(m * 0.025)),
        (int(w * 0.88), int(h * 0.52), (180, 160, 255), int(m * 0.022)),
    ]
    for bx, by, col, r in balloons:
        d.line([(bx, by + r), (bx + 3, by + r + int(r * 2.2))], fill=(140, 110, 120, 140), width=2)
        soft_circle(d, (bx, by), r, (*col, 220))
        soft_circle(d, (bx - r // 3, by - r // 3), max(3, r // 4), (255, 255, 255, 140))
        soft_circle(d, (bx, by + r - 1), 3, (*col, 230))

    for i in range(36):
        x = int((i * 97 + 31) % (w - 40) + 20)
        y = int((i * 53 + 17) % (h - 40) + 20)
        if 0.22 * w < x < 0.78 * w and 0.18 * h < y < 0.72 * h:
            continue
        cols = [
            (255, 140, 160, 140),
            (140, 200, 255, 140),
            (255, 220, 100, 140),
            (160, 230, 150, 140),
            (200, 160, 255, 140),
        ]
        soft_circle(d, (x, y), 3 + (i % 3), cols[i % 5])

    floor = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    fd = ImageDraw.Draw(floor, "RGBA")
    for y in range(h - 90, h):
        a = int(55 * (y - (h - 90)) / 90)
        fd.line([(0, y), (w, y)], fill=(255, 235, 215, a))

    return Image.alpha_composite(Image.alpha_composite(im, layer), floor)


def make_title_banner(w: int = 720, h: int = 160) -> Image.Image:
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im, "RGBA")
    round_rect(d, [6, 24, w - 6, h - 12], 30, (255, 252, 245, 240), outline=(255, 170, 90, 230), width=5)
    d.rounded_rectangle([18, 32, w - 18, 52], 10, fill=(255, 255, 255, 90))
    cubes = [
        (40, 50, (255, 110, 130)),
        (w - 68, 50, (110, 180, 255)),
        (50, h - 48, (255, 200, 80)),
        (w - 78, h - 48, (130, 220, 140)),
    ]
    for cx, cy, col in cubes:
        d.rounded_rectangle([cx, cy, cx + 26, cy + 26], 6, fill=(*col, 255), outline=(255, 255, 255, 200), width=2)
        soft_circle(d, (cx + 8, cy + 9), 2, (40, 40, 55, 220))
        soft_circle(d, (cx + 18, cy + 9), 2, (40, 40, 55, 220))
        d.arc([cx + 7, cy + 13, cx + 19, cy + 22], 20, 160, fill=(40, 40, 55, 220), width=2)

    def star(cx, cy, r, col):
        pts = []
        for i in range(10):
            ang = -math.pi / 2 + i * math.pi / 5
            rr = r if i % 2 == 0 else r * 0.45
            pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
        d.polygon(pts, fill=col)

    star(110, 38, 12, (255, 210, 60, 255))
    star(w - 120, 38, 11, (255, 210, 60, 255))
    star(w // 2, 34, 9, (255, 230, 120, 255))

    font_paths = [
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
        str(ROOT / "assets" / "fonts" / "NotoSansCJK-Regular.ttc"),
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]
    font_big = font_small = None
    for fp in font_paths:
        if os.path.exists(fp):
            try:
                font_big = ImageFont.truetype(fp, 48 if h >= 150 else 34)
                font_small = ImageFont.truetype(fp, 22 if h >= 150 else 16)
                break
            except Exception:
                continue
    if font_big is None:
        font_big = font_small = ImageFont.load_default()

    title = "彩色方塊逃脫"
    bbox = d.textbbox((0, 0), title, font=font_big)
    tw = bbox[2] - bbox[0]
    tx = (w - tw) // 2
    ty = 50 if h >= 150 else 38
    d.text((tx + 2, ty + 2), title, font=font_big, fill=(200, 120, 60, 150))
    d.text((tx, ty), title, font=font_big, fill=(255, 115, 75, 255))
    sub = "Color Block Escape"
    bbox2 = d.textbbox((0, 0), sub, font=font_small)
    sw = bbox2[2] - bbox2[0]
    d.text(((w - sw) // 2, ty + (52 if h >= 150 else 40)), sub, font=font_small, fill=(120, 100, 90, 220))
    return im


def make_star(on: bool = True, size: int = 64) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im, "RGBA")
    cx = cy = size // 2
    r = size // 2 - 4
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.42
        pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
    if on:
        draw.polygon(pts, fill=(255, 210, 50, 255), outline=(255, 255, 200, 255))
        soft_circle(draw, (cx - 4, cy - 6), size // 8, (255, 255, 255, 120))
    else:
        draw.polygon(pts, fill=(220, 220, 230, 200), outline=(180, 180, 190, 255))
    return im


def make_panel_frame(w: int = 320, h: int = 520) -> Image.Image:
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im, "RGBA")
    round_rect(draw, [4, 4, w - 4, h - 4], 28, (255, 252, 245, 210), outline=(255, 190, 120, 230), width=5)
    draw.rounded_rectangle([12, 12, w - 12, h // 4], 14, fill=(255, 255, 255, 55))
    for x, y, c in [
        (22, 22, (255, 130, 150)),
        (w - 22, 22, (130, 190, 255)),
        (22, h - 22, (255, 210, 90)),
        (w - 22, h - 22, (150, 220, 140)),
    ]:
        soft_circle(draw, (x, y), 8, (*c, 230))
    return im


def make_hud_bar(w: int = 1280, h: int = 96) -> Image.Image:
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im, "RGBA")
    round_rect(draw, [0, 0, w, h], 0, (255, 255, 255, 175))
    draw.rectangle([0, h - 6, w, h], fill=(255, 180, 120, 180))
    for i in range(12):
        x = 40 + i * (w // 12)
        cols = [(255, 140, 160), (140, 190, 255), (255, 210, 90), (150, 220, 140)]
        soft_circle(draw, (x, h - 3), 3, (*cols[i % 4], 200))
    return im


def make_toolbar_bar(w: int = 1280, h: int = 88) -> Image.Image:
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im, "RGBA")
    round_rect(draw, [0, 0, w, h], 0, (255, 250, 245, 210))
    draw.rectangle([0, 0, w, 4], fill=(255, 180, 120, 160))
    return im


def make_gate_deco(color_rgb, size: int = 64) -> Image.Image:
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im, "RGBA")
    pad = 6
    draw.rounded_rectangle(
        [pad, pad + 8, size - pad, size - pad],
        10,
        fill=(*color_rgb, 230),
        outline=(255, 255, 255, 200),
        width=3,
    )
    soft_circle(draw, (size // 2, pad + 10), size // 2 - pad - 2, (*color_rgb, 230))
    soft_circle(draw, (size // 2 - 6, pad + 14), 6, (255, 255, 255, 100))
    soft_circle(draw, (size // 2 + 8, size // 2 + 6), 4, (255, 255, 255, 200))
    return im


def main() -> None:
    print("Generating kids UI art →", OUT)
    save(make_background(1280, 720), "bg_playroom.png")
    save(make_background(720, 1280), "bg_playroom_portrait.png")
    save(make_title_banner(720, 160), "title_banner.png")
    save(make_title_banner(480, 120), "title_banner_sm.png")
    for name in BTN_COLORS:
        save(make_button(name, 128, False), f"btn_{name}.png")
        save(make_button(name, 128, True), f"btn_{name}_pressed.png")
    save(make_star(True, 64), "star_on.png")
    save(make_star(False, 64), "star_off.png")
    save(make_panel_frame(320, 520), "panel_frame.png")
    save(make_hud_bar(1280, 96), "hud_bar.png")
    save(make_toolbar_bar(1280, 88), "toolbar_bar.png")
    for name, rgb in GATE_COLORS.items():
        save(make_gate_deco(rgb, 64), f"gate_{name}.png")
    print("Done.")


if __name__ == "__main__":
    main()
