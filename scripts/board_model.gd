extends RefCounted
class_name BoardModel
## Pure board logic for Color Block Escape.

const SIZE := 8

var blocks: Array = []  # each: {id, shape, color, x, y, axis, ice, frozen, cells}
var gates: Array = []
var moves: int = 0
var exits_done: int = 0
var history: Array = []  # stack of snapshots
var last_exit_time: float = -999.0
var combo_bonus: int = 0


func load_level(data: Dictionary) -> void:
	blocks.clear()
	gates = data.get("gates", []).duplicate(true)
	moves = 0
	exits_done = 0
	history.clear()
	last_exit_time = -999.0
	combo_bonus = 0
	var id := 0
	for b in data.get("blocks", []):
		var shape: String = str(b.get("shape", "1x1"))
		var blk: Dictionary = {
			"id": id,
			"shape": shape,
			"color": str(b.get("color", "red")),
			"x": int(b.get("x", 0)),
			"y": int(b.get("y", 0)),
			"axis": str(b.get("axis", "")),  # "" | "h" | "v"
			"ice": int(b.get("ice", 0)),  # unlock after N exits; 0 = none
			"frozen": int(b.get("ice", 0)) > 0,
			"stone": LevelData.is_stone(shape),
		}
		blk["cells"] = _abs_cells(blk)
		blocks.append(blk)
		id += 1


func snapshot() -> Dictionary:
	var bl: Array = []
	for b in blocks:
		bl.append({
			"id": b.id,
			"shape": b.shape,
			"color": b.color,
			"x": b.x,
			"y": b.y,
			"axis": b.axis,
			"ice": b.ice,
			"frozen": b.frozen,
			"stone": b.stone,
		})
	return {
		"blocks": bl,
		"moves": moves,
		"exits_done": exits_done,
		"combo_bonus": combo_bonus,
		"last_exit_time": last_exit_time,
	}


func restore(snap: Dictionary) -> void:
	blocks.clear()
	for b in snap.blocks:
		var blk: Dictionary = b.duplicate(true)
		blk["cells"] = _abs_cells(blk)
		blocks.append(blk)
	moves = int(snap.moves)
	exits_done = int(snap.exits_done)
	combo_bonus = int(snap.get("combo_bonus", 0))
	last_exit_time = float(snap.get("last_exit_time", -999.0))


func push_history() -> void:
	history.append(snapshot())
	if history.size() > 80:
		history.pop_front()


func undo() -> bool:
	if history.is_empty():
		return false
	var snap: Dictionary = history.pop_back()
	restore(snap)
	return true


func _abs_cells(blk: Dictionary) -> Array:
	var out: Array = []
	for c in LevelData.shape_cells(str(blk.shape)):
		out.append(Vector2i(int(blk.x) + c.x, int(blk.y) + c.y))
	return out


func occupancy(ignore_id: int = -1) -> Dictionary:
	var occ: Dictionary = {}
	for b in blocks:
		if int(b.id) == ignore_id:
			continue
		for c in b.cells:
			occ[c] = b.id
	return occ


func get_block(id: int) -> Dictionary:
	for b in blocks:
		if int(b.id) == id:
			return b
	return {}


func block_at_cell(cell: Vector2i) -> int:
	for b in blocks:
		for c in b.cells:
			if c == cell:
				return int(b.id)
	return -1


func can_place(blk: Dictionary, nx: int, ny: int) -> bool:
	if bool(blk.get("frozen", false)):
		return false
	var axis: String = str(blk.get("axis", ""))
	if axis == "h" and ny != int(blk.y):
		return false
	if axis == "v" and nx != int(blk.x):
		return false
	var cells: Array = []
	for c in LevelData.shape_cells(str(blk.shape)):
		var p := Vector2i(nx + c.x, ny + c.y)
		if p.x < 0 or p.y < 0 or p.x >= SIZE or p.y >= SIZE:
			return false
		cells.append(p)
	var occ := occupancy(int(blk.id))
	for p in cells:
		if occ.has(p):
			return false
	return true


