extends Node2D
## 彩色方塊逃脫 — Color Block Escape main scene.

const CELL := 84
const BOARD_ORIGIN := Vector2(340, 96)
const GAP := 6

var font: Font
var model: BoardModel
var level_index: int = 0
var level_data: Dictionary = {}
var unlocked: int = 1  # levels 1..unlocked playable
var best_stars: Array = [0, 0, 0, 0, 0, 0, 0, 0]

var selected_id: int = -1
var dragging: bool = false
var drag_moved: bool = false
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_cell: Vector2i = Vector2i.ZERO
var drag_origin_xy: Vector2i = Vector2i.ZERO
var gesture_counted: bool = false

var elapsed: float = 0.0
var running: bool = false
var show_rules: bool = true
var show_clear: bool = false
var show_map: bool = false
var show_fail: bool = false
var clear_result: Dictionary = {}
var hint_flash: Dictionary = {}
var hint_timer: float = 0.0
var exit_anim: Dictionary = {}  # id -> {pos, color, t}
var toast: String = ""
var toast_t: float = 0.0

# Soft pastel background
var bg_a := Color(0.93, 0.96, 1.0)
var bg_b := Color(0.98, 0.93, 0.96)


func _ready() -> void:
	font = load("res://assets/fonts/NotoSansCJK-Regular.ttc")
	if font == null:
		font = ThemeDB.fallback_font
	model = BoardModel.new()
	_load_progress()
	_start_level(0)
	show_rules = true
	running = false


func _load_progress() -> void:
	if FileAccess.file_exists("user://cbe_progress.cfg"):
		var cfg := ConfigFile.new()
		if cfg.load("user://cbe_progress.cfg") == OK:
			unlocked = int(cfg.get_value("p", "unlocked", 1))
			best_stars = cfg.get_value("p", "stars", best_stars)


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("p", "unlocked", unlocked)
	cfg.set_value("p", "stars", best_stars)
	cfg.save("user://cbe_progress.cfg")


func _start_level(idx: int) -> void:
	level_index = clampi(idx, 0, LevelData.level_count() - 1)
	level_data = LevelData.get_level(level_index)
	model.load_level(level_data)
	selected_id = -1
	dragging = false
	elapsed = 0.0
	running = not show_rules and not show_map
	show_clear = false
	show_fail = false
	clear_result = {}
	hint_flash = {}
	exit_anim.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if running and not show_clear and not show_fail and not show_rules and not show_map:
		elapsed += delta
		var gold: float = float(level_data.get("gold", 60))
		var sc: Dictionary = BoardModel.compute_score(model.moves, int(level_data.get("par", 5)), elapsed, gold, model.combo_bonus)
		if sc.failed:
			running = false
			show_fail = true
	if hint_timer > 0.0:
		hint_timer -= delta
		if hint_timer <= 0.0:
			hint_flash = {}
	if toast_t > 0.0:
		toast_t -= delta
	# Animate exits
	var done: Array = []
	for k in exit_anim.keys():
		exit_anim[k].t += delta
		if exit_anim[k].t > 0.45:
			done.append(k)
	for k in done:
		exit_anim.erase(k)
	queue_redraw()


func _board_rect() -> Rect2:
	var s := BoardModel.SIZE * (CELL + GAP) - GAP
	return Rect2(BOARD_ORIGIN, Vector2(s, s))


func _cell_rect(cx: int, cy: int) -> Rect2:
	var p := BOARD_ORIGIN + Vector2(cx * (CELL + GAP), cy * (CELL + GAP))
	return Rect2(p, Vector2(CELL, CELL))


func _cell_at(pos: Vector2) -> Vector2i:
	var local := pos - BOARD_ORIGIN
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var cx := int(local.x / (CELL + GAP))
	var cy := int(local.y / (CELL + GAP))
	if cx < 0 or cy < 0 or cx >= BoardModel.SIZE or cy >= BoardModel.SIZE:
		return Vector2i(-1, -1)
	return Vector2i(cx, cy)


