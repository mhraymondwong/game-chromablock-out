#!/usr/bin/env python3
"""Generate 50 original Color Block Escape levels + fast Python BFS solver.

Matches BoardModel / LevelData. Mid-stop pruning: max-slide | gate-aligned | exit.
Writes scripts/levels.gd.
"""
from __future__ import annotations

import json
import sys
from collections import deque
from pathlib import Path

SIZE = 8
ROOT = Path(__file__).resolve().parents[1]
OUT_GD = ROOT / "scripts" / "levels.gd"

SHAPES: dict[str, list[tuple[int, int]]] = {
    "1x1": [(0, 0)],
    "1x2": [(0, 0), (1, 0)],
    "1x3": [(0, 0), (1, 0), (2, 0)],
    "2x1": [(0, 0), (0, 1)],
    "3x1": [(0, 0), (0, 1), (0, 2)],
    "2x2": [(0, 0), (1, 0), (0, 1), (1, 1)],
    "L_ne": [(0, 0), (0, 1), (1, 1)],
    "L_nw": [(1, 0), (0, 1), (1, 1)],
    "L_se": [(0, 0), (1, 0), (0, 1)],
    "L_sw": [(0, 0), (1, 0), (1, 1)],
    "stone_1": [(0, 0)],
    "stone_2h": [(0, 0), (1, 0)],
    "stone_2v": [(0, 0), (0, 1)],
}

DIRS = ((1, 0), (-1, 0), (0, 1), (0, -1))
SIDE = {(1, 0): "right", (-1, 0): "left", (0, 1): "bottom", (0, -1): "top"}


def shape_size(shape: str) -> tuple[int, int]:
    cells = SHAPES[shape]
    return max(c[0] for c in cells) + 1, max(c[1] for c in cells) + 1


def exit_span(shape: str, side: str) -> int:
    w, h = shape_size(shape)
    return h if side in ("left", "right") else w


def cells_of(shape: str, x: int, y: int) -> list[tuple[int, int]]:
    return [(x + cx, y + cy) for cx, cy in SHAPES[shape]]


def validate_level(level: dict) -> str:
    occ: dict[tuple[int, int], bool] = {}
    for b in level["blocks"]:
        for p in cells_of(b["shape"], b["x"], b["y"]):
            if not (0 <= p[0] < SIZE and 0 <= p[1] < SIZE):
                return f"oob {b['shape']} {p}"
            if p in occ:
                return f"overlap {p}"
            occ[p] = True
    for g in level["gates"]:
        if g["start"] < 0 or g["start"] + g["size"] > SIZE:
            return f"bad gate {g}"
    for b in level["blocks"]:
        if b["shape"].startswith("stone"):
            continue
        ok, need_min = False, 999
        for g in level["gates"]:
            if g["color"] != b["color"]:
                continue
            need = exit_span(b["shape"], g["side"])
            need_min = min(need_min, need)
            if g["size"] >= need:
                ok = True
                break
        if not ok:
            return f"no gate for {b['color']} {b['shape']} need>={need_min}"
    return ""