## Try to move block by delta cells. Returns true if position changed.
func try_move(id: int, dx: int, dy: int) -> bool:
	var blk: Dictionary = get_block(id)
	if blk.is_empty() or bool(blk.stone):
		return false
	if dx == 0 and dy == 0:
		return false
	# Axis lock: only allow allowed component
	var axis: String = str(blk.get("axis", ""))
	if axis == "h":
		dy = 0
	elif axis == "v":
		dx = 0
	if dx == 0 and dy == 0:
		return false
	# Slide step by step along the dominant axis first for clarity
	var sx := 1 if dx > 0 else (-1 if dx < 0 else 0)
	var sy := 1 if dy > 0 else (-1 if dy < 0 else 0)
	var moved := false
	var cx := int(blk.x)
	var cy := int(blk.y)
	# Move along x
	for _i in abs(dx):
		if can_place(blk, cx + sx, cy):
			cx += sx
			moved = true
		else:
			break
	# Refresh blk position for y slide
	blk.x = cx
	blk.y = cy
	blk.cells = _abs_cells(blk)
	for _i in abs(dy):
		if can_place(blk, cx, cy + sy):
			cy += sy
			moved = true
		else:
			break
	if moved:
		_set_pos(id, cx, cy)
	return moved


func _set_pos(id: int, x: int, y: int) -> void:
	for i in blocks.size():
		if int(blocks[i].id) == id:
			blocks[i].x = x
			blocks[i].y = y
			blocks[i].cells = _abs_cells(blocks[i])
			return


## Check if block can exit through a matching gate in given direction (unit Vector2i).
func can_exit(id: int, dir: Vector2i) -> Dictionary:
	var blk: Dictionary = get_block(id)
	if blk.is_empty() or bool(blk.stone) or bool(blk.get("frozen", false)):
		return {}
	var color: String = str(blk.color)
	var cells: Array = blk.cells
	# Find matching gate on the appropriate side
	var side := ""
	if dir == Vector2i(1, 0):
		side = "right"
	elif dir == Vector2i(-1, 0):
		side = "left"
	elif dir == Vector2i(0, 1):
		side = "bottom"
	elif dir == Vector2i(0, -1):
		side = "top"
	else:
		return {}
	# Gate must cover the full span of the piece perpendicular to the exit direction
	var min_x0 := 999
	var max_x0 := -1
	var min_y0 := 999
	var max_y0 := -1
	for c in cells:
		min_x0 = mini(min_x0, c.x)
		max_x0 = maxi(max_x0, c.x)
		min_y0 = mini(min_y0, c.y)
		max_y0 = maxi(max_y0, c.y)
	var need: int = (max_y0 - min_y0 + 1) if side in ["left", "right"] else (max_x0 - min_x0 + 1)
	var gate: Dictionary = {}
	for g in gates:
		if str(g.side) != side:
			continue
		if str(g.color) != color:
			continue
		if int(g.size) < need:
			continue
		gate = g
		break
	if gate.is_empty():
		return {}
	# Block must touch that edge (max/min along exit axis), not every cell on the rim —
	# otherwise horizontal bars can never exit left/right (and vertical never top/bottom).
	var g_start: int = int(gate.start)
	var g_end: int = g_start + int(gate.size) - 1
	var min_x := 999
	var max_x := -1
	var min_y := 999
	var max_y := -1
	for c in cells:
		min_x = mini(min_x, c.x)
		max_x = maxi(max_x, c.x)
		min_y = mini(min_y, c.y)
		max_y = maxi(max_y, c.y)
	match side:
		"right":
			if max_x != SIZE - 1:
				return {}
			if min_y < g_start or max_y > g_end:
				return {}
		"left":
			if min_x != 0:
				return {}
			if min_y < g_start or max_y > g_end:
				return {}
		"bottom":
			if max_y != SIZE - 1:
				return {}
			if min_x < g_start or max_x > g_end:
				return {}
		"top":
			if min_y != 0:
				return {}
			if min_x < g_start or max_x > g_end:
				return {}
	return gate


func try_exit(id: int, dir: Vector2i, now_sec: float) -> bool:
	var gate := can_exit(id, dir)
	if gate.is_empty():
		return false
	# Remove block
	for i in range(blocks.size() - 1, -1, -1):
		if int(blocks[i].id) == id:
			blocks.remove_at(i)
			break
	exits_done += 1
	# Combo
	if now_sec - last_exit_time <= 8.0 and last_exit_time > 0:
		combo_bonus = mini(15, combo_bonus + 3)
	last_exit_time = now_sec
	# Unlock ice
	_update_ice()
	return true