func _draw() -> void:
	# Background gradient-ish
	draw_rect(Rect2(0, 0, 1280, 720), bg_a)
	draw_circle(Vector2(180, 120), 160, Color(1, 0.85, 0.9, 0.35))
	draw_circle(Vector2(1100, 600), 200, Color(0.75, 0.9, 1.0, 0.4))
	draw_circle(Vector2(1000, 100), 120, Color(0.9, 1.0, 0.8, 0.3))

	_draw_hud()
	_draw_board()
	_draw_gates()
	_draw_blocks()
	_draw_exit_anims()
	_draw_side_panel()

	if show_rules:
		_draw_modal_rules()
	elif show_map:
		_draw_modal_map()
	elif show_clear:
		_draw_modal_clear()
	elif show_fail:
		_draw_modal_fail()

	if toast_t > 0.0:
		_draw_toast()


func _draw_text(pos: Vector2, text: String, size: int, col: Color, outline: bool = false) -> void:
	if outline:
		draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.25))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_hud() -> void:
	# Top bar
	draw_rect(Rect2(0, 0, 1280, 64), Color(1, 1, 1, 0.72))
	draw_rect(Rect2(0, 62, 1280, 2), Color(0.7, 0.75, 0.85, 0.5))
	var title := "彩色方塊逃脫"
	_draw_text(Vector2(24, 42), title, 28, Color(0.25, 0.3, 0.45), true)
	_draw_text(Vector2(250, 40), "Color Block Escape", 16, Color(0.45, 0.5, 0.6))

	var lv := "關卡 %d / %d　%s" % [level_index + 1, LevelData.level_count(), str(level_data.get("title", ""))]
	_draw_text(Vector2(480, 40), lv, 20, Color(0.3, 0.35, 0.5))

	var gold: float = float(level_data.get("gold", 60))
	var sc: Dictionary = BoardModel.compute_score(model.moves, int(level_data.get("par", 5)), elapsed, gold, model.combo_bonus)
	var mm := int(elapsed) / 60
	var ss := int(elapsed) % 60
	var tcol := Color(0.2, 0.55, 0.35) if elapsed <= gold else Color(0.85, 0.4, 0.2)
	_draw_text(Vector2(900, 28), "時間 %02d:%02d" % [mm, ss], 18, tcol)
	_draw_text(Vector2(900, 50), "分數 %d" % int(sc.total), 18, Color(0.35, 0.35, 0.55))
	_draw_text(Vector2(1050, 28), "步數 %d / %d" % [model.moves, int(level_data.get("par", 5))], 18, Color(0.35, 0.4, 0.55))
	if model.combo_bonus > 0:
		_draw_text(Vector2(1050, 50), "連擊 +%d" % model.combo_bonus, 16, Color(0.9, 0.45, 0.2))


func _draw_board() -> void:
	var br := _board_rect()
	# Shadow
	draw_rect(Rect2(br.position + Vector2(8, 10), br.size), Color(0.4, 0.45, 0.55, 0.18), true, -1.0)
	# Board frame
	draw_rect(Rect2(br.position - Vector2(14, 14), br.size + Vector2(28, 28)), Color(0.98, 0.97, 0.94), true, -1.0)
	draw_rect(Rect2(br.position - Vector2(14, 14), br.size + Vector2(28, 28)), Color(0.75, 0.7, 0.65), false, 3.0)
	for y in BoardModel.SIZE:
		for x in BoardModel.SIZE:
			var r := _cell_rect(x, y)
			var c := Color(0.88, 0.90, 0.93) if (x + y) % 2 == 0 else Color(0.84, 0.87, 0.91)
			_round_rect(r, 14, c)


func _round_rect(r: Rect2, rad: float, col: Color) -> void:
	draw_rect(Rect2(r.position + Vector2(rad, 0), r.size - Vector2(rad * 2, 0)), col)
	draw_rect(Rect2(r.position + Vector2(0, rad), Vector2(r.size.x, r.size.y - rad * 2)), col)
	draw_circle(r.position + Vector2(rad, rad), rad, col)
	draw_circle(r.position + Vector2(r.size.x - rad, rad), rad, col)
	draw_circle(r.position + Vector2(rad, r.size.y - rad), rad, col)
	draw_circle(r.position + Vector2(r.size.x - rad, r.size.y - rad), rad, col)


