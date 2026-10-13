#!/usr/bin/env python3
"""Generate 50 original Color Block Escape levels + Python BFS solver.

Matches BoardModel / LevelData rules (8×8, axis, ice, stones, gate spans).
Writes scripts/levels.gd. Prefer python proof over multi-hour Godot BFS.
"""
from __future__ import annotations

import json
import sys
from collections import deque
from copy import deepcopy
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

DIRS = [(1, 0), (-1, 0), (0, 1), (0, -1)]
SIDE_OF = {(1, 0): "right", (-1, 0): "left", (0, 1): "bottom", (0, -1): "top"}


def is_stone(shape: str) -> bool:
    return shape.startswith("stone")


def shape_cells(shape: str) -> list[tuple[int, int]]:
    return list(SHAPES.get(shape, [(0, 0)]))


def shape_size(shape: str) -> tuple[int, int]:
    cells = shape_cells(shape)
    return max(c[0] for c in cells) + 1, max(c[1] for c in cells) + 1


def exit_span_needed(shape: str, side: str) -> int:
    w, h = shape_size(shape)
    return h if side in ("left", "right") else w


def abs_cells(blk: dict) -> list[tuple[int, int]]:
    return [(blk["x"] + c[0], blk["y"] + c[1]) for c in shape_cells(blk["shape"])]


def validate_level(data: dict) -> str:
    occ: dict[tuple[int, int], bool] = {}
    for b in data.get("blocks", []):
        shape = str(b.get("shape", "1x1"))
        x, y = int(b.get("x", 0)), int(b.get("y", 0))
        for cx, cy in shape_cells(shape):
            p = (x + cx, y + cy)
            if not (0 <= p[0] < SIZE and 0 <= p[1] < SIZE):
                return f"out of bounds: {shape} at {p}"
            if p in occ:
                return f"overlap at {p}"
            occ[p] = True
    for g in data.get("gates", []):
        start, size = int(g.get("start", 0)), int(g.get("size", 1))
        if start < 0 or start + size > SIZE:
            return f"bad gate {g}"
    for b in data.get("blocks", []):
        shape = str(b.get("shape", "1x1"))
        if is_stone(shape):
            continue
        color = str(b.get("color", ""))
        ok = False
        need_min = 999
        for g in data.get("gates", []):
            if str(g.get("color", "")) != color:
                continue
            side = str(g.get("side", ""))
            need = exit_span_needed(shape, side)
            need_min = min(need_min, need)
            if int(g.get("size", 1)) >= need:
                ok = True
                break
        if not ok:
            return f"no gate large enough for {color} {shape} (need ≥{need_min if need_min < 999 else '?'})"
    return ""


