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


# --- Mockup restyle: wood hanging badges, board frame, gate arrows, sky rainbow ---

WOOD = (196, 148, 96)
WOOD_DK = (150, 105, 62)
WOOD_LT = (230, 190, 140)
WOOD_EDGE = (120, 80, 45)
FLOWER_COLORS = {
    "level": (110, 170, 255),
    "time": (190, 130, 240),
    "moves": (255, 110, 130),
    "score": (255, 210, 70),
}


def wood_grain(d, box, seed=0):
    x0, y0, x1, y1 = box
    for i in range(8):
        y = y0 + 8 + i * ((y1 - y0 - 16) // 8)
        a = 18 + (i + seed) % 5 * 4
        d.line([(x0 + 10, y), (x1 - 10, y + (i % 3) - 1)], fill=(*WOOD_DK, a), width=1)


def make_wood_badge(name: str, w: int = 240, h: int = 120) -> Image.Image:
    """Wooden hanging sign with twine pins + corner flower (mockup style)."""
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im, "RGBA")
    # hanging pins + twine
    pin_y = 10
    for px in (int(w * 0.22), int(w * 0.78)):
        soft_circle(d, (px, pin_y), 5, (150, 155, 160, 255))
        soft_circle(d, (px - 1, pin_y - 1), 2, (230, 230, 235, 200))
        d.line([(px, pin_y + 4), (px, 22)], fill=(130, 130, 140, 200), width=2)
    # soft shadow
    round_rect(d, [8, 28, w - 4, h - 4], 18, (0, 0, 0, 40))
    # wood plate
    round_rect(d, [6, 22, w - 8, h - 8], 18, (*WOOD, 255), outline=(*WOOD_EDGE, 230), width=3)
    wood_grain(d, [10, 26, w - 12, h - 12], seed=hash(name) % 7)
    # top gloss
    d.rounded_rectangle([14, 28, w - 16, 42], 8, fill=(255, 255, 255, 55))
    # bottom-right flower accent
    fx, fy = w - 28, h - 26
    fcol = FLOWER_COLORS.get(name, (255, 160, 180))
    for ang in range(0, 360, 60):
        rad = math.radians(ang)
        soft_circle(d, (int(fx + math.cos(rad) * 7), int(fy + math.sin(rad) * 7)), 5, (*fcol, 230))
    soft_circle(d, (fx, fy), 4, (255, 230, 90, 255))
    return im