func _draw_gates() -> void:
	for g in model.gates:
		var col: Color = LevelData.COLORS.get(str(g.color), Color.WHITE)
		var start: int = int(g.start)
		var size: int = int(g.size)
		match str(g.side):
			"right":
				for i in size:
					var r := _cell_rect(BoardModel.SIZE - 1, start + i)
					var door := Rect2(r.position.x + r.size.x + 4, r.position.y + 8, 18, r.size.y - 16)
					_round_rect(door, 6, col)
					draw_rect(door, Color(1, 1, 1, 0.35), false, 2.0)
			"left":
				for i in size:
					var r2 := _cell_rect(0, start + i)
					var door2 := Rect2(r2.position.x - 22, r2.position.y + 8, 18, r2.size.y - 16)
					_round_rect(door2, 6, col)
					draw_rect(door2, Color(1, 1, 1, 0.35), false, 2.0)
			"bottom":
				for i in size:
					var r3 := _cell_rect(start + i, BoardModel.SIZE - 1)
					var door3 := Rect2(r3.position.x + 8, r3.position.y + r3.size.y + 4, r3.size.x - 16, 18)
					_round_rect(door3, 6, col)
					draw_rect(door3, Color(1, 1, 1, 0.35), false, 2.0)
			"top":
				for i in size:
					var r4 := _cell_rect(start + i, 0)
					var door4 := Rect2(r4.position.x + 8, r4.position.y - 22, r4.size.x - 16, 18)
					_round_rect(door4, 6, col)
					draw_rect(door4, Color(1, 1, 1, 0.35), false, 2.0)


func _block_bounds(blk: Dictionary) -> Rect2:
	var cells: Array = blk.cells
	if cells.is_empty():
		return Rect2()
	var minx: int = cells[0].x
	var miny: int = cells[0].y
	var maxx: int = cells[0].x
	var maxy: int = cells[0].y
	for c in cells:
		minx = mini(minx, c.x)
		miny = mini(miny, c.y)
		maxx = maxi(maxx, c.x)
		maxy = maxi(maxy, c.y)
	var p0 := _cell_rect(minx, miny).position
	var p1 := _cell_rect(maxx, maxy)
	return Rect2(p0, (p1.position + p1.size) - p0)


func _draw_blocks() -> void:
	for b in model.blocks:
		_draw_one_block(b, 1.0)
	# Hint highlight
	if not hint_flash.is_empty() and hint_timer > 0.0:
		var hb: Dictionary = model.get_block(int(hint_flash.get("id", -1)))
		if not hb.is_empty():
			var r := _block_bounds(hb)
			var pulse: float = 0.4 + 0.4 * abs(sin(hint_timer * 8.0))
			draw_rect(r.grow(6), Color(1, 1, 0.3, pulse), false, 4.0)


func _draw_one_block(b: Dictionary, alpha: float) -> void:
	var col: Color = LevelData.COLORS.get(str(b.color), Color.GRAY)
	col.a = alpha
	var stone: bool = bool(b.stone)
	var frozen: bool = bool(b.get("frozen", false))
	var base: Color = col if not stone else LevelData.COLORS["stone"]
	base.a = alpha
	# Connected body: fill cells with tiny inset so multi-cell pieces look glued
	for c in b.cells:
		var grow := -1
		var r: Rect2 = _cell_rect(c.x, c.y).grow(grow)
		_round_rect(Rect2(r.position + Vector2(3, 4), r.size), 14, Color(0, 0, 0, 0.10 * alpha))
		_round_rect(r, 14, base)
	# Soft outline of whole bounds
	var bounds: Rect2 = _block_bounds(b).grow(1)
	draw_rect(bounds, Color(1, 1, 1, 0.22 * alpha), false, 2.0)
	# Single gloss strip across top of bounds
	_round_rect(Rect2(bounds.position + Vector2(10, 8), Vector2(bounds.size.x - 20, mini(22.0, bounds.size.y * 0.22))), 10, Color(1, 1, 1, 0.25 * alpha))
	if frozen:
		_round_rect(bounds, 12, Color(0.7, 0.9, 1.0, 0.4 * alpha))
		_draw_text(bounds.get_center() + Vector2(-14, 10), "❄", 32, Color(1, 1, 1, 0.95 * alpha))
	elif not stone:
		_draw_face(bounds.get_center(), mini(bounds.size.x, bounds.size.y) * 0.18, alpha)
	var axis: String = str(b.get("axis", ""))
	if axis != "":
		var icon := "↔" if axis == "h" else "↕"
		_draw_text(bounds.position + Vector2(8, 24), icon, 20, Color(1, 1, 1, 0.95 * alpha))
	if int(b.id) == selected_id:
		draw_rect(bounds.grow(5), Color(1, 1, 1, 0.9), false, 3.0)