class Board:
    __slots__ = ("gates", "blocks", "exits_done")

    def __init__(self, data=None):
        if data is None:
            return
        self.gates = tuple(
            (g["side"], g["start"], g["size"], g["color"]) for g in data["gates"]
        )
        self.exits_done = 0
        self.blocks = []
        for i, b in enumerate(data["blocks"]):
            shape = b["shape"]
            ice = int(b.get("ice", 0))
            self.blocks.append([
                i, shape, b["color"], int(b["x"]), int(b["y"]),
                b.get("axis", ""), ice, ice > 0, shape.startswith("stone"),
            ])

    def copy(self):
        b = Board.__new__(Board)
        b.gates = self.gates
        b.exits_done = self.exits_done
        b.blocks = [bl[:] for bl in self.blocks]
        return b

    def key(self):
        parts = sorted((bl[0], bl[3], bl[4], int(bl[7])) for bl in self.blocks)
        return (self.exits_done, tuple(parts))

    def occ(self, ignore=-1):
        o = set()
        for bl in self.blocks:
            if bl[0] == ignore:
                continue
            for c in cells_of(bl[1], bl[3], bl[4]):
                o.add(c)
        return o

    def get(self, bid):
        for bl in self.blocks:
            if bl[0] == bid:
                return bl
        return None

    def can_place(self, bl, nx, ny):
        if bl[7]:
            return False
        axis = bl[5]
        if axis == "h" and ny != bl[4]:
            return False
        if axis == "v" and nx != bl[3]:
            return False
        o = self.occ(bl[0])
        for cx, cy in SHAPES[bl[1]]:
            p = (nx + cx, ny + cy)
            if p[0] < 0 or p[1] < 0 or p[0] >= SIZE or p[1] >= SIZE or p in o:
                return False
        return True

    def try_move_one(self, bid, dx, dy):
        bl = self.get(bid)
        if not bl or bl[8] or bl[7]:
            return False
        axis = bl[5]
        if axis == "h" and dy:
            return False
        if axis == "v" and dx:
            return False
        nx, ny = bl[3] + dx, bl[4] + dy
        if not self.can_place(bl, nx, ny):
            return False
        bl[3], bl[4] = nx, ny
        return True

    def aligned(self, bid):
        bl = self.get(bid)
        cells = cells_of(bl[1], bl[3], bl[4])
        xs = [c[0] for c in cells]
        ys = [c[1] for c in cells]
        min_x, max_x, min_y, max_y = min(xs), max(xs), min(ys), max(ys)
        for side, start, size, color in self.gates:
            if color != bl[2]:
                continue
            ge = start + size - 1
            if side in ("left", "right"):
                if max_y >= start and min_y <= ge:
                    return True
            else:
                if max_x >= start and min_x <= ge:
                    return True
        return False

    def can_exit(self, bid, d):
        bl = self.get(bid)
        if not bl or bl[8] or bl[7]:
            return False
        side = SIDE[d]
        cells = cells_of(bl[1], bl[3], bl[4])
        xs = [c[0] for c in cells]
        ys = [c[1] for c in cells]
        min_x, max_x, min_y, max_y = min(xs), max(xs), min(ys), max(ys)
        need = (max_y - min_y + 1) if side in ("left", "right") else (max_x - min_x + 1)
        gate = None
        for gside, start, size, color in self.gates:
            if gside == side and color == bl[2] and size >= need:
                gate = (gside, start, size, color)
                break
        if not gate:
            return False
        _, gs, gsz, _ = gate
        ge = gs + gsz - 1
        if side == "right":
            return max_x == SIZE - 1 and min_y >= gs and max_y <= ge
        if side == "left":
            return min_x == 0 and min_y >= gs and max_y <= ge
        if side == "bottom":
            return max_y == SIZE - 1 and min_x >= gs and max_x <= ge
        if side == "top":
            return min_y == 0 and min_x >= gs and max_x <= ge
        return False

    def try_exit(self, bid, d):
        if not self.can_exit(bid, d):
            return False
        self.blocks = [b for b in self.blocks if b[0] != bid]
        self.exits_done += 1
        for b in self.blocks:
            if b[6] > 0:
                b[7] = self.exits_done < b[6]
        return True

    def is_clear(self):
        return all(b[8] for b in self.blocks)


def bfs_solve(data, cap=200000):
    root = Board(data)
    if root.is_clear():
        return True, 0, 0
    q = deque()
    q.append((root, 0))
    seen = {root.key()}
    processed = 0
    while q and processed < cap:
        m, moves = q.popleft()
        processed += 1
        if m.is_clear():
            return True, processed, moves
        bids = [b[0] for b in m.blocks if not b[8] and not b[7]]
        for bid in bids:
            for d in DIRS:
                m2 = m.copy()
                if m2.try_exit(bid, d):
                    k = m2.key()
                    if k not in seen:
                        seen.add(k)
                        q.append((m2, moves + 1))
                cur = m.copy()
                steps = 0
                while steps < SIZE:
                    if not cur.try_move_one(bid, d[0], d[1]):
                        break
                    steps += 1
                    bl = cur.get(bid)
                    more = cur.can_place(bl, bl[3] + d[0], bl[4] + d[1])
                    align = cur.aligned(bid)
                    can_ex = cur.can_exit(bid, d)
                    if (not more) or align or can_ex:
                        k = cur.key()
                        if k not in seen:
                            seen.add(k)
                            q.append((cur.copy(), moves + 1))
                    if can_ex:
                        ex = cur.copy()
                        if ex.try_exit(bid, d):
                            k = ex.key()
                            if k not in seen:
                                seen.add(k)
                                q.append((ex, moves + 1))
    return False, processed, -1


def L(id_, title, par, gold, gates, blocks):
    return {"id": id_, "title": title, "par": par, "gold": gold, "gates": gates, "blocks": blocks}


def G(side, start, size, color):
    return {"side": side, "start": start, "size": size, "color": color}


def B(shape, color, x, y, axis="", ice=0):
    d = {"shape": shape, "color": color, "x": x, "y": y}
    if axis:
        d["axis"] = axis
    if ice:
        d["ice"] = ice
    return d