func _update_ice() -> void:
	for i in blocks.size():
		if int(blocks[i].get("ice", 0)) > 0:
			blocks[i].frozen = exits_done < int(blocks[i].ice)


func colored_remaining() -> int:
	var n := 0
	for b in blocks:
		if not bool(b.stone):
			n += 1
	return n


func is_clear() -> bool:
	return colored_remaining() == 0


## Score out of 100 (+ combo).
static func compute_score(move_count: int, par: int, elapsed: float, gold: float, combo: int) -> Dictionary:
	# Moves portion: 50 max
	var move_pts := 50
	if move_count > par:
		move_pts = maxi(10, 50 - 4 * (move_count - par))
	# Time portion: 50 max
	var time_pts := 50
	if elapsed > gold:
		if elapsed <= 180.0:
			# decay from 50 at gold to 10 at 180
			var t := (elapsed - gold) / maxf(1.0, 180.0 - gold)
			time_pts = int(round(lerpf(50.0, 10.0, clampf(t, 0.0, 1.0))))
		else:
			# overtime: from 10, -1/sec → 0 fail
			time_pts = maxi(0, 10 - int(floor(elapsed - 180.0)))
	var failed := time_pts <= 0 and elapsed > 180.0
	var total := move_pts + time_pts + combo
	if failed:
		total = 0
	var stars := 0
	if total >= 85:
		stars = 3
	elif total >= 60:
		stars = 2
	elif total >= 1:
		stars = 1
	return {
		"total": total,
		"moves": move_pts,
		"time": time_pts,
		"combo": combo,
		"stars": stars,
		"failed": failed,
	}


## Hint: prefer a block that can exit now; else a movable block toward a gate.
func hint() -> Dictionary:
	for b in blocks:
		if bool(b.stone) or bool(b.get("frozen", false)):
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not can_exit(int(b.id), d).is_empty():
				return {"id": int(b.id), "dir": d, "exit": true}
	# Otherwise suggest sliding toward nearest matching gate
	for b in blocks:
		if bool(b.stone) or bool(b.get("frozen", false)):
			continue
		var color: String = str(b.color)
		for g in gates:
			if str(g.color) != color:
				continue
			var dir := Vector2i.ZERO
			match str(g.side):
				"right":
					dir = Vector2i(1, 0)
				"left":
					dir = Vector2i(-1, 0)
				"bottom":
					dir = Vector2i(0, 1)
				"top":
					dir = Vector2i(0, -1)
			if try_probe_move(int(b.id), dir.x, dir.y):
				return {"id": int(b.id), "dir": dir, "exit": false}
	# Any free move
	for b in blocks:
		if bool(b.stone) or bool(b.get("frozen", false)):
			continue
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if try_probe_move(int(b.id), d.x, d.y):
				return {"id": int(b.id), "dir": d, "exit": false}
	return {}


func try_probe_move(id: int, dx: int, dy: int) -> bool:
	var blk: Dictionary = get_block(id)
	if blk.is_empty():
		return false
	return can_place(blk, int(blk.x) + dx, int(blk.y) + dy)


## Validate level layout: no overlaps, in bounds.
static func validate_level(data: Dictionary) -> String:
	var occ: Dictionary = {}
	for b in data.get("blocks", []):
		var shape: String = str(b.get("shape", "1x1"))
		var x: int = int(b.get("x", 0))
		var y: int = int(b.get("y", 0))
		for c in LevelData.shape_cells(shape):
			var p := Vector2i(x + c.x, y + c.y)
			if p.x < 0 or p.y < 0 or p.x >= SIZE or p.y >= SIZE:
				return "out of bounds: %s at %s" % [shape, str(p)]
			if occ.has(p):
				return "overlap at %s" % str(p)
			occ[p] = true
	for g in data.get("gates", []):
		var start: int = int(g.get("start", 0))
		var size: int = int(g.get("size", 1))
		if start < 0 or start + size > SIZE:
			return "bad gate %s" % str(g)
	return ""