func _draw_face(center: Vector2, s: float, alpha: float) -> void:
	# Simple happy face
	var eye := Color(0.2, 0.2, 0.28, alpha)
	draw_circle(center + Vector2(-s * 0.45, -s * 0.25), s * 0.18, eye)
	draw_circle(center + Vector2(s * 0.45, -s * 0.25), s * 0.18, eye)
	# Smile arc approximated with small circles
	for i in 5:
		var t := (i / 4.0) * PI
		var p := center + Vector2(cos(t) * s * 0.55, sin(t) * s * 0.45 + s * 0.15)
		draw_circle(p, s * 0.1, eye)


func _draw_exit_anims() -> void:
	for k in exit_anim.keys():
		var a: Dictionary = exit_anim[k]
		var t: float = float(a.t)
		var fade: float = 1.0 - clampf(t / 0.45, 0.0, 1.0)
		var col: Color = a.color
		col.a = fade
		var p: Vector2 = a.pos + a.dir * t * 180.0
		draw_circle(p, 28 * fade + 10, col)
		_draw_text(p + Vector2(-10, 8), "★", 22, Color(1, 1, 0.6, fade))


func _draw_side_panel() -> void:
	var px := 980.0
	var py := 100.0
	_round_rect(Rect2(px, py, 270, 520), 18, Color(1, 1, 1, 0.78))
	_draw_text(Vector2(px + 24, py + 40), "操作", 24, Color(0.3, 0.35, 0.5))
	_draw_text(Vector2(px + 24, py + 78), "拖曳方塊滑動", 16, Color(0.4, 0.45, 0.55))
	_draw_text(Vector2(px + 24, py + 102), "方向鍵 / WASD 移動", 16, Color(0.4, 0.45, 0.55))
	_draw_text(Vector2(px + 24, py + 126), "同色門才能出去", 16, Color(0.4, 0.45, 0.55))
	_draw_text(Vector2(px + 24, py + 150), "Z 復原　H 提示", 16, Color(0.4, 0.45, 0.55))

	_draw_button(Rect2(px + 30, py + 190, 210, 48), "↺  復原", Color(0.55, 0.7, 0.95))
	_draw_button(Rect2(px + 30, py + 250, 210, 48), "⟳  重來", Color(0.95, 0.7, 0.55))
	_draw_button(Rect2(px + 30, py + 310, 210, 48), "💡  提示", Color(0.95, 0.85, 0.4))
	_draw_button(Rect2(px + 30, py + 370, 210, 48), "🗺  關卡地圖", Color(0.7, 0.85, 0.6))
	_draw_button(Rect2(px + 30, py + 430, 210, 48), "❓  規則", Color(0.8, 0.75, 0.9))

	_draw_text(Vector2(px + 24, py + 500), "灰色石頭不會離開", 14, Color(0.5, 0.55, 0.6))


func _draw_button(r: Rect2, label: String, col: Color) -> void:
	_round_rect(Rect2(r.position + Vector2(2, 3), r.size), 12, Color(0, 0, 0, 0.12))
	_round_rect(r, 12, col)
	_round_rect(Rect2(r.position + Vector2(6, 4), Vector2(r.size.x - 12, 14)), 8, Color(1, 1, 1, 0.25))
	_draw_text(r.position + Vector2(24, r.size.y * 0.65), label, 20, Color(0.2, 0.22, 0.3))


func _hit_button(pos: Vector2) -> String:
	var px := 980.0
	var py := 100.0
	var buttons := {
		"undo": Rect2(px + 30, py + 190, 210, 48),
		"reset": Rect2(px + 30, py + 250, 210, 48),
		"hint": Rect2(px + 30, py + 310, 210, 48),
		"map": Rect2(px + 30, py + 370, 210, 48),
		"rules": Rect2(px + 30, py + 430, 210, 48),
	}
	for k in buttons.keys():
		if buttons[k].has_point(pos):
			return str(k)
	return ""