def build_levels():
    """50 original levels — progressive, harder than original 8, not Block Out copies."""
    lv = []

    # ——— 1–5 teach (harder than one-slide) ———
    lv.append(L(1, "第一次逃脫", 5, 45, [
        G("right", 3, 1, "red"),
    ], [
        B("1x1", "red", 2, 3),
        B("1x1", "red", 4, 5),  # must move to row 3 then out
    ]))

    lv.append(L(2, "長長的朋友", 7, 50, [
        G("right", 2, 1, "blue"),
    ], [
        B("1x2", "blue", 1, 2),
        B("1x1", "blue", 5, 4),
        B("1x1", "blue", 3, 6),
    ]))

    lv.append(L(3, "紅藍合作", 9, 55, [
        G("right", 1, 1, "red"),
        G("bottom", 4, 1, "blue"),
    ], [
        B("1x1", "red", 2, 1),
        B("1x1", "red", 5, 3),
        B("2x1", "blue", 4, 2),
    ]))

    lv.append(L(4, "轉角相遇", 10, 60, [
        G("top", 2, 1, "green"),
        G("right", 5, 1, "yellow"),
    ], [
        B("1x1", "green", 2, 4),
        B("1x1", "yellow", 1, 5),
        B("1x2", "yellow", 3, 5),
        B("1x1", "green", 5, 2),
    ]))

    lv.append(L(5, "大方塊出門", 10, 65, [
        G("bottom", 3, 2, "orange"),
        G("right", 0, 1, "purple"),
    ], [
        B("2x2", "orange", 3, 2),
        B("1x1", "purple", 1, 4),
        B("1x1", "purple", 6, 1),
    ]))

    # ——— 6–12 stones ———
    lv.append(L(6, "石頭擋路", 12, 65, [
        G("left", 3, 1, "green"),
        G("right", 5, 1, "yellow"),
    ], [
        B("stone_1", "stone", 3, 3),
        B("stone_1", "stone", 4, 5),
        B("1x2", "green", 1, 3),
        B("1x1", "yellow", 5, 1),
        B("1x1", "yellow", 6, 5),
    ]))

    lv.append(L(7, "石牆縫隙", 12, 70, [
        G("right", 1, 1, "red"),
        G("bottom", 5, 1, "blue"),
    ], [
        B("stone_2h", "stone", 3, 3),
        B("stone_1", "stone", 2, 5),
        B("1x1", "red", 1, 1),
        B("1x1", "red", 0, 4),
        B("3x1", "blue", 5, 2),
    ]))

    lv.append(L(8, "繞石而行", 14, 75, [
        G("top", 2, 2, "orange"),
        G("right", 6, 1, "purple"),
    ], [
        B("stone_1", "stone", 3, 2),
        B("stone_2h", "stone", 5, 4),
        B("2x2", "orange", 1, 4),
        B("1x1", "purple", 6, 6),
        B("1x1", "purple", 0, 1),
    ]))

    lv.append(L(9, "雙石夾道", 14, 75, [
        G("left", 2, 1, "blue"),
        G("right", 2, 1, "blue"),
        G("bottom", 4, 1, "green"),
    ], [
        B("stone_2v", "stone", 3, 1),
        B("stone_1", "stone", 4, 4),
        B("1x2", "blue", 1, 2),
        B("1x1", "blue", 5, 2),
        B("1x1", "green", 4, 6),
        B("1x1", "green", 6, 5),
    ]))

    lv.append(L(10, "石陣迷宮", 15, 80, [
        G("top", 3, 1, "red"),
        G("right", 6, 1, "yellow"),
        G("left", 0, 1, "yellow"),
    ], [
        B("stone_1", "stone", 2, 2),
        B("stone_1", "stone", 4, 3),
        B("stone_1", "stone", 3, 5),
        B("1x1", "red", 3, 6),
        B("1x1", "red", 6, 1),
        B("1x2", "yellow", 4, 0),
        B("1x1", "yellow", 1, 0),
    ]))

    lv.append(L(11, "窄門過石", 14, 80, [
        G("right", 3, 2, "orange"),
        G("top", 0, 1, "blue"),
    ], [
        B("stone_2v", "stone", 5, 0),
        B("stone_1", "stone", 2, 6),
        B("2x2", "orange", 1, 3),
        B("1x1", "blue", 0, 2),
        B("1x1", "blue", 3, 0),
        B("1x1", "orange", 6, 5),
    ]))

    lv.append(L(12, "石橋盡頭", 16, 85, [
        G("bottom", 2, 2, "green"),
        G("right", 0, 1, "purple"),
        G("left", 5, 1, "purple"),
    ], [
        B("stone_2h", "stone", 3, 3),
        B("stone_1", "stone", 1, 1),
        B("stone_1", "stone", 5, 5),
        B("L_se", "green", 2, 4),
        B("1x1", "purple", 0, 5),
        B("1x1", "purple", 7, 0),
    ]))

    # ——— 13–22 axis locks ———
    lv.append(L(13, "只能直走", 12, 70, [
        G("right", 2, 1, "red"),
        G("bottom", 5, 1, "blue"),
    ], [
        B("1x3", "red", 1, 2, axis="h"),
        B("3x1", "blue", 5, 3, axis="v"),
        B("stone_1", "stone", 3, 4),
        B("1x1", "red", 6, 0),
    ]))

    lv.append(L(14, "橫行天下", 12, 70, [
        G("left", 1, 1, "yellow"),
        G("right", 4, 1, "yellow"),
        G("bottom", 2, 1, "red"),
    ], [
        B("1x2", "yellow", 3, 1, axis="h"),
        B("1x1", "yellow", 5, 4, axis="h"),
        B("1x1", "red", 2, 3),
        B("stone_1", "stone", 4, 2),
    ]))

    lv.append(L(15, "豎井滑梯", 12, 75, [
        G("top", 3, 1, "blue"),
        G("bottom", 6, 1, "green"),
    ], [
        B("2x1", "blue", 3, 2, axis="v"),
        B("3x1", "green", 6, 1, axis="v"),
        B("1x1", "blue", 1, 0),
        B("stone_1", "stone", 0, 4),
    ]))

    lv.append(L(16, "十字路口", 14, 80, [
        G("right", 3, 1, "red"),
        G("bottom", 3, 1, "blue"),
        G("left", 6, 1, "green"),
    ], [
        B("1x2", "red", 1, 3, axis="h"),
        B("2x1", "blue", 3, 1, axis="v"),
        B("1x1", "green", 4, 6, axis="h"),
        B("stone_1", "stone", 5, 4),
        B("1x1", "red", 6, 1),
    ]))

    lv.append(L(17, "軌道封鎖", 14, 80, [
        G("right", 4, 1, "orange"),
        G("left", 4, 1, "orange"),
        G("right", 5, 1, "purple"),
        G("top", 2, 1, "purple"),
    ], [
        B("1x2", "orange", 1, 4, axis="h"),
        B("1x1", "purple", 5, 5, axis="h"),
        B("1x1", "orange", 4, 6),
        B("stone_1", "stone", 3, 2),
        B("1x1", "purple", 2, 0),
    ]))

    lv.append(L(18, "雙軌並行", 16, 85, [
        G("right", 1, 1, "red"),
        G("right", 5, 1, "blue"),
        G("top", 6, 1, "blue"),
    ], [
        B("1x3", "red", 0, 1, axis="h"),
        B("1x2", "blue", 2, 5, axis="h"),
        B("1x1", "blue", 6, 3, axis="v"),
        B("stone_1", "stone", 4, 3),
        B("1x1", "red", 5, 0),
    ]))

    lv.append(L(19, "強制轉彎", 16, 85, [
        G("left", 4, 2, "green"),
        G("bottom", 5, 1, "yellow"),
        G("top", 2, 1, "yellow"),
    ], [
        B("2x1", "green", 3, 4, axis="h"),
        B("1x1", "yellow", 5, 2, axis="v"),
        B("1x1", "yellow", 2, 6),
        B("stone_1", "stone", 1, 3),
        B("1x1", "green", 6, 0),
    ]))

    lv.append(L(20, "軸向迷宮", 18, 90, [
        G("right", 2, 1, "red"),
        G("left", 4, 2, "blue"),
        G("bottom", 3, 2, "orange"),
        G("top", 6, 1, "blue"),
    ], [
        B("1x2", "red", 2, 2, axis="h"),
        B("2x1", "blue", 0, 4, axis="v"),
        B("2x2", "orange", 3, 4),
        B("stone_1", "stone", 5, 3),
        B("1x1", "blue", 6, 0),
        B("1x1", "red", 7, 6),
    ]))

    lv.append(L(21, "單向巷弄", 18, 90, [
        G("top", 4, 1, "purple"),
        G("right", 0, 1, "green"),
        G("bottom", 1, 1, "purple"),
        G("left", 6, 1, "green"),
    ], [
        B("3x1", "purple", 4, 2, axis="v"),
        B("1x2", "green", 2, 0, axis="h"),
        B("1x1", "green", 0, 6),
        B("1x1", "purple", 1, 7),
        B("stone_1", "stone", 3, 3),
        B("stone_1", "stone", 6, 4),
    ]))

    lv.append(L(22, "軌道終點", 10, 95, [
        G("right", 3, 1, "red"),
        G("left", 2, 1, "blue"),
        G("top", 5, 1, "yellow"),
        G("bottom", 5, 1, "yellow"),
    ], [
        B("1x2", "red", 0, 3, axis="h"),
        B("1x1", "blue", 4, 2, axis="h"),
        B("1x1", "yellow", 5, 4, axis="v"),
        B("stone_1", "stone", 2, 5),
        B("stone_1", "stone", 6, 1),
    ]))

    # ——— 23–35 L-pieces / order ———
    lv.append(L(23, "彎彎的腳", 14, 80, [
        G("left", 2, 2, "green"),
        G("right", 4, 2, "yellow"),
        G("bottom", 1, 1, "purple"),
    ], [
        B("L_se", "green", 2, 2),
        B("1x2", "yellow", 4, 5),
        B("1x1", "purple", 1, 5),
        B("stone_2v", "stone", 6, 0),
        B("2x1", "yellow", 6, 4),
    ]))

    lv.append(L(24, "L 型起步", 14, 80, [
        G("right", 2, 2, "red"),
        G("top", 4, 2, "blue"),
    ], [
        B("L_ne", "red", 3, 2),
        B("L_sw", "blue", 4, 4),
        B("1x1", "red", 0, 6),
        B("stone_1", "stone", 1, 1),
        B("1x1", "blue", 1, 5),
    ]))

    lv.append(L(25, "先後次序", 16, 85, [
        G("left", 3, 2, "orange"),
        G("right", 5, 1, "purple"),
        G("top", 6, 1, "purple"),
    ], [
        B("L_nw", "orange", 2, 3),
        B("1x1", "purple", 5, 2),
        B("1x1", "purple", 6, 5),
        B("1x1", "orange", 4, 6),
        B("stone_1", "stone", 1, 1),
        B("stone_1", "stone", 7, 3),
    ]))

    lv.append(L(26, "雙 L 交錯", 16, 85, [
        G("bottom", 2, 2, "green"),
        G("top", 4, 2, "yellow"),
        G("right", 0, 1, "green"),
    ], [
        B("L_se", "green", 2, 3),
        B("L_nw", "yellow", 4, 1),
        B("1x1", "green", 6, 0),
        B("stone_1", "stone", 0, 5),
        B("1x1", "yellow", 1, 6),
    ]))

    lv.append(L(27, "堵住出口", 16, 90, [
        G("right", 3, 2, "blue"),
        G("left", 1, 2, "red"),
        G("bottom", 5, 1, "red"),
    ], [
        B("L_sw", "blue", 4, 3),
        B("L_ne", "red", 1, 1),
        B("1x1", "red", 5, 6),
        B("stone_1", "stone", 3, 5),
        B("1x1", "blue", 0, 6),
    ]))

    lv.append(L(28, "開鎖順序", 10, 90, [
        G("top", 2, 2, "orange"),
        G("right", 5, 1, "green"),
        G("bottom", 3, 1, "blue"),
    ], [
        B("L_se", "orange", 2, 1),
        B("1x1", "green", 3, 5),
        B("1x1", "blue", 3, 3),
        B("stone_1", "stone", 0, 4),
        B("stone_1", "stone", 6, 2),
    ]))

    lv.append(L(29, "三色 L 舞", 18, 95, [
        G("left", 1, 2, "red"),
        G("right", 5, 2, "blue"),
        G("bottom", 3, 2, "yellow"),
    ], [
        B("L_nw", "red", 2, 1),
        B("L_se", "blue", 4, 5),
        B("L_sw", "yellow", 3, 3),
        B("stone_1", "stone", 0, 4),
        B("stone_1", "stone", 6, 2),
    ]))

    lv.append(L(30, "讓路給 L", 10, 95, [
        G("top", 3, 2, "purple"),
        G("right", 2, 1, "green"),
        G("left", 6, 1, "green"),
    ], [
        B("L_ne", "purple", 3, 1),
        B("1x1", "green", 5, 2),
        B("1x1", "green", 2, 6),
        B("stone_1", "stone", 1, 3),
        B("1x1", "purple", 0, 5),
    ]))

    lv.append(L(31, "軸上的 L", 18, 95, [
        G("right", 2, 2, "orange"),
        G("bottom", 4, 2, "blue"),
    ], [
        B("L_sw", "orange", 2, 2, axis="h"),
        B("L_ne", "blue", 4, 4),
        B("1x1", "blue", 0, 6),
        B("stone_1", "stone", 1, 5),
        B("1x1", "orange", 6, 0),
    ]))

    lv.append(L(32, "夾心 L", 20, 100, [
        G("top", 1, 2, "red"),
        G("bottom", 5, 2, "yellow"),
        G("right", 3, 1, "red"),
    ], [
        B("L_se", "red", 1, 1),
        B("L_nw", "yellow", 5, 4),
        B("1x1", "red", 4, 3),
        B("1x1", "yellow", 2, 6),
        B("stone_1", "stone", 3, 2),
        B("stone_1", "stone", 6, 0),
    ]))

    lv.append(L(33, "旋轉空間", 20, 100, [
        G("left", 3, 2, "green"),
        G("right", 0, 2, "purple"),
        G("bottom", 2, 1, "purple"),
    ], [
        B("L_ne", "green", 2, 3),
        B("L_sw", "purple", 4, 0),
        B("1x1", "green", 5, 6),
        B("1x1", "purple", 1, 6),
        B("stone_1", "stone", 0, 1),
        B("stone_1", "stone", 7, 4),
    ]))

    lv.append(L(34, "次序鎖鏈", 20, 105, [
        G("bottom", 1, 2, "blue"),
        G("top", 4, 2, "orange"),
        G("right", 6, 1, "blue"),
    ], [
        B("L_se", "blue", 1, 3),
        B("L_nw", "orange", 4, 2),
        B("1x1", "blue", 5, 6),
        B("1x1", "orange", 0, 5),
        B("stone_1", "stone", 3, 0),
        B("stone_1", "stone", 7, 3),
    ]))

    lv.append(L(35, "L 型終章", 12, 110, [
        G("right", 2, 2, "red"),
        G("left", 5, 2, "yellow"),
        G("bottom", 3, 2, "green"),
    ], [
        B("L_ne", "red", 4, 2),
        B("L_sw", "yellow", 1, 5),
        B("L_se", "green", 3, 5),
        B("stone_1", "stone", 0, 1),
        B("stone_1", "stone", 6, 0),
    ]))

    # ——— 36–50 ice + multi ———
    lv.append(L(36, "冰封寶藏", 14, 95, [
        G("top", 3, 2, "blue"),
        G("right", 4, 2, "orange"),
        G("left", 5, 1, "red"),
    ], [
        B("1x2", "blue", 3, 1),
        B("1x1", "red", 1, 5),
        B("1x1", "blue", 5, 3),
        B("2x2", "orange", 3, 4, ice=2),
        B("stone_1", "stone", 0, 2),
        B("stone_1", "stone", 7, 1),
    ]))

    lv.append(L(37, "解凍第一步", 14, 95, [
        G("right", 2, 1, "red"),
        G("bottom", 5, 1, "green"),
        G("left", 5, 2, "blue"),
    ], [
        B("1x1", "red", 4, 2),
        B("1x1", "green", 5, 4),
        B("L_se", "blue", 1, 5, ice=2),
        B("stone_1", "stone", 2, 3),
        B("1x1", "red", 0, 0),
    ]))

    lv.append(L(38, "冰層雙重", 12, 100, [
        G("top", 1, 1, "yellow"),
        G("right", 3, 2, "purple"),
        G("bottom", 5, 1, "yellow"),
    ], [
        B("1x1", "yellow", 1, 2),
        B("1x1", "yellow", 5, 4),
        B("2x2", "purple", 3, 3, ice=1),
        B("1x1", "purple", 0, 6, ice=2),
        B("stone_1", "stone", 6, 1),
    ]))

    lv.append(L(39, "軸向解凍", 16, 100, [
        G("right", 1, 1, "red"),
        G("bottom", 5, 1, "blue"),
        G("left", 4, 2, "orange"),
    ], [
        B("1x2", "red", 2, 1, axis="h"),
        B("3x1", "blue", 5, 2, axis="v"),
        B("L_nw", "orange", 1, 4, ice=2),
        B("stone_1", "stone", 4, 3),
        B("1x1", "red", 6, 0),
    ]))

    lv.append(L(40, "冰石夾擊", 18, 105, [
        G("top", 2, 2, "green"),
        G("right", 5, 1, "yellow"),
        G("bottom", 0, 1, "yellow"),
    ], [
        B("1x2", "green", 2, 4),
        B("1x1", "yellow", 6, 5),
        B("2x2", "green", 3, 0, ice=1),
        B("1x1", "yellow", 0, 6),
        B("stone_1", "stone", 1, 2),
        B("stone_1", "stone", 5, 3),
    ]))

    lv.append(L(41, "三凍挑戰", 18, 110, [
        G("right", 0, 1, "red"),
        G("left", 2, 1, "blue"),
        G("bottom", 4, 2, "orange"),
    ], [
        B("1x1", "red", 5, 0),
        B("1x1", "blue", 2, 3),
        B("L_se", "orange", 4, 4, ice=2),
        B("1x1", "blue", 6, 1, ice=1),
        B("stone_1", "stone", 3, 1),
        B("1x1", "red", 0, 6),
    ]))

    lv.append(L(42, "冰封軌道", 12, 110, [
        G("right", 3, 1, "purple"),
        G("top", 1, 1, "green"),
        G("bottom", 5, 1, "purple"),
    ], [
        B("1x2", "purple", 1, 3, axis="h"),
        B("1x1", "green", 1, 2),
        B("1x1", "green", 4, 0, ice=1),
        B("1x1", "purple", 5, 6, ice=1),
        B("stone_1", "stone", 0, 5),
        B("stone_1", "stone", 6, 1),
    ]))

    lv.append(L(43, "解凍 L 舞", 20, 115, [
        G("left", 2, 2, "red"),
        G("right", 5, 2, "blue"),
        G("top", 4, 1, "yellow"),
    ], [
        B("1x1", "yellow", 4, 3),
        B("L_ne", "red", 2, 2, ice=1),
        B("L_sw", "blue", 4, 5, ice=1),
        B("stone_1", "stone", 6, 0),
        B("1x1", "yellow", 0, 6),
        B("1x1", "red", 7, 3),
    ]))

    lv.append(L(44, "層層解凍", 20, 120, [
        G("right", 1, 1, "orange"),
        G("left", 4, 1, "green"),
        G("bottom", 2, 2, "purple"),
    ], [
        B("1x1", "orange", 3, 1),
        B("1x1", "green", 4, 5),
        B("2x2", "purple", 2, 3, ice=2),
        B("1x1", "orange", 6, 0, ice=1),
        B("stone_1", "stone", 5, 2),
        B("1x1", "green", 0, 0),
    ]))

    lv.append(L(45, "冰石軸三重", 22, 120, [
        G("right", 2, 1, "red"),
        G("bottom", 5, 2, "blue"),
        G("left", 0, 2, "yellow"),
    ], [
        B("1x2", "red", 1, 2, axis="h"),
        B("L_se", "blue", 5, 4, ice=1),
        B("2x2", "yellow", 0, 4, ice=2),
        B("stone_1", "stone", 3, 0),
        B("stone_1", "stone", 4, 3),
        B("1x1", "red", 6, 0),
        B("1x1", "blue", 7, 1),
    ]))

    lv.append(L(46, "終盤暖身", 12, 125, [
        G("top", 2, 2, "green"),
        G("right", 4, 2, "orange"),
        G("left", 6, 1, "purple"),
    ], [
        B("1x1", "purple", 3, 6),
        B("L_nw", "green", 2, 1, ice=1),
        B("L_se", "orange", 4, 4, ice=1),
        B("stone_1", "stone", 0, 3),
        B("1x1", "purple", 6, 2),
    ]))

    lv.append(L(47, "深凍迷宮", 24, 130, [
        G("right", 0, 1, "red"),
        G("left", 3, 1, "blue"),
        G("bottom", 5, 2, "yellow"),
        G("top", 1, 2, "blue"),
    ], [
        B("1x1", "red", 4, 0),
        B("1x2", "blue", 1, 3),
        B("L_sw", "yellow", 5, 4, ice=2),
        B("1x1", "blue", 3, 5, ice=1),
        B("stone_1", "stone", 2, 1),
        B("stone_1", "stone", 6, 2),
        B("1x1", "red", 7, 6),
    ]))

    lv.append(L(48, "四色冰封", 14, 130, [
        G("right", 2, 1, "red"),
        G("left", 5, 1, "blue"),
        G("top", 3, 2, "green"),
        G("bottom", 0, 2, "yellow"),
    ], [
        B("1x1", "red", 4, 2),
        B("1x1", "blue", 3, 5),
        B("L_ne", "green", 3, 0, ice=1),
        B("L_sw", "yellow", 0, 5, ice=2),
        B("stone_1", "stone", 6, 3),
        B("stone_1", "stone", 2, 3),
    ]))

    lv.append(L(49, "終極解凍", 14, 140, [
        G("right", 1, 2, "orange"),
        G("left", 4, 2, "purple"),
        G("bottom", 3, 1, "red"),
        G("top", 6, 1, "red"),
    ], [
        B("1x1", "red", 3, 2),
        B("1x1", "red", 6, 4),
        B("L_se", "orange", 4, 1, ice=1),
        B("L_nw", "purple", 1, 4, ice=2),
        B("stone_1", "stone", 0, 0),
        B("stone_1", "stone", 5, 6),
    ]))

    lv.append(L(50, "逃脫終章", 16, 150, [
        G("right", 2, 2, "red"),
        G("left", 5, 2, "blue"),
        G("top", 0, 2, "green"),
        G("bottom", 3, 2, "yellow"),
    ], [
        B("1x1", "green", 1, 2),
        B("1x1", "yellow", 4, 5),
        B("L_ne", "red", 4, 2, ice=1),
        B("L_sw", "blue", 1, 5, ice=2),
        B("1x2", "green", 3, 0),
        B("stone_1", "stone", 6, 4),
        B("stone_1", "stone", 0, 3),
    ]))

    assert len(lv) == 50, len(lv)
    for i, x in enumerate(lv):
        x["id"] = i + 1
    return lv