class Board:
    def __init__(self, data: dict):
        self.gates = deepcopy(data.get("gates", []))
        self.blocks: list[dict] = []
        self.exits_done = 0
        for i, b in enumerate(data.get("blocks", [])):
            ice = int(b.get("ice", 0))
            blk = {
                "id": i,
                "shape": str(b.get("shape", "1x1")),
                "color": str(b.get("color", "red")),
                "x": int(b.get("x", 0)),
                "y": int(b.get("y", 0)),
                "axis": str(b.get("axis", "")),
                "ice": ice,
                "frozen": ice > 0,
                "stone": is_stone(str(b.get("shape", "1x1"))),
            }
            blk["cells"] = abs_cells(blk)
            self.blocks.append(blk)

    def snapshot(self) -> dict:
        return {
            "blocks": [
                {
                    "id": b["id"],
                    "shape": b["shape"],
                    "color": b["color"],
                    "x": b["x"],
                    "y": b["y"],
                    "axis": b["axis"],
                    "ice": b["ice"],
                    "frozen": b["frozen"],
                    "stone": b["stone"],
                }
                for b in self.blocks
            ],
            "exits_done": self.exits_done,
        }

    def restore(self, snap: dict) -> None:
        self.blocks = []
        for b in snap["blocks"]:
            blk = dict(b)
            blk["cells"] = abs_cells(blk)
            self.blocks.append(blk)
        self.exits_done = int(snap["exits_done"])

    def state_key(self) -> str:
        parts = []
        for b in sorted(self.blocks, key=lambda x: x["id"]):
            fr = 1 if b.get("frozen") else 0
            parts.append(f"{b['id']}:{b['x']}:{b['y']}:{fr}")
        return f"{self.exits_done}|{','.join(parts)}"

    def get_block(self, bid: int) -> dict | None:
        for b in self.blocks:
            if b["id"] == bid:
                return b
        return None

    def occupancy(self, ignore_id: int = -1) -> set[tuple[int, int]]:
        occ: set[tuple[int, int]] = set()
        for b in self.blocks:
            if b["id"] == ignore_id:
                continue
            for c in b["cells"]:
                occ.add(c)
        return occ

    def can_place(self, blk: dict, nx: int, ny: int) -> bool:
        if blk.get("frozen"):
            return False
        axis = blk.get("axis", "")
        if axis == "h" and ny != blk["y"]:
            return False
        if axis == "v" and nx != blk["x"]:
            return False
        cells = []
        for cx, cy in shape_cells(blk["shape"]):
            p = (nx + cx, ny + cy)
            if not (0 <= p[0] < SIZE and 0 <= p[1] < SIZE):
                return False
            cells.append(p)
        occ = self.occupancy(blk["id"])
        return all(p not in occ for p in cells)

    def try_move(self, bid: int, dx: int, dy: int) -> bool:
        blk = self.get_block(bid)
        if not blk or blk["stone"]:
            return False
        if dx == 0 and dy == 0:
            return False
        axis = blk.get("axis", "")
        if axis == "h":
            dy = 0
        elif axis == "v":
            dx = 0
        if dx == 0 and dy == 0:
            return False
        sx = 1 if dx > 0 else (-1 if dx < 0 else 0)
        sy = 1 if dy > 0 else (-1 if dy < 0 else 0)
        moved = False
        cx, cy = blk["x"], blk["y"]
        for _ in range(abs(dx)):
            if self.can_place(blk, cx + sx, cy):
                cx += sx
                moved = True
            else:
                break
        blk["x"], blk["y"] = cx, cy
        blk["cells"] = abs_cells(blk)
        for _ in range(abs(dy)):
            if self.can_place(blk, cx, cy + sy):
                cy += sy
                moved = True
            else:
                break
        if moved:
            blk["x"], blk["y"] = cx, cy
            blk["cells"] = abs_cells(blk)
        return moved

    def can_exit(self, bid: int, d: tuple[int, int]) -> dict | None:
        blk = self.get_block(bid)
        if not blk or blk["stone"] or blk.get("frozen"):
            return None
        side = SIDE_OF.get(d)
        if not side:
            return None
        cells = blk["cells"]
        min_x = min(c[0] for c in cells)
        max_x = max(c[0] for c in cells)
        min_y = min(c[1] for c in cells)
        max_y = max(c[1] for c in cells)
        need = (max_y - min_y + 1) if side in ("left", "right") else (max_x - min_x + 1)
        gate = None
        for g in self.gates:
            if g["side"] != side or g["color"] != blk["color"]:
                continue
            if int(g["size"]) < need:
                continue
            gate = g
            break
        if not gate:
            return None
        g_start = int(gate["start"])
        g_end = g_start + int(gate["size"]) - 1
        if side == "right":
            if max_x != SIZE - 1 or min_y < g_start or max_y > g_end:
                return None
        elif side == "left":
            if min_x != 0 or min_y < g_start or max_y > g_end:
                return None
        elif side == "bottom":
            if max_y != SIZE - 1 or min_x < g_start or max_x > g_end:
                return None
        elif side == "top":
            if min_y != 0 or min_x < g_start or max_x > g_end:
                return None
        return gate

    def try_exit(self, bid: int, d: tuple[int, int]) -> bool:
        if not self.can_exit(bid, d):
            return False
        self.blocks = [b for b in self.blocks if b["id"] != bid]
        self.exits_done += 1
        for b in self.blocks:
            if b.get("ice", 0) > 0:
                b["frozen"] = self.exits_done < b["ice"]
        return True

    def colored_remaining(self) -> int:
        return sum(1 for b in self.blocks if not b["stone"])

    def is_clear(self) -> bool:
        return self.colored_remaining() == 0


def bfs_solve(data: dict, max_states: int = 200_000) -> tuple[bool, int, int]:
    """Return (ok, expansions, min_moves)."""
    board = Board(data)
    if board.is_clear():
        return True, 0, 0
    q: deque[tuple[dict, int]] = deque()
    visited: set[str] = set()
    start = board.snapshot()
    q.append((start, 0))
    visited.add(board.state_key())
    processed = 0
    while q and processed < max_states:
        snap, moves = q.popleft()
        processed += 1
        board.restore(snap)
        if board.is_clear():
            return True, processed, moves
        bids = [b["id"] for b in board.blocks if not b["stone"] and not b.get("frozen")]
        for bid in bids:
            for d in DIRS:
                board.restore(snap)
                if board.can_exit(bid, d):
                    if board.try_exit(bid, d):
                        k = board.state_key()
                        if k not in visited:
                            visited.add(k)
                            q.append((board.snapshot(), moves + 1))
                board.restore(snap)
                steps = 0
                while steps < SIZE:
                    if not board.try_move(bid, d[0], d[1]):
                        break
                    steps += 1
                    k2 = board.state_key()
                    if k2 not in visited:
                        visited.add(k2)
                        q.append((board.snapshot(), moves + 1))
                    if board.can_exit(bid, d):
                        # exit from this stop without mutating the slide path state in queue
                        snap2 = board.snapshot()
                        board2 = Board({"gates": data["gates"], "blocks": []})
                        board2.gates = deepcopy(data["gates"])
                        board2.restore(snap2)
                        if board2.try_exit(bid, d):
                            k3 = board2.state_key()
                            if k3 not in visited:
                                visited.add(k3)
                                q.append((board2.snapshot(), moves + 1))
    return False, processed, -1


def L(id_: int, title: str, par: int, gold: int, gates: list, blocks: list) -> dict:
    return {"id": id_, "title": title, "par": par, "gold": gold, "gates": gates, "blocks": blocks}