func _draw_modal_dim() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.15, 0.18, 0.25, 0.55))


func _draw_modal_rules() -> void:
	_draw_modal_dim()
	var r := Rect2(260, 80, 760, 560)
	_round_rect(r, 24, Color(1, 0.99, 0.96))
	_draw_text(r.position + Vector2(40, 56), "怎麼玩？", 32, Color(0.3, 0.35, 0.5))
	var lines := [
		"1. 把彩色方塊滑到同顏色的門，讓它們逃脫！",
		"2. 一次拖曳同一塊算一步；碰到牆壁沒動就不計步。",
		"3. 灰色石頭是障礙，永遠不會離開。",
		"4. 有 ↔ / ↕ 標記的方塊只能橫向或直向移動。",
		"5. 結冰的方塊要先讓其他顏色逃脫才會解凍。",
		"6. 步數越少、時間越快，星星越多！",
		"7. 連續逃脫可獲得連擊加分。",
	]
	var y := 100.0
	for line in lines:
		_draw_text(r.position + Vector2(40, y), line, 20, Color(0.35, 0.4, 0.5))
		y += 42
	_draw_button(Rect2(r.position.x + 230, r.position.y + 470, 300, 56), "開始遊戲！", Color(0.45, 0.85, 0.55))


func _draw_modal_clear() -> void:
	_draw_modal_dim()
	var r := Rect2(320, 120, 640, 480)
	_round_rect(r, 24, Color(1, 0.98, 0.92))
	_draw_text(r.position + Vector2(200, 60), "過關啦！", 36, Color(0.85, 0.45, 0.2))
	var stars: int = int(clear_result.get("stars", 0))
	var star_str := ""
	for i in 3:
		star_str += "★" if i < stars else "☆"
	_draw_text(r.position + Vector2(220, 130), star_str, 48, Color(1.0, 0.75, 0.15))
	_draw_text(r.position + Vector2(180, 200), "分數 %d" % int(clear_result.get("total", 0)), 28, Color(0.3, 0.35, 0.5))
	_draw_text(r.position + Vector2(140, 250), "步數分 %d　時間分 %d　連擊 +%d" % [
		int(clear_result.get("moves", 0)),
		int(clear_result.get("time", 0)),
		int(clear_result.get("combo", 0)),
	], 18, Color(0.45, 0.5, 0.55))
	_draw_button(Rect2(r.position.x + 60, r.position.y + 340, 240, 56), "再玩一次", Color(0.95, 0.75, 0.45))
	_draw_button(Rect2(r.position.x + 340, r.position.y + 340, 240, 56), "下一關 ▶", Color(0.45, 0.85, 0.55))
	_draw_button(Rect2(r.position.x + 180, r.position.y + 410, 280, 48), "關卡地圖", Color(0.7, 0.8, 0.95))


func _draw_modal_fail() -> void:
	_draw_modal_dim()
	var r := Rect2(360, 180, 560, 320)
	_round_rect(r, 24, Color(1, 0.95, 0.95))
	_draw_text(r.position + Vector2(160, 70), "時間到了…", 32, Color(0.75, 0.3, 0.3))
	_draw_text(r.position + Vector2(120, 130), "超過三分鐘，再試一次吧！", 20, Color(0.45, 0.4, 0.4))
	_draw_button(Rect2(r.position.x + 130, r.position.y + 200, 300, 56), "重新挑戰", Color(0.95, 0.6, 0.5))