LEVELS = None  # filled in main


def emit_gd(levels: list[dict]) -> str:
    lines = [
        "extends RefCounted",
        "class_name LevelData",
        "## Original Color Block Escape levels — not copied from any commercial title.",
        "## Board is 8×8 (BoardModel.SIZE). Generated by tools/gen_levels50.py",
        "",
        "const COLORS := {",
        '\t"red": Color(0.95, 0.35, 0.40),',
        '\t"blue": Color(0.35, 0.55, 0.95),',
        '\t"green": Color(0.35, 0.78, 0.45),',
        '\t"yellow": Color(0.98, 0.82, 0.28),',
        '\t"orange": Color(0.98, 0.58, 0.28),',
        '\t"purple": Color(0.72, 0.45, 0.90),',
        '\t"stone": Color(0.55, 0.58, 0.62),',
        "}",
        "",
        "static func shape_cells(shape: String) -> Array:",
        "\tmatch shape:",
        '\t\t"1x1":',
        "\t\t\treturn [Vector2i(0, 0)]",
        '\t\t"1x2":',
        "\t\t\treturn [Vector2i(0, 0), Vector2i(1, 0)]",
        '\t\t"1x3":',
        "\t\t\treturn [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]",
        '\t\t"2x1":',
        "\t\t\treturn [Vector2i(0, 0), Vector2i(0, 1)]",
        '\t\t"3x1":',
        "\t\t\treturn [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]",
        '\t\t"2x2":',
        "\t\t\treturn [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]",
        '\t\t"L_ne":',
        "\t\t\treturn [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]",
        '\t\t"L_nw":',
        "\t\t\treturn [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]",
        '\t\t"L_se":',
        "\t\t\treturn [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]",
        '\t\t"L_sw":',
        "\t\t\treturn [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]",
        '\t\t"stone_1":',
        "\t\t\treturn [Vector2i(0, 0)]",
        '\t\t"stone_2h":',
        "\t\t\treturn [Vector2i(0, 0), Vector2i(1, 0)]",
        '\t\t"stone_2v":',
        "\t\t\treturn [Vector2i(0, 0), Vector2i(0, 1)]",
        "\t\t_:",
        "\t\t\treturn [Vector2i(0, 0)]",
        "",
        "",
        "static func shape_size(shape: String) -> Vector2i:",
        "\tvar cells: Array = shape_cells(shape)",
        "\tvar mx := 0",
        "\tvar my := 0",
        "\tfor c in cells:",
        "\t\tmx = maxi(mx, c.x)",
        "\t\tmy = maxi(my, c.y)",
        "\treturn Vector2i(mx + 1, my + 1)",
        "",
        "",
        "static func is_stone(shape: String) -> bool:",
        '\treturn shape.begins_with("stone")',
        "",
        "",
        "static func all_levels() -> Array:",
        "\t## 50 original levels on an 8×8 board.",
        "\treturn [",
    ]
    for lv in levels:
        lines.append(f'\t\t# Level {lv["id"]} — {lv["title"]}')
        lines.append("\t\t{")
        lines.append(f'\t\t\t"id": {lv["id"]},')
        lines.append(f'\t\t\t"title": "{lv["title"]}",')
        lines.append(f'\t\t\t"par": {lv["par"]},')
        lines.append(f'\t\t\t"gold": {lv["gold"]},')
        lines.append('\t\t\t"gates": [')
        for gate in lv["gates"]:
            lines.append(
                f'\t\t\t\t{{"side": "{gate["side"]}", "start": {gate["start"]}, '
                f'"size": {gate["size"]}, "color": "{gate["color"]}"}},'
            )
        lines.append("\t\t\t],")
        lines.append('\t\t\t"blocks": [')
        for blk in lv["blocks"]:
            parts = [
                f'"shape": "{blk["shape"]}"',
                f'"color": "{blk["color"]}"',
                f'"x": {blk["x"]}',
                f'"y": {blk["y"]}',
            ]
            if blk.get("axis"):
                parts.append(f'"axis": "{blk["axis"]}"')
            if blk.get("ice"):
                parts.append(f'"ice": {blk["ice"]}')
            lines.append("\t\t\t\t{" + ", ".join(parts) + "},")
        lines.append("\t\t\t],")
        lines.append("\t\t},")
    lines += [
        "\t]",
        "",
        "",
        "static func get_level(index: int) -> Dictionary:",
        "\tvar levels: Array = all_levels()",
        "\tif index < 0 or index >= levels.size():",
        "\t\treturn {}",
        "\treturn levels[index].duplicate(true)",
        "",
        "",
        "static func level_count() -> int:",
        "\treturn all_levels().size()",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    global LEVELS
    levels = build_levels()
    LEVELS = levels
    print(f"Built {len(levels)} levels", flush=True)
    bad = 0
    for lv in levels:
        msg = validate_level(lv)
        if msg:
            print(f"VALIDATE FAIL L{lv['id']}: {msg}", flush=True)
            bad += 1
        else:
            print(f"OK validate L{lv['id']} — {lv['title']}", flush=True)
    if bad:
        return 1

    OUT_GD.write_text(emit_gd(levels), encoding="utf-8")
    print(f"Wrote {OUT_GD}", flush=True)

    if "--solve" in sys.argv:
        fails = []
        summary = []
        for lv in levels:
            ok, exp, moves = bfs_solve(lv, 400000)
            status = "OK" if ok else "FAIL"
            print(f"{status} solve L{lv['id']:02d} exp={exp} moves={moves} — {lv['title']}", flush=True)
            summary.append({"id": lv["id"], "ok": ok, "exp": exp, "moves": moves, "title": lv["title"]})
            if not ok:
                fails.append(lv["id"])
        (ROOT / "tools" / "solve_summary.json").write_text(
            json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        print(f"Solved {sum(1 for s in summary if s['ok'])}/50 fails={fails}", flush=True)
        return 2 if fails else 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
