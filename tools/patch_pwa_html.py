#!/usr/bin/env python3
"""Patch Godot Web export index.html for mobile Safari full-bleed viewport."""
from __future__ import annotations

import re
import sys
from pathlib import Path

DEFAULT = Path(__file__).resolve().parents[1] / "build" / "pwa" / "index.html"

VIEWPORT = (
    'width=device-width, initial-scale=1.0, maximum-scale=1.0, '
    'user-scalable=no, viewport-fit=cover'
)

MOBILE_CSS = """
html, body {
	width: 100%;
	height: 100%;
	height: 100dvh;
	margin: 0;
	padding: 0;
	border: 0;
	overflow: hidden;
	background: #000;
	background-color: #000;
	touch-action: none;
	overscroll-behavior: none;
	-webkit-text-size-adjust: 100%;
}

body {
	color: white;
	position: fixed;
	inset: 0;
}

#canvas {
	position: fixed;
	inset: 0;
	width: 100% !important;
	height: 100% !important;
	height: 100dvh !important;
	display: block;
	touch-action: none;
	border: 0;
	margin: 0;
	padding: 0;
}

#canvas:focus {
	outline: none;
}
""".strip()


def patch(html: str) -> str:
	# Viewport meta
	html = re.sub(
		r'<meta\s+name="viewport"\s+content="[^"]*"\s*/?>',
		f'<meta name="viewport" content="{VIEWPORT}">',
		html,
		count=1,
		flags=re.I,
	)
	if 'name="viewport"' not in html:
		html = html.replace(
			"<head>",
			f'<head>\n\t\t<meta name="viewport" content="{VIEWPORT}">',
			1,
		)

	# Replace the Godot-generated style block's html/body/#canvas rules with
	# full-bleed mobile rules, keeping status overlay styles intact.
	style_match = re.search(r"(<style>)(.*?)(</style>)", html, flags=re.S | re.I)
	if not style_match:
		raise RuntimeError("No <style> block found in index.html")

	old_style = style_match.group(2)
	# Drop default html/body/#canvas rules; keep #status* rules.
	kept = re.sub(
		r"html,\s*body,\s*#canvas\s*\{.*?\}",
		"",
		old_style,
		count=1,
		flags=re.S,
	)
	kept = re.sub(r"body\s*\{.*?\}", "", kept, count=1, flags=re.S)
	kept = re.sub(r"#canvas\s*\{.*?\}", "", kept, count=1, flags=re.S)
	# Keep #canvas:focus if present later; our MOBILE_CSS already has it.
	kept = re.sub(r"#canvas:focus\s*\{.*?\}", "", kept, count=1, flags=re.S)
	new_style = "\n" + MOBILE_CSS + "\n" + kept.strip() + "\n\t\t"
	html = html[: style_match.start(2)] + new_style + html[style_match.end(2) :]

	# Prefer Traditional Chinese for this title page
	html = re.sub(r'<html\s+lang="[^"]*">', '<html lang="zh-Hant">', html, count=1, flags=re.I)

	# Ensure canvasResizePolicy stays 2
	if '"canvasResizePolicy":2' not in html and "'canvasResizePolicy':2" not in html:
		html = re.sub(
			r'"canvasResizePolicy"\s*:\s*\d+',
			'"canvasResizePolicy":2',
			html,
			count=1,
		)
	return html


def main() -> int:
	path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT
	if not path.is_file():
		print(f"missing: {path}", file=sys.stderr)
		return 1
	original = path.read_text(encoding="utf-8")
	patched = patch(original)
	path.write_text(patched, encoding="utf-8")
	print(f"patched {path}")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
