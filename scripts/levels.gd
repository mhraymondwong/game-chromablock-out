extends RefCounted
class_name LevelData
## Original Color Block Escape levels — not copied from any commercial title.
## Board is 8×8 (BoardModel.SIZE).

const COLORS := {
	"red": Color(0.95, 0.35, 0.40),
	"blue": Color(0.35, 0.55, 0.95),
	"green": Color(0.35, 0.78, 0.45),
	"yellow": Color(0.98, 0.82, 0.28),
	"orange": Color(0.98, 0.58, 0.28),
	"purple": Color(0.72, 0.45, 0.90),
	"stone": Color(0.55, 0.58, 0.62),
}

## Shape cells relative to origin (top-left of bounding box).
static func shape_cells(shape: String) -> Array:
	match shape:
		"1x1":
			return [Vector2i(0, 0)]
		"1x2":
			return [Vector2i(0, 0), Vector2i(1, 0)]
		"1x3":
			return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
		"2x1":
			return [Vector2i(0, 0), Vector2i(0, 1)]
		"3x1":
			return [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
		"2x2":
			return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
		"L_ne":  # └ shape pointing up-right from bottom-left
			return [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
		"L_nw":
			return [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
		"L_se":
			return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
		"L_sw":
			return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]
		"stone_1":
			return [Vector2i(0, 0)]
		"stone_2h":
			return [Vector2i(0, 0), Vector2i(1, 0)]
		"stone_2v":
			return [Vector2i(0, 0), Vector2i(0, 1)]
		_:
			return [Vector2i(0, 0)]


static func shape_size(shape: String) -> Vector2i:
	var cells: Array = shape_cells(shape)
	var mx := 0
	var my := 0
	for c in cells:
		mx = maxi(mx, c.x)
		my = maxi(my, c.y)
	return Vector2i(mx + 1, my + 1)


static func is_stone(shape: String) -> bool:
	return shape.begins_with("stone")


static func all_levels() -> Array:
	## 8 original levels on an 8×8 board.
	## Gates: side in {left,right,top,bottom}, start cell index along that edge, size in cells.
	return [
		# Level 1 — warm-up: one red 1x1 → right gate
		{
			"id": 1,
			"title": "第一次逃脫",
			"par": 4,
			"gold": 30,
			"gates": [
				{"side": "right", "start": 3, "size": 1, "color": "red"},
			],
			"blocks": [
				{"shape": "1x1", "color": "red", "x": 2, "y": 3},
			],
		},
		# Level 2 — horizontal 1x2 + 1x1 both blue (tests multi-cell exit)
		{
			"id": 2,
			"title": "長長的朋友",
			"par": 6,
			"gold": 35,
			"gates": [
				{"side": "right", "start": 2, "size": 1, "color": "blue"},
			],
			"blocks": [
				{"shape": "1x2", "color": "blue", "x": 1, "y": 2},
				{"shape": "1x1", "color": "blue", "x": 4, "y": 4},
			],
		},
		# Level 3 — two colors, two gates
		{
			"id": 3,
			"title": "紅藍合作",
			"par": 8,
			"gold": 45,
			"gates": [
				{"side": "right", "start": 1, "size": 1, "color": "red"},
				{"side": "bottom", "start": 4, "size": 1, "color": "blue"},
			],
			"blocks": [
				{"shape": "1x1", "color": "red", "x": 2, "y": 1},
				{"shape": "2x1", "color": "blue", "x": 4, "y": 3},
				{"shape": "1x1", "color": "red", "x": 5, "y": 2},
			],
		},
		# Level 4 — introduce stones
		{
			"id": 4,
			"title": "石頭擋路",
			"par": 10,
			"gold": 50,
			"gates": [
				{"side": "left", "start": 3, "size": 1, "color": "green"},
				{"side": "right", "start": 5, "size": 1, "color": "yellow"},
			],
			"blocks": [
				{"shape": "stone_1", "color": "stone", "x": 3, "y": 4},
				{"shape": "stone_1", "color": "stone", "x": 4, "y": 2},
				{"shape": "1x2", "color": "green", "x": 1, "y": 3},
				{"shape": "1x1", "color": "yellow", "x": 5, "y": 1},
				{"shape": "2x1", "color": "yellow", "x": 6, "y": 4},
			],
		},
		# Level 5 — 2x2 square needs wide gate
		{
			"id": 5,
			"title": "大方塊出門",
			"par": 10,
			"gold": 55,
			"gates": [
				{"side": "bottom", "start": 3, "size": 2, "color": "orange"},
				{"side": "top", "start": 1, "size": 1, "color": "purple"},
			],
			"blocks": [
				{"shape": "2x2", "color": "orange", "x": 3, "y": 2},
				{"shape": "1x1", "color": "purple", "x": 1, "y": 3},
				{"shape": "stone_2h", "color": "stone", "x": 5, "y": 5},
			],
		},
		# Level 6 — axis lock (↔ horizontal only / ↕ vertical only)
		{
			"id": 6,
			"title": "只能直走",
			"par": 12,
			"gold": 60,
			"gates": [
				{"side": "right", "start": 2, "size": 1, "color": "red"},
				{"side": "bottom", "start": 5, "size": 1, "color": "blue"},
			],
			"blocks": [
				{"shape": "1x3", "color": "red", "x": 1, "y": 2, "axis": "h"},
				{"shape": "3x1", "color": "blue", "x": 5, "y": 3, "axis": "v"},
				{"shape": "stone_1", "color": "stone", "x": 3, "y": 4},
				{"shape": "1x1", "color": "red", "x": 6, "y": 1},
			],
		},
		# Level 7 — L piece + multi-color scramble
		{
			"id": 7,
			"title": "彎彎的腳",
			"par": 14,
			"gold": 75,
			"gates": [
				{"side": "left", "start": 1, "size": 2, "color": "green"},
				{"side": "right", "start": 4, "size": 1, "color": "yellow"},
				{"side": "bottom", "start": 2, "size": 1, "color": "purple"},
			],
			"blocks": [
				{"shape": "L_se", "color": "green", "x": 2, "y": 2},
				{"shape": "1x2", "color": "yellow", "x": 4, "y": 4},
				{"shape": "1x1", "color": "purple", "x": 2, "y": 6},
				{"shape": "stone_2v", "color": "stone", "x": 0, "y": 4},
				{"shape": "2x1", "color": "yellow", "x": 6, "y": 2},
			],
		},
		# Level 8 — ice unlock (ice blocks unlock after N colored exits)
		{
			"id": 8,
			"title": "冰封寶藏",
			"par": 16,
			"gold": 90,
			"gates": [
				{"side": "top", "start": 3, "size": 1, "color": "blue"},
				{"side": "right", "start": 5, "size": 2, "color": "orange"},
				{"side": "left", "start": 4, "size": 1, "color": "red"},
			],
			"blocks": [
				{"shape": "1x1", "color": "blue", "x": 3, "y": 3},
				{"shape": "1x1", "color": "red", "x": 2, "y": 4},
				{"shape": "2x2", "color": "orange", "x": 4, "y": 4, "ice": 2},
				{"shape": "stone_1", "color": "stone", "x": 0, "y": 1},
				{"shape": "stone_1", "color": "stone", "x": 7, "y": 2},
				{"shape": "1x2", "color": "blue", "x": 4, "y": 1},
			],
		},
	]


static func get_level(index: int) -> Dictionary:
	var levels: Array = all_levels()
	if index < 0 or index >= levels.size():
		return {}
	return levels[index].duplicate(true)


static func level_count() -> int:
	return all_levels().size()