def g(side: str, start: int, size: int, color: str) -> dict:
    return {"side": side, "start": start, "size": size, "color": color}


def b(shape: str, color: str, x: int, y: int, axis: str = "", ice: int = 0) -> dict:
    d: dict = {"shape": shape, "color": color, "x": x, "y": y}
    if axis:
        d["axis"] = axis
    if ice:
        d["ice"] = ice
    return d


def build_levels() -> list[dict]:
    """50 original levels — progressive difficulty, not copied from Block Out."""
    levels: list[dict] = []

    # ——— 1–5 teach (harder than one-slide) ———
    levels.append(L(1, "第一次逃脫", 6, 45, [
        g("right", 3, 1, "red"),
    ], [
        b("1x1", "red", 1, 5),
        b("1x1", "red", 3, 1),  # decoy path: need to align to row 3
    ]))
    # Fix L1: two reds both need same gate — both can exit. Make second block path.
    # Actually both reds exit same gate - fine. Make them block each other.
    levels[-1] = L(1, "第一次逃脫", 5, 45, [
        g("right", 3, 1, "red"),
    ], [
        b("1x1", "red", 2, 3),
        b("1x1", "red", 5, 3),  # front one exits first, then back
    ])

    levels.append(L(2, "長長的朋友", 8, 50, [
        g("right", 2, 1, "blue"),
        g("bottom", 4, 1, "blue"),
    ], [
        b("1x2", "blue", 1, 2),
        b("1x1", "blue", 4, 4),
        b("2x1", "blue", 6, 1),  # blocks right path for 1x2 until moved
    ]))

    levels.append(L(3, "紅藍合作", 10, 55, [
        g("right", 1, 1, "red"),
        g("left", 4, 2, "blue"),
        g("bottom", 3, 1, "red"),
    ], [
        b("1x1", "red", 2, 4),
        b("1x1", "blue", 4, 5),
        b("1x2", "red", 3, 1),
        b("2x1", "blue", 1, 2),
    ]))

    levels.append(L(4, "轉角相遇", 12, 60, [
        g("top", 2, 1, "green"),
        g("right", 5, 1, "yellow"),
        g("left", 3, 1, "green"),
    ], [
        b("1x1", "green", 5, 5),
        b("1x1", "yellow", 1, 5),
        b("1x2", "yellow", 3, 3),
        b("2x1", "green", 2, 1),
        b("1x1", "green", 6, 2),
    ]))

    levels.append(L(5, "大方塊出門", 12, 65, [
        g("bottom", 2, 2, "orange"),
        g("right", 0, 1, "purple"),
        g("top", 5, 1, "purple"),
    ], [
        b("2x2", "orange", 3, 2),
        b("1x1", "purple", 2, 5),
        b("1x1", "purple", 5, 4),
        b("1x2", "orange", 0, 6),  # same color, uses bottom gate (size 2 covers 1x2 height 1)
    ]))

    # ——— 6–12 stones ———
    levels.append(L(6, "石頭擋路", 12, 60, [
        g("left", 3, 1, "green"),
        g("right", 4, 2, "yellow"),
        g("top", 6, 1, "green"),
    ], [
        b("stone_1", "stone", 3, 3),
        b("stone_1", "stone", 4, 2),
        b("stone_1", "stone", 2, 5),
        b("1x2", "green", 0, 3),
        b("1x1", "yellow", 5, 1),
        b("2x1", "yellow", 6, 4),
        b("1x1", "green", 6, 6),
    ]))

    levels.append(L(7, "石牆縫隙", 14, 70, [
        g("right", 1, 1, "red"),
        g("bottom", 5, 1, "blue"),
        g("left", 6, 1, "red"),
    ], [
        b("stone_2h", "stone", 3, 3),
        b("stone_2v", "stone", 2, 4),
        b("stone_1", "stone", 5, 1),
        b("1x1", "red", 1, 1),
        b("1x3", "red", 0, 6),
        b("3x1", "blue", 5, 3),
        b("1x1", "blue", 7, 0),
    ]))

    levels.append(L(8, "繞石而行", 14, 70, [
        g("top", 1, 2, "orange"),
        g("right", 5, 1, "purple"),
        g("bottom", 3, 1, "purple"),
    ], [
        b("stone_1", "stone", 2, 2),
        b("stone_1", "stone", 4, 4),
        b("stone_2h", "stone", 5, 2),
        b("2x2", "orange", 1, 4),
        b("1x1", "purple", 6, 5),
        b("1x1", "purple", 0, 1),
        b("2x1", "purple", 7, 6),
    ]))

    levels.append(L(9, "雙石夾道", 15, 75, [
        g("left", 2, 1, "blue"),
        g("right", 2, 1, "blue"),
        g("bottom", 0, 2, "green"),
    ], [
        b("stone_2v", "stone", 3, 1),
        b("stone_2v", "stone", 4, 4),
        b("stone_1", "stone", 1, 5),
        b("1x2", "blue", 1, 2),
        b("1x1", "blue", 5, 2),
        b("2x2", "green", 0, 3),
        b("1x1", "green", 6, 6),
    ]))

    levels.append(L(10, "石陣迷宮", 16, 80, [
        g("top", 3, 1, "red"),
        g("right", 5, 2, "yellow"),
        g("left", 0, 1, "yellow"),
        g("bottom", 5, 1, "red"),
    ], [
        b("stone_1", "stone", 2, 2),
        b("stone_1", "stone", 3, 4),
        b("stone_1", "stone", 5, 3),
        b("stone_2h", "stone", 0, 6),
        b("1x1", "red", 3, 6),
        b("1x1", "red", 6, 1),
        b("1x2", "yellow", 4, 0),
        b("2x1", "yellow", 1, 0),
    ]))

    levels.append(L(11, "窄門過石", 16, 80, [
        g("right", 3, 2, "orange"),
        g("top", 0, 1, "blue"),
        g("left", 7, 1, "blue"),
    ], [
        b("stone_2v", "stone", 4, 2),
        b("stone_1", "stone", 2, 4),
        b("stone_1", "stone", 6, 5),
        b("2x2", "orange", 1, 1),
        b("1x1", "blue", 0, 5),
        b("1x3", "blue", 5, 7),
        b("1x1", "orange", 7, 0),
    ]))

    levels.append(L(12, "石橋盡頭", 18, 85, [
        g("bottom", 2, 2, "green"),
        g("right", 0, 1, "purple"),
        g("left", 4, 1, "purple"),
        g("top", 6, 1, "green"),
    ], [
        b("stone_2h", "stone", 3, 3),
        b("stone_1", "stone", 1, 1),
        b("stone_1", "stone", 5, 5),
        b("stone_2v", "stone", 6, 1),
        b("L_se", "green", 2, 4),
        b("1x1", "purple", 0, 3),
        b("1x1", "purple", 7, 4),
        b("1x1", "green", 6, 6),
    ]))

    # ——— 13–22 axis locks ———
    levels.append(L(13, "只能直走", 12, 65, [
        g("right", 2, 1, "red"),
        g("bottom", 5, 1, "blue"),
    ], [
        b("1x3", "red", 1, 2, axis="h"),
        b("3x1", "blue", 5, 3, axis="v"),
        b("stone_1", "stone", 3, 4),
        b("1x1", "red", 6, 1),
    ]))

    levels.append(L(14, "橫行天下", 14, 70, [
        g("left", 1, 1, "yellow"),
        g("right", 4, 1, "yellow"),
        g("bottom", 2, 1, "red"),
    ], [
        b("1x2", "yellow", 3, 1, axis="h"),
        b("1x1", "yellow", 5, 4, axis="h"),
        b("1x1", "red", 2, 2),
        b("stone_1", "stone", 4, 2),
        b("2x1", "red", 2, 5),
    ]))

    levels.append(L(15, "豎井滑梯", 14, 70, [
        g("top", 3, 1, "blue"),
        g("bottom", 6, 1, "green"),
        g("right", 3, 1, "blue"),
    ], [
        b("2x1", "blue", 3, 2, axis="v"),
        b("3x1", "green", 6, 1, axis="v"),
        b("1x1", "blue", 1, 3),
        b("stone_2h", "stone", 0, 5),
        b("1x1", "green", 5, 6),
    ]))

    levels.append(L(16, "十字路口", 16, 75, [
        g("right", 3, 1, "red"),
        g("bottom", 3, 1, "blue"),
        g("left", 6, 1, "green"),
    ], [
        b("1x2", "red", 1, 3, axis="h"),
        b("2x1", "blue", 3, 1, axis="v"),
        b("1x1", "green", 5, 6, axis="h"),
        b("stone_1", "stone", 3, 5),
        b("1x1", "red", 6, 0),
        b("1x1", "blue", 0, 7),
    ]))

    levels.append(L(17, "軌道封鎖", 16, 80, [
        g("top", 1, 2, "orange"),
        g("right", 5, 1, "purple"),
        g("left", 2, 1, "purple"),
        g("bottom", 4, 1, "orange"),
    ], [
        b("1x2", "orange", 1, 4, axis="h"),
        b("1x1", "purple", 6, 5, axis="h"),
        b("1x1", "purple", 2, 2, axis="v"),
        b("stone_1", "stone", 4, 3),
        b("1x1", "orange", 4, 6),
        b("2x1", "orange", 7, 0),
    ]))

    levels.append(L(18, "雙軌並行", 18, 85, [
        g("right", 1, 1, "red"),
        g("right", 5, 1, "blue"),
        g("bottom", 0, 1, "red"),
        g("top", 6, 1, "blue"),
    ], [
        b("1x3", "red", 0, 1, axis="h"),
        b("1x2", "blue", 2, 5, axis="h"),
        b("1x1", "red", 5, 3, axis="v"),
        b("1x1", "blue", 6, 2, axis="v"),
        b("stone_2v", "stone", 4, 0),
        b("stone_1", "stone", 3, 4),
    ]))

    levels.append(L(19, "強制轉彎", 18, 85, [
        g("left", 4, 2, "green"),
        g("bottom", 5, 1, "yellow"),
        g("top", 2, 1, "yellow"),
        g("right", 6, 1, "yellow"),
    ], [
        b("2x1", "green", 3, 4, axis="h"),
        b("1x1", "yellow", 5, 1, axis="v"),
        b("1x2", "yellow", 1, 6),
        b("stone_1", "stone", 2, 3),
        b("stone_1", "stone", 6, 5),
        b("1x1", "green", 0, 1),
    ]))

    levels.append(L(20, "軸向迷宮", 20, 90, [
        g("right", 2, 1, "red"),
        g("left", 5, 1, "blue"),
        g("bottom", 3, 2, "orange"),
        g("top", 0, 1, "blue"),
    ], [
        b("1x2", "red", 2, 2, axis="h"),
        b("2x1", "blue", 0, 4, axis="v"),
        b("2x2", "orange", 3, 4),
        b("1x1", "blue", 6, 0),
        b("stone_1", "stone", 5, 3),
        b("stone_2h", "stone", 1, 6),
        b("1x1", "red", 7, 6),
    ]))

    levels.append(L(21, "單向巷弄", 20, 90, [
        g("top", 4, 1, "purple"),
        g("right", 0, 2, "green"),
        g("bottom", 1, 1, "purple"),
        g("left", 7, 1, "green"),
    ], [
        b("3x1", "purple", 4, 2, axis="v"),
        b("1x2", "green", 2, 0, axis="h"),
        b("1x1", "green", 5, 5),
        b("1x1", "purple", 1, 7),
        b("stone_1", "stone", 3, 3),
        b("stone_1", "stone", 6, 4),
        b("2x1", "green", 0, 4),
    ]))

    levels.append(L(22, "軌道終點", 22, 95, [
        g("right", 3, 1, "red"),
        g("left", 1, 1, "blue"),
        g("bottom", 6, 1, "yellow"),
        g("top", 3, 2, "yellow"),
    ], [
        b("1x3", "red", 0, 3, axis="h"),
        b("1x2", "blue", 4, 1, axis="h"),
        b("2x1", "yellow", 6, 4, axis="v"),
        b("1x1", "yellow", 3, 5),
        b("1x1", "blue", 1, 6),
        b("stone_2v", "stone", 2, 0),
        b("stone_1", "stone", 5, 5),
        b("1x1", "red", 7, 0),
    ]))

    # ——— 23–35 L-pieces / order puzzles ———
    levels.append(L(23, "彎彎的腳", 14, 75, [
        g("left", 2, 2, "green"),
        g("right", 4, 2, "yellow"),
        g("bottom", 1, 1, "purple"),
    ], [
        b("L_se", "green", 2, 2),
        b("1x2", "yellow", 4, 5),
        b("1x1", "purple", 1, 5),
        b("stone_2v", "stone", 6, 0),
        b("2x1", "yellow", 6, 4),
    ]))

    levels.append(L(24, "L 型起步", 16, 80, [
        g("right", 1, 2, "red"),
        g("top", 4, 2, "blue"),
        g("bottom", 0, 1, "red"),
    ], [
        b("L_ne", "red", 3, 3),
        b("L_sw", "blue", 5, 5),
        b("1x1", "red", 0, 6),
        b("stone_1", "stone", 2, 1),
        b("1x1", "blue", 1, 4),
    ]))

    levels.append(L(25, "先後次序", 16, 80, [
        g("left", 3, 2, "orange"),
        g("right", 5, 1, "purple"),
        g("top", 6, 1, "purple"),
    ], [
        b("L_nw", "orange", 2, 3),
        b("1x1", "purple", 5, 2),
        b("1x1", "purple", 6, 5),
        b("1x2", "orange", 4, 6),  # blocks L path; must exit purple first or move
        b("stone_1", "stone", 1, 1),
        b("stone_1", "stone", 7, 3),
    ]))

    levels.append(L(26, "雙 L 交錯", 18, 85, [
        g("bottom", 2, 2, "green"),
        g("top", 4, 2, "yellow"),
        g("right", 0, 1, "green"),
    ], [
        b("L_se", "green", 2, 2),
        b("L_nw", "yellow", 4, 4),
        b("1x1", "green", 6, 0),
        b("stone_2h", "stone", 0, 5),
        b("1x1", "yellow", 1, 0),
        b("2x1", "yellow", 7, 2),
    ]))

    levels.append(L(27, "堵住出口", 18, 85, [
        g("right", 3, 2, "blue"),
        g("left", 0, 2, "red"),
        g("bottom", 5, 1, "red"),
    ], [
        b("L_sw", "blue", 4, 3),
        b("L_ne", "red", 1, 1),
        b("1x1", "red", 5, 6),
        b("1x1", "blue", 0, 5),
        b("stone_1", "stone", 3, 5),
        b("stone_1", "stone", 6, 1),
    ]))

    levels.append(L(28, "開鎖順序", 20, 90, [
        g("top", 1, 2, "orange"),
        g("right", 4, 2, "green"),
        g("bottom", 3, 1, "blue"),
        g("left", 6, 1, "blue"),
    ], [
        b("L_se", "orange", 1, 2),
        b("L_ne", "green", 4, 4),
        b("1x1", "blue", 3, 6),
        b("1x1", "blue", 6, 1),
        b("stone_2v", "stone", 3, 0),
        b("1x2", "orange", 5, 0),
    ]))

    levels.append(L(29, "三色 L 舞", 20, 90, [
        g("left", 1, 2, "red"),
        g("right", 5, 2, "blue"),
        g("bottom", 3, 2, "yellow"),
    ], [
        b("L_nw", "red", 2, 1),
        b("L_se", "blue", 4, 5),
        b("L_sw", "yellow", 3, 3),
        b("stone_1", "stone", 0, 4),
        b("stone_1", "stone", 6, 2),
        b("1x1", "red", 7, 7),
    ]))

    levels.append(L(30, "讓路給 L", 20, 95, [
        g("top", 3, 2, "purple"),
        g("right", 1, 1, "green"),
        g("left", 5, 2, "green"),
        g("bottom", 0, 1, "purple"),
    ], [
        b("L_ne", "purple", 3, 3),
        b("1x2", "green", 1, 1),
        b("2x1", "green", 5, 5),
        b("1x1", "purple", 0, 6),
        b("stone_1", "stone", 2, 5),
        b("stone_2h", "stone", 6, 0),
    ]))

    levels.append(L(31, "軸上的 L", 22, 95, [
        g("right", 2, 2, "orange"),
        g("bottom", 4, 2, "blue"),
        g("left", 0, 1, "blue"),
    ], [
        b("L_sw", "orange", 3, 2, axis="h"),
        b("L_ne", "blue", 4, 4),
        b("1x1", "blue", 0, 3),
        b("stone_1", "stone", 1, 5),
        b("stone_1", "stone", 6, 1),
        b("1x1", "orange", 7, 6),
    ]))

    levels.append(L(32, "夾心 L", 22, 100, [
        g("top", 0, 2, "red"),
        g("bottom", 5, 2, "yellow"),
        g("right", 3, 1, "red"),
        g("left", 7, 1, "yellow"),
    ], [
        b("L_se", "red", 1, 1),
        b("L_nw", "yellow", 5, 4),
        b("1x1", "red", 4, 3),
        b("1x1", "yellow", 2, 6),
        b("stone_2v", "stone", 3, 2),
        b("stone_1", "stone", 6, 0),
        b("1x2", "red", 0, 5),
    ]))

    levels.append(L(33, "旋轉空間", 24, 100, [
        g("left", 3, 2, "green"),
        g("right", 0, 2, "purple"),
        g("top", 5, 2, "green"),
        g("bottom", 2, 1, "purple"),
    ], [
        b("L_ne", "green", 2, 3),
        b("L_sw", "purple", 4, 1),
        b("1x1", "green", 5, 6),
        b("1x1", "purple", 1, 6),
        b("stone_1", "stone", 0, 1),
        b("stone_1", "stone", 7, 4),
        b("2x1", "purple", 6, 6),
    ]))

    levels.append(L(34, "次序鎖鏈", 24, 105, [
        g("bottom", 1, 2, "blue"),
        g("top", 4, 2, "orange"),
        g("right", 6, 1, "blue"),
        g("left", 0, 1, "orange"),
    ], [
        b("L_se", "blue", 1, 3),
        b("L_nw", "orange", 4, 2),
        b("1x2", "blue", 5, 6),
        b("1x1", "orange", 0, 5),
        b("stone_2h", "stone", 2, 0),
        b("stone_1", "stone", 7, 3),
        b("1x1", "blue", 3, 7),
    ]))

    levels.append(L(35, "L 型終章", 26, 110, [
        g("right", 2, 2, "red"),
        g("left", 5, 2, "yellow"),
        g("bottom", 3, 2, "green"),
        g("top", 0, 1, "green"),
    ], [
        b("L_ne", "red", 3, 2),
        b("L_sw", "yellow", 1, 5),
        b("L_se", "green", 4, 4),
        b("1x1", "green", 0, 3),
        b("stone_1", "stone", 2, 0),
        b("stone_1", "stone", 6, 6),
        b("1x1", "red", 7, 0),
        b("1x1", "yellow", 6, 1),
    ]))

    # ——— 36–50 ice + multi-mechanic ———
    levels.append(L(36, "冰封寶藏", 14, 90, [
        g("top", 3, 2, "blue"),
        g("right", 4, 2, "orange"),
        g("left", 5, 1, "red"),
    ], [
        b("1x2", "blue", 3, 1),
        b("1x1", "red", 1, 5),
        b("1x1", "blue", 5, 3),
        b("2x2", "orange", 3, 4, ice=2),
        b("stone_1", "stone", 0, 2),
        b("stone_1", "stone", 7, 1),
    ]))

    levels.append(L(37, "解凍第一步", 16, 95, [
        g("right", 2, 1, "red"),
        g("bottom", 4, 1, "green"),
        g("left", 6, 2, "blue"),
    ], [
        b("1x1", "red", 4, 2),
        b("1x1", "green", 4, 5),
        b("L_se", "blue", 1, 5, ice=2),
        b("stone_1", "stone", 2, 3),
        b("1x2", "red", 0, 0),
        b("1x1", "green", 6, 1),
    ]))

    levels.append(L(38, "冰層雙重", 18, 100, [
        g("top", 1, 1, "yellow"),
        g("right", 3, 2, "purple"),
        g("bottom", 5, 1, "yellow"),
        g("left", 0, 1, "purple"),
    ], [
        b("1x1", "yellow", 1, 3),
        b("1x1", "yellow", 5, 4),
        b("2x2", "purple", 3, 2, ice=1),
        b("1x1", "purple", 0, 6, ice=2),
        b("stone_2h", "stone", 6, 6),
        b("stone_1", "stone", 2, 5),
    ]))

    levels.append(L(39, "軸向解凍", 20, 100, [
        g("right", 1, 1, "red"),
        g("bottom", 5, 1, "blue"),
        g("left", 4, 2, "orange"),
    ], [
        b("1x2", "red", 2, 1, axis="h"),
        b("3x1", "blue", 5, 2, axis="v"),
        b("L_nw", "orange", 1, 4, ice=2),
        b("stone_1", "stone", 4, 3),
        b("1x1", "red", 6, 0),
        b("1x1", "blue", 0, 7),
    ]))

    levels.append(L(40, "冰石夾擊", 20, 105, [
        g("top", 2, 2, "green"),
        g("right", 5, 1, "yellow"),
        g("bottom", 0, 1, "yellow"),
        g("left", 3, 1, "green"),
    ], [
        b("1x2", "green", 2, 4),
        b("1x1", "yellow", 6, 5),
        b("2x2", "green", 3, 0, ice=2),
        b("1x1", "yellow", 0, 6),
        b("stone_2v", "stone", 1, 1),
        b("stone_1", "stone", 5, 3),
        b("stone_1", "stone", 4, 6),
    ]))

    levels.append(L(41, "三凍挑戰", 22, 110, [
        g("right", 0, 1, "red"),
        g("left", 2, 1, "blue"),
        g("bottom", 4, 2, "orange"),
        g("top", 6, 1, "blue"),
    ], [
        b("1x1", "red", 5, 0),
        b("1x1", "blue", 2, 3),
        b("L_se", "orange", 4, 4, ice=2),
        b("1x1", "blue", 6, 5, ice=1),
        b("1x1", "red", 0, 6, ice=3),
        b("stone_1", "stone", 3, 1),
        b("stone_2h", "stone", 1, 5),
    ]))

    levels.append(L(42, "冰封軌道", 22, 110, [
        g("right", 3, 1, "purple"),
        g("top", 1, 2, "green"),
        g("bottom", 5, 1, "purple"),
        g("left", 6, 1, "green"),
    ], [
        b("1x2", "purple", 2, 3, axis="h"),
        b("1x2", "green", 1, 5, axis="h"),
        b("2x1", "green", 6, 0, ice=1),
        b("1x1", "purple", 5, 6, ice=2),
        b("stone_1", "stone", 4, 1),
        b("stone_1", "stone", 0, 2),
        b("1x1", "green", 7, 4),
    ]))

    levels.append(L(43, "解凍 L 舞", 24, 115, [
        g("left", 2, 2, "red"),
        g("right", 5, 2, "blue"),
        g("top", 4, 1, "yellow"),
        g("bottom", 0, 1, "yellow"),
    ], [
        b("1x1", "yellow", 4, 3),
        b("L_ne", "red", 2, 2, ice=1),
        b("L_sw", "blue", 4, 5, ice=1),
        b("1x1", "yellow", 0, 6),
        b("stone_2v", "stone", 6, 0),
        b("stone_1", "stone", 1, 5),
        b("1x1", "red", 7, 3),
    ]))

    levels.append(L(44, "層層解凍", 24, 120, [
        g("right", 1, 1, "orange"),
        g("left", 4, 1, "green"),
        g("bottom", 2, 2, "purple"),
        g("top", 6, 1, "orange"),
    ], [
        b("1x1", "orange", 3, 1),
        b("1x1", "green", 4, 5),
        b("2x2", "purple", 2, 3, ice=2),
        b("1x1", "orange", 6, 4, ice=1),
        b("1x2", "green", 0, 0, ice=3),
        b("stone_1", "stone", 5, 2),
        b("stone_1", "stone", 1, 6),
    ]))

    levels.append(L(45, "冰石軸三重", 26, 120, [
        g("right", 2, 1, "red"),
        g("bottom", 5, 2, "blue"),
        g("left", 0, 2, "yellow"),
        g("top", 3, 1, "red"),
    ], [
        b("1x2", "red", 1, 2, axis="h"),
        b("L_se", "blue", 5, 4, ice=1),
        b("2x2", "yellow", 0, 4, ice=2),
        b("1x1", "red", 3, 5),
        b("stone_2h", "stone", 3, 0),
        b("stone_1", "stone", 4, 3),
        b("1x1", "blue", 7, 1),
    ]))

    levels.append(L(46, "終盤暖身", 26, 125, [
        g("top", 2, 2, "green"),
        g("right", 4, 2, "orange"),
        g("left", 6, 1, "purple"),
        g("bottom", 0, 1, "purple"),
    ], [
        b("1x1", "purple", 6, 3),
        b("L_nw", "green", 2, 2, ice=1),
        b("L_se", "orange", 4, 4, ice=1),
        b("1x1", "purple", 0, 7),
        b("1x1", "green", 5, 0),
        b("stone_1", "stone", 1, 4),
        b("stone_2v", "stone", 7, 5),
        b("1x2", "orange", 0, 0),
    ]))

    levels.append(L(47, "深凍迷宮", 28, 130, [
        g("right", 0, 1, "red"),
        g("left", 3, 1, "blue"),
        g("bottom", 5, 2, "yellow"),
        g("top", 1, 2, "blue"),
    ], [
        b("1x1", "red", 4, 0),
        b("1x2", "blue", 1, 3),
        b("L_sw", "yellow", 5, 4, ice=2),
        b("2x1", "blue", 3, 5, ice=1),
        b("1x1", "red", 7, 6, ice=3),
        b("stone_1", "stone", 2, 1),
        b("stone_1", "stone", 6, 2),
        b("stone_2h", "stone", 0, 6),
    ]))

    levels.append(L(48, "四色冰封", 28, 130, [
        g("right", 2, 1, "red"),
        g("left", 5, 1, "blue"),
        g("top", 3, 2, "green"),
        g("bottom", 0, 2, "yellow"),
    ], [
        b("1x1", "red", 5, 2),
        b("1x1", "blue", 2, 5),
        b("L_ne", "green", 3, 1, ice=1),
        b("L_sw", "yellow", 0, 4, ice=2),
        b("1x1", "green", 6, 6),
        b("1x1", "yellow", 7, 0),
        b("stone_1", "stone", 1, 2),
        b("stone_2v", "stone", 4, 4),
    ]))

    levels.append(L(49, "終極解凍", 30, 140, [
        g("right", 1, 2, "orange"),
        g("left", 4, 2, "purple"),
        g("bottom", 3, 1, "red"),
        g("top", 6, 1, "red"),
        g("bottom", 6, 1, "blue"),
    ], [
        b("1x1", "red", 3, 3),
        b("1x1", "blue", 6, 5),
        b("L_se", "orange", 4, 1, ice=1),
        b("L_nw", "purple", 1, 4, ice=2),
        b("2x1", "red", 7, 0, ice=2),
        b("stone_1", "stone", 0, 1),
        b("stone_1", "stone", 5, 6),
        b("stone_2h", "stone", 2, 0),
        b("1x1", "orange", 0, 7),
    ]))

    levels.append(L(50, "逃脫終章", 32, 150, [
        g("right", 2, 2, "red"),
        g("left", 5, 2, "blue"),
        g("top", 0, 2, "green"),
        g("bottom", 3, 2, "yellow"),
        g("right", 6, 1, "yellow"),
    ], [
        b("1x1", "green", 1, 3),
        b("1x1", "yellow", 4, 6),
        b("L_ne", "red", 3, 2, ice=1),
        b("L_sw", "blue", 1, 5, ice=2),
        b("2x2", "yellow", 5, 4, ice=2),
        b("1x2", "green", 4, 0, axis="h"),
        b("stone_1", "stone", 0, 4),
        b("stone_1", "stone", 6, 1),
        b("stone_2v", "stone", 2, 0),
        b("1x1", "red", 7, 7),
        b("1x1", "blue", 7, 0),
    ]))

    assert len(levels) == 50, len(levels)
    for i, lv in enumerate(levels):
        lv["id"] = i + 1
    return levels


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
        "## Shape cells relative to origin (top-left of bounding box).",
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
        "\t## Gates: side in {left,right,top,bottom}, start cell index along that edge, size in cells.",
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
    levels = build_levels()
    print(f"Built {len(levels)} levels")
    bad = 0
    for lv in levels:
        msg = validate_level(lv)
        if msg:
            print(f"VALIDATE FAIL L{lv['id']}: {msg}")
            bad += 1
        else:
            print(f"OK validate L{lv['id']} — {lv['title']}")
    if bad:
        print(f"Validation failed: {bad}")
        return 1

    OUT_GD.write_text(emit_gd(levels), encoding="utf-8")
    print(f"Wrote {OUT_GD}")

    # Optional: --solve to run BFS now
    if "--solve" in sys.argv or "--solve-only" in sys.argv:
        fails = []
        summary = []
        for lv in levels:
            cap = 250_000 if lv["id"] >= 36 else 150_000
            ok, exp, moves = bfs_solve(lv, cap)
            status = "OK" if ok else "FAIL"
            print(f"{status} solve L{lv['id']} expansions={exp} moves={moves} — {lv['title']}")
            summary.append((lv["id"], ok, exp, moves, lv["title"]))
            if not ok:
                fails.append(lv["id"])
        print("---")
        print(f"Solved {sum(1 for s in summary if s[1])}/50")
        if fails:
            print(f"Unsolvable: {fails}")
            return 2
        # write summary json
        (ROOT / "tools" / "solve_summary.json").write_text(
            json.dumps(
                [{"id": a, "ok": b, "exp": c, "moves": d, "title": e} for a, b, c, d, e in summary],
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