func _draw_modal_map() -> void:
	_draw_modal_dim()
	var r := Rect2(200, 80, 880, 560)
	_round_rect(r, 24, Color(0.98, 0.99, 1.0))
	_draw_text(r.position + Vector2(40, 50), "關卡地圖", 30, Color(0.3, 0.35, 0.5))
	for i in LevelData.level_count():
		var col_i := i % 4
		var row_i := i / 4
		var br := Rect2(r.position + Vector2(50 + col_i * 200, 100 + row_i * 180), Vector2(170, 140))
		var locked := (i + 1) > unlocked
		var bg := Color(0.85, 0.88, 0.95) if locked else Color(0.55, 0.85, 0.7)
		if i == level_index and not locked:
			bg = Color(0.95, 0.8, 0.45)
		_round_rect(br, 16, bg)
		var ld: Dictionary = LevelData.get_level(i)
		_draw_text(br.position + Vector2(20, 40), "第 %d 關" % (i + 1), 22, Color(0.2, 0.25, 0.35))
		_draw_text(br.position + Vector2(20, 70), str(ld.get("title", "")), 14, Color(0.3, 0.35, 0.45))
		if locked:
			_draw_text(br.position + Vector2(50, 110), "🔒", 28, Color(0.4, 0.4, 0.5))
		else:
			var st: int = int(best_stars[i]) if i < best_stars.size() else 0
			var ss := ""
			for s in 3:
				ss += "★" if s < st else "☆"
			_draw_text(br.position + Vector2(40, 110), ss, 22, Color(1, 0.75, 0.2))
	_draw_button(Rect2(r.position.x + 300, r.position.y + 480, 280, 52), "關閉", Color(0.75, 0.78, 0.85))


func _draw_toast() -> void:
	var r := Rect2(440, 660, 400, 40)
	_round_rect(r, 12, Color(0.2, 0.25, 0.35, 0.85))
	_draw_text(r.position + Vector2(24, 28), toast, 18, Color(1, 1, 1))


func _show_toast(msg: String) -> void:
	toast = msg
	toast_t = 2.0


func _input(event: InputEvent) -> void:
	if show_rules:
		var dismiss := false
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
				dismiss = true
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Whole modal + start button
			var modal := Rect2(260, 80, 760, 560)
			if modal.has_point(event.position):
				dismiss = true
		if dismiss:
			show_rules = false
			running = true
			queue_redraw()
		return
	if show_fail:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var r := Rect2(490, 380, 300, 56)
			if r.has_point(event.position):
				show_fail = false
				_start_level(level_index)
				running = true
		return
	if show_clear:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var base := Vector2(320, 120)
			if Rect2(base + Vector2(60, 340), Vector2(240, 56)).has_point(event.position):
				show_clear = false
				_start_level(level_index)
				running = true
			elif Rect2(base + Vector2(340, 340), Vector2(240, 56)).has_point(event.position):
				show_clear = false
				if level_index + 1 < LevelData.level_count():
					_start_level(level_index + 1)
				else:
					show_map = true
				running = not show_map
			elif Rect2(base + Vector2(180, 410), Vector2(280, 48)).has_point(event.position):
				show_clear = false
				show_map = true
				running = false
		return
	if show_map:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var r := Rect2(200, 80, 880, 560)
			if Rect2(r.position.x + 300, r.position.y + 480, 280, 52).has_point(event.position):
				show_map = false
				running = true
				return
			for i in LevelData.level_count():
				var col_i := i % 4
				var row_i := i / 4
				var br := Rect2(r.position + Vector2(50 + col_i * 200, 100 + row_i * 180), Vector2(170, 140))
				if br.has_point(event.position) and (i + 1) <= unlocked:
					show_map = false
					_start_level(i)
					running = true
					return
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z or event.physical_keycode == KEY_Z:
			_do_undo()
			return
		if event.keycode == KEY_H or event.physical_keycode == KEY_H:
			_do_hint()
			return
		if selected_id >= 0:
			var d := Vector2i.ZERO
			match event.keycode:
				KEY_LEFT, KEY_A:
					d = Vector2i(-1, 0)
				KEY_RIGHT, KEY_D:
					d = Vector2i(1, 0)
				KEY_UP, KEY_W:
					d = Vector2i(0, -1)
				KEY_DOWN, KEY_S:
					d = Vector2i(0, 1)
			if d != Vector2i.ZERO:
				_keyboard_move(d)
				return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var btn := _hit_button(event.position)
				if btn != "":
					_press_button(btn)
					return
				var cell := _cell_at(event.position)
				if cell.x >= 0:
					var id := model.block_at_cell(cell)
					if id >= 0:
						var blk: Dictionary = model.get_block(id)
						if not bool(blk.stone) and not bool(blk.get("frozen", false)):
							selected_id = id
							dragging = true
							drag_moved = false
							gesture_counted = false
							drag_start_mouse = event.position
							drag_start_cell = cell
							drag_origin_xy = Vector2i(int(blk.x), int(blk.y))
							model.push_history()
			else:
				if dragging:
					dragging = false
					# Try exit if flush against gate in last drag direction
					if selected_id >= 0 and drag_moved:
						_try_auto_exit(selected_id)
					if not drag_moved and not model.history.is_empty():
						# Bump without move — discard history snapshot
						model.history.pop_back()
				queue_redraw()

	if event is InputEventMouseMotion and dragging and selected_id >= 0:
		var delta: Vector2 = event.position - drag_start_mouse
		var dx := int(round(delta.x / float(CELL + GAP)))
		var dy := int(round(delta.y / float(CELL + GAP)))
		var blk: Dictionary = model.get_block(selected_id)
		if blk.is_empty():
			return
		var tx := drag_origin_xy.x + dx
		var ty := drag_origin_xy.y + dy
		# Clamp attempt by stepping from origin
		var want := Vector2i(tx - int(blk.x), ty - int(blk.y))
		if want != Vector2i.ZERO:
			if model.try_move(selected_id, want.x, want.y):
				if not gesture_counted:
					model.moves += 1
					gesture_counted = true
				drag_moved = true
				_try_auto_exit(selected_id)
		queue_redraw()


