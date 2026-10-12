#!/usr/bin/env python3
"""Extract full Raymond title logo from start_page.png for HUD use."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sp = Image.open(ROOT / "assets/ui/start_page.png").convert("RGBA")
# Full 「彩色方塊逃脫」 + stars (verified unclipped crop)
logo = sp.crop((0, 30, 780, 630))
out = ROOT / "assets/ui/logo.png"
logo.save(out)
print(f"wrote {out.relative_to(ROOT)} {logo.size}")
