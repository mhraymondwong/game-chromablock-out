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

BADGE_COLORS = {
    "level": (255, 140, 170),
    "time": (90, 200, 170),
    "moves": (255, 170, 90),
    "score": (255, 210, 70),
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


def load_cjk_font(size: int):
    font_paths = [
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
        str(ROOT / "assets" / "fonts" / "NotoSansCJK-Regular.ttc"),
        "/usr/share/fonts/truetype/noto/NotoSansCJK-Bold.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ]
    for fp in font_paths:
        if os.path.exists(fp):
            try:
                return ImageFont.truetype(fp, size)
            except Exception:
                continue
    return ImageFont.load_default()


def draw_cute_cube(d, cx, cy, size, col):
    """Friendly square character with eyes and smile."""
    half = size // 2
    round_rect(
        d,
        [cx - half, cy - half, cx + half, cy + half],
        max(6, size // 5),
        (*col, 255),
        outline=(255, 255, 255, 230),
        width=max(2, size // 16),
    )
    # gloss
    round_rect(
        d,
        [cx - half + 4, cy - half + 4, cx + half - 4, cy - half + size // 3],
        6,
        (255, 255, 255, 90),
    )
    eye_r = max(2, size // 12)
    soft_circle(d, (cx - size // 5, cy - size // 10), eye_r, (40, 40, 55, 240))
    soft_circle(d, (cx + size // 5, cy - size // 10), eye_r, (40, 40, 55, 240))
    soft_circle(d, (cx - size // 5 - 1, cy - size // 10 - 1), max(1, eye_r // 2), (255, 255, 255, 200))
    soft_circle(d, (cx + size // 5 - 1, cy - size // 10 - 1), max(1, eye_r // 2), (255, 255, 255, 200))
    d.arc(
        [cx - size // 5, cy, cx + size // 5, cy + size // 4],
        20,
        160,
        fill=(40, 40, 55, 230),
        width=max(2, size // 18),
    )


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


def make_button(name: str, size: int = 192, pressed: bool = False) -> Image.Image:
    face = BTN_COLORS[name]
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im, "RGBA")
    pad = 8
    cy_off = 6 if pressed else 0
    if not pressed:
        soft_circle(draw, (size // 2 + 3, size // 2 + 8), size // 2 - pad, (0, 0, 0, 55))
    soft_circle(draw, (size // 2, size // 2 + cy_off), size // 2 - pad, (255, 255, 255, 255))
    fr = size // 2 - pad - 10
    face_col = tuple(max(0, c - (30 if pressed else 0)) for c in face)
    soft_circle(draw, (size // 2, size // 2 + cy_off), fr, (*face_col, 255))
    soft_circle(
        draw,
        (size // 2 - fr // 3, size // 2 - fr // 2 + cy_off),
        max(10, fr // 3),
        (255, 255, 255, 70 if not pressed else 40),
    )
    draw_icon(draw, name, size // 2, size // 2 + cy_off, size - 40)
    return im


def make_background(w: int = 720, h: int = 1280) -> Image.Image:
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
    cloud(int(w * 0.14), int(h * 0.08), int(m * 0.14), 175)
    cloud(int(w * 0.55), int(h * 0.05), int(m * 0.11), 155)
    cloud(int(w * 0.88), int(h * 0.10), int(m * 0.13), 165)
    cloud(int(w * 0.30), int(h * 0.14), int(m * 0.08), 130)
    cloud(int(w * 0.72), int(h * 0.16), int(m * 0.09), 140)

    balloons = [
        (int(w * 0.06), int(h * 0.22), (255, 120, 150), int(m * 0.04)),
        (int(w * 0.12), int(h * 0.30), (120, 190, 255), int(m * 0.032)),
        (int(w * 0.05), int(h * 0.38), (255, 210, 90), int(m * 0.028)),
        (int(w * 0.94), int(h * 0.24), (170, 230, 130), int(m * 0.038)),
        (int(w * 0.97), int(h * 0.34), (255, 160, 200), int(m * 0.028)),
        (int(w * 0.90), int(h * 0.42), (180, 160, 255), int(m * 0.026)),
    ]
    for bx, by, col, r in balloons:
        d.line([(bx, by + r), (bx + 3, by + r + int(r * 2.2))], fill=(140, 110, 120, 140), width=2)
        soft_circle(d, (bx, by), r, (*col, 220))
        soft_circle(d, (bx - r // 3, by - r // 3), max(3, r // 4), (255, 255, 255, 140))
        soft_circle(d, (bx, by + r - 1), 3, (*col, 230))

    for i in range(48):
        x = int((i * 97 + 31) % (w - 40) + 20)
        y = int((i * 53 + 17) % (h - 40) + 20)
        if 0.18 * w < x < 0.82 * w and 0.18 * h < y < 0.72 * h:
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
    for y in range(h - 110, h):
        a = int(60 * (y - (h - 110)) / 110)
        fd.line([(0, y), (w, y)], fill=(255, 235, 215, a))

    return Image.alpha_composite(Image.alpha_composite(im, layer), floor)


def star_poly(d, cx, cy, r, col):
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + rr * math.cos(ang), cy + rr * math.sin(ang)))
    d.polygon(pts, fill=col)


def make_title_banner(w: int = 960, h: int = 260) -> Image.Image:
    """BIG lovable cartoon title — clear Chinese + English, cute block pals."""
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im, "RGBA")

    # Soft drop shadow
    round_rect(d, [18, 28, w - 10, h - 8], 40, (0, 0, 0, 40))
    # Main creamy plaque
    round_rect(d, [10, 18, w - 18, h - 18], 40, (255, 252, 245, 245), outline=(255, 160, 80, 240), width=7)
    # Inner white gloss strip
    d.rounded_rectangle([28, 30, w - 36, 70], 16, fill=(255, 255, 255, 100))
    # Soft peach inner rim
    d.rounded_rectangle([22, 26, w - 30, h - 26], 34, outline=(255, 200, 140, 120), width=3)

    # Rainbow candy dots along top edge
    rainbow = [
        (255, 110, 130),
        (255, 170, 80),
        (255, 220, 80),
        (120, 210, 130),
        (110, 180, 255),
        (190, 140, 240),
    ]
    for i, col in enumerate(rainbow):
        x = 70 + i * ((w - 140) // max(1, len(rainbow) - 1))
        soft_circle(d, (x, 28), 8, (*col, 230))
        soft_circle(d, (x - 2, 26), 3, (255, 255, 255, 160))

    # Big cute cube characters left & right
    cube_sz = 72
    draw_cute_cube(d, 70, h // 2 + 8, cube_sz, (255, 110, 130))
    draw_cute_cube(d, w - 78, h // 2 + 8, cube_sz, (110, 180, 255))
    draw_cute_cube(d, 130, h - 55, 44, (255, 200, 80))
    draw_cute_cube(d, w - 140, h - 55, 44, (130, 220, 140))

    # Stars
    star_poly(d, w // 2 - 180, 48, 16, (255, 210, 60, 255))
    star_poly(d, w // 2 + 180, 48, 16, (255, 210, 60, 255))
    star_poly(d, w // 2, 36, 12, (255, 230, 120, 255))

    font_big = load_cjk_font(72)
    font_sub = load_cjk_font(28)

    title = "彩色方塊逃脫"
    bbox = d.textbbox((0, 0), title, font=font_big)
    tw = bbox[2] - bbox[0]
    tx = (w - tw) // 2
    ty = 78
    # Soft multi-layer shadow for pop
    d.text((tx + 3, ty + 3), title, font=font_big, fill=(200, 100, 50, 100))
    d.text((tx + 1, ty + 1), title, font=font_big, fill=(255, 180, 120, 180))
    d.text((tx, ty), title, font=font_big, fill=(255, 105, 70, 255))

    sub = "Color Block Escape"
    bbox2 = d.textbbox((0, 0), sub, font=font_sub)
    sw = bbox2[2] - bbox2[0]
    d.text(((w - sw) // 2, ty + 78), sub, font=font_sub, fill=(130, 105, 95, 230))

    # Tiny sparkles near title
    for sx, sy in [(tx - 20, ty + 10), (tx + tw + 16, ty + 18), (tx + tw // 2, ty - 8)]:
        soft_circle(d, (sx, sy), 3, (255, 230, 120, 220))

    return im


def make_badge_chip(name: str, w: int = 200, h: int = 88) -> Image.Image:
    """Colorful rounded badge chip for HUD stats."""
    base = BADGE_COLORS.get(name, (200, 200, 210))
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im, "RGBA")
    # shadow
    round_rect(d, [4, 6, w - 2, h - 2], 22, (0, 0, 0, 35))
    # body
    round_rect(d, [2, 2, w - 4, h - 6], 22, (*base, 240), outline=(255, 255, 255, 220), width=4)
    # soft gloss (keep chip colorful, not half-white)
    d.rounded_rectangle([12, 8, w - 14, max(18, h // 3)], 10, fill=(255, 255, 255, 45))
    # accent dot
    soft_circle(d, (20, 18), 6, (255, 255, 255, 160))
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


def make_hud_bar(w: int = 720, h: int = 200) -> Image.Image:
    """Mostly transparent — soft fade so playroom bg shows through."""
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im, "RGBA")
    for y in range(h):
        a = int(40 * (1.0 - y / max(1, h - 1)))
        draw.line([(0, y), (w, y)], fill=(255, 255, 255, a))
    return im


def make_toolbar_bar(w: int = 720, h: int = 140) -> Image.Image:
    """Soft pill tray behind bottom buttons — not a full-width hard bar."""
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(im, "RGBA")
    pad_x = int(w * 0.04)
    round_rect(draw, [pad_x, 10, w - pad_x, h - 8], 36, (255, 250, 245, 175), outline=(255, 190, 130, 140), width=3)
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
    save(make_background(720, 1280), "bg_playroom_portrait.png")
    save(make_background(1280, 720), "bg_playroom.png")
    save(make_title_banner(960, 260), "title_banner.png")
    save(make_title_banner(720, 200), "title_banner_sm.png")
    for name in BTN_COLORS:
        save(make_button(name, 192, False), f"btn_{name}.png")
        save(make_button(name, 192, True), f"btn_{name}_pressed.png")
    for name in BADGE_COLORS:
        save(make_badge_chip(name, 220, 96), f"badge_{name}.png")
    save(make_star(True, 64), "star_on.png")
    save(make_star(False, 64), "star_off.png")
    save(make_panel_frame(320, 520), "panel_frame.png")
    save(make_hud_bar(720, 220), "hud_bar.png")
    save(make_toolbar_bar(720, 150), "toolbar_bar.png")
    for name, rgb in GATE_COLORS.items():
        save(make_gate_deco(rgb, 64), f"gate_{name}.png")
    print("Done.")


if __name__ == "__main__":
    main()