func _keyboard_move(d: Vector2i) -> void:
	if selected_id < 0:
		return
	model.push_history()
	var moved := model.try_move(selected_id, d.x, d.y)
	if moved:
		model.moves += 1
		_try_auto_exit(selected_id)
	else:
		# try exit in that direction without moving
		if model.try_exit(selected_id, d, elapsed):
			model.moves += 1
			_on_exit_visual(selected_id, d)
			selected_id = -1
			_check_clear()
		else:
			model.history.pop_back()
	queue_redraw()


func _try_auto_exit(id: int) -> void:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if model.can_exit(id, d).is_empty():
			continue
		# Need an extra "step" toward the gate — if player dragged toward it or presses that way
		# Auto-exit when flush: require last motion toward gate OR always when flush after move
		var blk: Dictionary = model.get_block(id)
		if blk.is_empty():
			return
		if model.try_exit(id, d, elapsed):
			_on_exit_visual(id, d)
			if selected_id == id:
				selected_id = -1
			dragging = false
			_check_clear()
			return


func _on_exit_visual(id: int, d: Vector2i) -> void:
	# Approximate last known position
	var pos := BOARD_ORIGIN + Vector2(3, 3) * (CELL + GAP)
	exit_anim[id] = {
		"pos": _board_rect().get_center(),
		"dir": Vector2(d),
		"color": Color(1, 0.9, 0.4),
		"t": 0.0,
	}
	_show_toast("逃脫成功！")


func _check_clear() -> void:
	if model.is_clear():
		running = false
		var gold: float = float(level_data.get("gold", 60))
		clear_result = BoardModel.compute_score(model.moves, int(level_data.get("par", 5)), elapsed, gold, model.combo_bonus)
		show_clear = true
		var stars: int = int(clear_result.stars)
		if level_index < best_stars.size():
			best_stars[level_index] = maxi(int(best_stars[level_index]), stars)
		if level_index + 1 >= unlocked and level_index + 1 < LevelData.level_count():
			unlocked = level_index + 2
		elif level_index + 1 == LevelData.level_count():
			unlocked = LevelData.level_count()
		_save_progress()


func _do_undo() -> void:
	if model.undo():
		selected_id = -1
		_show_toast("已復原")
	else:
		_show_toast("沒有可以復原的步驟")
	queue_redraw()


func _do_hint() -> void:
	hint_flash = model.hint()
	hint_timer = 2.5
	if hint_flash.is_empty():
		_show_toast("暫時沒有提示")
	else:
		selected_id = int(hint_flash.id)
		_show_toast("試試這塊方塊！")
	queue_redraw()


func _press_button(btn: String) -> void:
	match btn:
		"undo":
			_do_undo()
		"reset":
			_start_level(level_index)
			running = true
			_show_toast("關卡已重設")
		"hint":
			_do_hint()
		"map":
			show_map = true
			running = false
		"rules":
			show_rules = true
			running = false
	queue_redraw()