def make_board_wood_frame(size: int = 512, border: int = 48) -> Image.Image:
    """Thick polished wood frame with corner screws; center transparent for board cells."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im, "RGBA")
    # outer shadow
    round_rect(d, [4, 8, size - 2, size - 2], 28, (0, 0, 0, 45))
    # wood body
    round_rect(d, [2, 2, size - 6, size - 8], 26, (*WOOD, 255), outline=(*WOOD_EDGE, 255), width=4)
    wood_grain(d, [8, 8, size - 12, size - 14], seed=3)
    # inner bevel (lighter)
    inset = border
    round_rect(
        d,
        [inset - 4, inset - 4, size - inset - 2, size - inset - 6],
        14,
        (0, 0, 0, 0),
        outline=(*WOOD_LT, 200),
        width=3,
    )
    # punch transparent center (with soft beige cell plate behind cells drawn in-engine)
    clear = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cd = ImageDraw.Draw(clear, "RGBA")
    # Keep frame only: draw opaque then cut hole by compositing
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([inset, inset, size - inset - 4, size - inset - 6], 12, fill=255)
    # beige inner plate
    plate = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pd = ImageDraw.Draw(plate, "RGBA")
    round_rect(pd, [inset, inset, size - inset - 4, size - inset - 6], 12, (235, 220, 195, 255))
    # Apply: frame with hole + plate under hole
    frame_only = im.copy()
    # Clear center of frame
    datas = frame_only.getdata()
    mask_data = mask.getdata()
    new_data = []
    for i, px in enumerate(datas):
        if mask_data[i] > 200:
            new_data.append((0, 0, 0, 0))
        else:
            new_data.append(px)
    frame_only.putdata(new_data)
    out = Image.alpha_composite(plate, frame_only)
    # corner screws
    od = ImageDraw.Draw(out, "RGBA")
    screw_r = 9
    offs = border // 2 + 2
    for sx, sy in [(offs, offs), (size - offs - 8, offs), (offs, size - offs - 10), (size - offs - 8, size - offs - 10)]:
        soft_circle(od, (sx, sy), screw_r + 1, (90, 95, 100, 200))
        soft_circle(od, (sx, sy), screw_r, (200, 205, 210, 255))
        soft_circle(od, (sx - 2, sy - 2), 3, (255, 255, 255, 180))
        od.line([(sx - 5, sy), (sx + 5, sy)], fill=(120, 125, 130, 220), width=2)
        od.line([(sx, sy - 5), (sx, sy + 5)], fill=(120, 125, 130, 220), width=2)
    return out


def make_gate_arrow(color_rgb, side: str = "right", size: int = 128) -> Image.Image:
    """Glowing capsule exit bar + arrow indicator (mockup)."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im, "RGBA")
    cx = cy = size // 2
    # soft glow
    for i, a in enumerate([40, 70, 110]):
        r = 28 + (2 - i) * 10
        soft_circle(d, (cx, cy), r, (*color_rgb, a))
    # vertical capsule bar
    bar_w, bar_h = 28, 88
    if side in ("left", "right"):
        round_rect(d, [cx - bar_w // 2, cy - bar_h // 2, cx + bar_w // 2, cy + bar_h // 2], 14, (*color_rgb, 240), outline=(255, 255, 255, 200), width=3)
        # gloss
        round_rect(d, [cx - bar_w // 2 + 4, cy - bar_h // 2 + 8, cx - 2, cy + bar_h // 2 - 8], 8, (255, 255, 255, 90))
        # arrow
        if side == "right":
            # outward →
            tip = (cx + 48, cy)
            d.polygon([(tip[0], tip[1]), (cx + 22, cy - 16), (cx + 22, cy + 16)], fill=(*color_rgb, 255))
            d.polygon([(tip[0], tip[1]), (cx + 22, cy - 16), (cx + 22, cy + 16)], outline=(255, 255, 255, 220))
        else:
            # inward → toward board (pointing right into grid from left)
            tip = (cx + 42, cy)
            d.polygon([(tip[0], tip[1]), (cx + 16, cy - 16), (cx + 16, cy + 16)], fill=(*color_rgb, 255))
    else:
        # horizontal for top/bottom
        bar_w, bar_h = 88, 28
        round_rect(d, [cx - bar_w // 2, cy - bar_h // 2, cx + bar_w // 2, cy + bar_h // 2], 14, (*color_rgb, 240), outline=(255, 255, 255, 200), width=3)
        if side == "bottom":
            tip = (cx, cy + 48)
            d.polygon([(tip[0], tip[1]), (cx - 16, cy + 22), (cx + 16, cy + 22)], fill=(*color_rgb, 255))
        else:
            tip = (cx, cy + 42)
            d.polygon([(tip[0], tip[1]), (cx - 16, cy + 16), (cx + 16, cy + 16)], fill=(*color_rgb, 255))
    return im


def make_background_with_rainbow(w: int = 720, h: int = 1280) -> Image.Image:
    """Sky playroom + soft rainbow arc near header."""
    base = make_background(w, h)
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer, "RGBA")
    # pastel rainbow behind title area
    colors = [
        (255, 140, 160, 90),
        (255, 190, 120, 90),
        (255, 230, 120, 90),
        (140, 220, 150, 90),
        (130, 190, 255, 90),
        (190, 160, 240, 90),
    ]
    cx, cy = int(w * 0.5), int(h * 0.02)
    for i, col in enumerate(colors):
        r_out = int(w * 0.62) - i * 10
        r_in = r_out - 9
        # draw arc as thick ring segments
        bbox = [cx - r_out, cy - r_out // 3, cx + r_out, cy + r_out]
        d.arc(bbox, 200, 340, fill=col, width=9)
    return Image.alpha_composite(base, layer)


def gen_mockup_restyle() -> None:
    print("Generating mockup restyle assets →", OUT)
    save(make_background_with_rainbow(720, 1280), "bg_playroom_portrait.png")
    save(make_background_with_rainbow(1280, 720), "bg_playroom.png")
    for name in BADGE_COLORS:
        save(make_wood_badge(name, 240, 120), f"badge_{name}.png")
    save(make_board_wood_frame(512, 48), "board_wood_frame.png")
    for name, rgb in GATE_COLORS.items():
        save(make_gate_arrow(rgb, "right", 128), f"gate_{name}.png")
        save(make_gate_arrow(rgb, "left", 128), f"gate_arrow_left_{name}.png")
        save(make_gate_arrow(rgb, "right", 128), f"gate_arrow_right_{name}.png")
        save(make_gate_arrow(rgb, "bottom", 128), f"gate_arrow_bottom_{name}.png")
        save(make_gate_arrow(rgb, "top", 128), f"gate_arrow_top_{name}.png")
    # Regenerate glossy buttons with mockup-ish colors
    BTN_COLORS["undo"] = (100, 170, 245)
    BTN_COLORS["reset"] = (235, 90, 100)
    BTN_COLORS["hint"] = (255, 175, 55)
    BTN_COLORS["map"] = (90, 200, 120)
    BTN_COLORS["rules"] = (170, 130, 235)
    for name in BTN_COLORS:
        save(make_button(name, 192, False), f"btn_{name}.png")
        save(make_button(name, 192, True), f"btn_{name}_pressed.png")
    # Transparent toolbar (labels drawn in-engine)
    im = Image.new("RGBA", (720, 160), (0, 0, 0, 0))
    save(im, "toolbar_bar.png")
    print("Mockup restyle assets done.")


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "mockup":
        gen_mockup_restyle()
    else:
        main()
