#!/usr/bin/env python3
"""Fast Python BFS solvability — mirrors BoardModel; aligned mid-stops like smoke_quick."""
from __future__ import annotations
import sys
from collections import deque
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_levels50 as gen

SHAPES = gen.SHAPES
SIZE = 8
DIRS = ((1, 0), (-1, 0), (0, 1), (0, -1))


def cells_of(shape, x, y):
    return tuple((x + cx, y + cy) for cx, cy in SHAPES[shape])


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
                i, shape, b["color"], b["x"], b["y"],
                b.get("axis", ""), ice, ice > 0, shape.startswith("stone"),
            ])
        # indices: id0 shape1 color2 x3 y4 axis5 ice6 frozen7 stone8

    def copy(self):
        b = Board.__new__(Board)
        b.gates = self.gates
        b.exits_done = self.exits_done
        b.blocks = [bl[:] for bl in self.blocks]
        return b

    def key(self):
        parts = sorted(
            (bl[0], bl[3], bl[4], int(bl[7])) for bl in self.blocks
        )
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
        side = {(1, 0): "right", (-1, 0): "left", (0, 1): "bottom", (0, -1): "top"}[d]
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


def solve(data, cap=120000):
    """Enqueue max-slide OR gate-aligned mid-stops OR exit (smoke_quick style)."""
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


def main():
    levels = gen.LEVELS
    print(f"Solving {len(levels)} levels…", flush=True)
    fails = []
    hard = []
    for lv in levels:
        lid = lv["id"]
        caps = [50000, 150000, 400000]
        ok = False
        proc = moves = 0
        used = 0
        for cap in caps:
            ok, proc, moves = solve(lv, cap)
            used = cap
            if ok:
                break
        status = "OK" if ok else "FAIL"
        if ok and proc > 30000:
            hard.append(lid)
        print(
            f"{status} L{lid:02d} {lv['title']} cap={used} proc={proc} moves={moves}",
            flush=True,
        )
        if not ok:
            fails.append(lid)
    print(f"DONE fails={fails} hard={hard}", flush=True)
    return 1 if fails else 0


if __name__ == "__main__":
    raise SystemExit(main())
