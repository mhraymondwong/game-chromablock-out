extends Node2D
## 彩色方塊逃脫 — Color Block Escape main scene (portrait-only kids UI).

const GAP_RATIO := 0.07  # gap relative to cell
const MIN_TOUCH := 52.0  # modal / secondary touch targets
const BTN_SIZE := 80.0   # bottom toolbar icon diameter (72–88)
const GATE_PAD := 26.0
const BOTTOM_PAD := 36.0 # lift toolbar off screen bottom

var font: Font
var model: BoardModel
var level_index: int = 0
var level_data: Dictionary = {}
var unlocked: int = 1
var best_stars: Array = [0, 0, 0, 0, 0, 0, 0, 0]

var selected_id: int = -1
var dragging: bool = false
var drag_moved: bool = false
var drag_start_mouse: Vector2 = Vector2.ZERO
var drag_start_cell: Vector2i = Vector2i.ZERO
var drag_origin_xy: Vector2i = Vector2i.ZERO
var gesture_counted: bool = false
var active_touch_index: int = -1  # -1 = mouse / none
var last_pointer_ms: int = 0

var elapsed: float = 0.0
var running: bool = false
var show_rules: bool = true
var show_clear: bool = false
var show_map: bool = false
var show_fail: bool = false
var clear_result: Dictionary = {}
var hint_flash: Dictionary = {}
var hint_timer: float = 0.0
var exit_anim: Dictionary = {}
var toast: String = ""
var toast_t: float = 0.0

var bg_a := Color(0.93, 0.96, 1.0)
var bg_b := Color(0.98, 0.93, 0.96)

# --- Portrait layout (recomputed on resize; always portrait) ---
var vp: Vector2 = Vector2(390, 844)
var is_narrow: bool = true  # always portrait layout
var cell: float = 48.0
var gap: float = 4.0
var board_origin: Vector2 = Vector2(40, 220)
var hud_h: float = 200.0
var toolbar_h: float = 130.0
var title_rect: Rect2 = Rect2()
var badge_rects: Dictionary = {}  # id -> Rect2
var btn_rects: Dictionary = {}  # id -> Rect2
var help_lines_pos: Vector2 = Vector2(-1, -1)

# --- Kids UI art (procedural, assets/ui/) ---
var tex_bg: Texture2D
var tex_bg_portrait: Texture2D
var tex_title: Texture2D
var tex_title_sm: Texture2D
var tex_hud: Texture2D
var tex_toolbar: Texture2D
var tex_panel: Texture2D
var tex_star_on: Texture2D
var tex_star_off: Texture2D
var tex_btn: Dictionary = {}  # id -> Texture2D
var tex_btn_pressed: Dictionary = {}
var tex_gates: Dictionary = {}  # color name -> Texture2D
var tex_badge: Dictionary = {}  # level/time/moves/score -> Texture2D
var pressed_btn: String = ""
var press_flash_t: float = 0.0


func _load_ui_art() -> void:
	tex_bg = _tex("res://assets/ui/bg_playroom.png")
	tex_bg_portrait = _tex("res://assets/ui/bg_playroom_portrait.png")
	tex_title = _tex("res://assets/ui/title_banner.png")
	tex_title_sm = _tex("res://assets/ui/title_banner_sm.png")
	tex_hud = _tex("res://assets/ui/hud_bar.png")
	tex_toolbar = _tex("res://assets/ui/toolbar_bar.png")
	tex_panel = _tex("res://assets/ui/panel_frame.png")
	tex_star_on = _tex("res://assets/ui/star_on.png")
	tex_star_off = _tex("res://assets/ui/star_off.png")
	for id in ["undo", "reset", "hint", "map", "rules"]:
		tex_btn[id] = _tex("res://assets/ui/btn_%s.png" % id)
		tex_btn_pressed[id] = _tex("res://assets/ui/btn_%s_pressed.png" % id)
	for id in ["level", "time", "moves", "score"]:
		tex_badge[id] = _tex("res://assets/ui/badge_%s.png" % id)
	for c in ["red", "blue", "green", "yellow", "purple", "orange"]:
		tex_gates[c] = _tex("res://assets/ui/gate_%s.png" % c)


func _tex(path: String) -> Texture2D:
	# Prefer Image.load so art works before Godot writes .import files.
	var img := Image.new()
	var abs_path := ProjectSettings.globalize_path(path)
	if img.load(abs_path) == OK:
		var it := ImageTexture.create_from_image(img)
		return it
	var t: Texture2D = load(path) as Texture2D
	if t != null:
		return t
	push_warning("Missing UI tex: " + path + " @ " + abs_path)
	return null


func _ready() -> void:
	font = load("res://assets/fonts/NotoSansCJK-Regular.ttc")
	if font == null:
		font = ThemeDB.fallback_font
	_load_ui_art()
	model = BoardModel.new()
	_load_progress()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()
	_start_level(0)
	show_rules = true
	running = false


func _on_viewport_resized() -> void:
	vp = get_viewport_rect().size
	if vp.x < 1.0 or vp.y < 1.0:
		vp = Vector2(1280, 720)
	_recompute_layout()
	queue_redraw()


func _recompute_layout() -> void:
	# Portrait-only: always use board + bottom toolbar (even if window is wide).
	is_narrow = true
	var margin := 14.0
	var top_pad := 10.0

	# Big title banner (prominent in sky area)
	var banner: Texture2D = tex_title if tex_title != null else tex_title_sm
	var bw: float = vp.x - 12.0
	var bh: float = 110.0
	if banner != null:
		bh = bw * float(banner.get_height()) / float(banner.get_width())
		bh = clampf(bh, 100.0, 130.0)
	title_rect = Rect2((vp.x - bw) * 0.5, top_pad, bw, bh)

	# Colorful badge chips under title
	var badge_h: float = clampf(vp.x * 0.145, 50.0, 60.0)
	var badge_gap: float = 5.0
	var badge_pad: float = 8.0
	var badge_y: float = title_rect.position.y + title_rect.size.y + 4.0
	var ids_b := ["level", "time", "moves", "score"]
	var n_b := ids_b.size()
	var badge_w: float = (vp.x - badge_pad * 2.0 - badge_gap * float(n_b - 1)) / float(n_b)
	badge_w = maxf(badge_w, 70.0)
	badge_rects.clear()
	var bx: float = badge_pad
	for id in ids_b:
		badge_rects[id] = Rect2(bx, badge_y, badge_w, badge_h)
		bx += badge_w + badge_gap

	hud_h = badge_y + badge_h + 10.0

	# Bottom toolbar: large buttons (72–88), lifted from edge — fill width
	var n := 5
	var side_m: float = 8.0
	var gap_btn: float = 8.0
	# Compute largest icon that fits with comfortable gaps
	var icon: float = (vp.x - side_m * 2.0 - gap_btn * float(n - 1)) / float(n)
	icon = clampf(icon, 72.0, 88.0)
	# Recompute gap so buttons are evenly spaced across width
	gap_btn = maxf(4.0, (vp.x - side_m * 2.0 - icon * float(n)) / float(maxi(n - 1, 1)))
	toolbar_h = icon + BOTTOM_PAD + 24.0

	var avail_w: float = vp.x - margin * 2.0 - GATE_PAD * 2.0
	var avail_h: float = vp.y - hud_h - toolbar_h - margin * 2.0 - GATE_PAD * 2.0
	var board_px: float = minf(avail_w, avail_h)
	board_px = maxf(board_px, 160.0)
	cell = board_px / (BoardModel.SIZE + (BoardModel.SIZE - 1) * GAP_RATIO)
	gap = cell * GAP_RATIO
	var board_span: float = BoardModel.SIZE * (cell + gap) - gap
	# Sit board a bit above toolbar with modest gap (not floating mid-sky)
	var board_y: float = hud_h + margin + GATE_PAD + maxf(0.0, (avail_h - board_span) * 0.55)
	board_origin = Vector2((vp.x - board_span) * 0.5, board_y)
	_layout_bottom_toolbar(icon, gap_btn)
	help_lines_pos = Vector2(-1, -1)


func _layout_bottom_toolbar(icon: float = BTN_SIZE, gap_btn: float = 8.0) -> void:
	btn_rects.clear()
	var labels := ["undo", "reset", "hint", "map", "rules"]
	var n := labels.size()
	var total_w: float = n * icon + gap_btn * float(n - 1)
	var x: float = (vp.x - total_w) * 0.5
	# Lift buttons: bottom of icon sits BOTTOM_PAD above screen bottom
	var y: float = vp.y - BOTTOM_PAD - icon
	for id in labels:
		btn_rects[id] = Rect2(x, y, icon, icon)
		x += icon + gap_btn


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
	active_touch_index = -1
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
	if press_flash_t > 0.0:
		press_flash_t -= delta
		if press_flash_t <= 0.0:
			pressed_btn = ""
	var done: Array = []
	for k in exit_anim.keys():
		exit_anim[k].t += delta
		if exit_anim[k].t > 0.45:
			done.append(k)
	for k in done:
		exit_anim.erase(k)
	queue_redraw()


func _board_rect() -> Rect2:
	var s := BoardModel.SIZE * (cell + gap) - gap
	return Rect2(board_origin, Vector2(s, s))


func _cell_rect(cx: int, cy: int) -> Rect2:
	var p := board_origin + Vector2(cx * (cell + gap), cy * (cell + gap))
	return Rect2(p, Vector2(cell, cell))


func _cell_at(pos: Vector2) -> Vector2i:
	var local := pos - board_origin
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)
	var cx := int(local.x / (cell + gap))
	var cy := int(local.y / (cell + gap))
	if cx < 0 or cy < 0 or cx >= BoardModel.SIZE or cy >= BoardModel.SIZE:
		return Vector2i(-1, -1)
	return Vector2i(cx, cy)


func _draw() -> void:
	_draw_background()
	_draw_hud()
	_draw_board()
	_draw_gates()
	_draw_blocks()
	_draw_exit_anims()
	_draw_controls()

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


func _draw_background() -> void:
	# Full-bleed playroom background (portrait art preferred).
	var bg: Texture2D = tex_bg_portrait if tex_bg_portrait != null else tex_bg
	if bg != null:
		draw_texture_rect(bg, Rect2(Vector2.ZERO, vp), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, vp), bg_a)
		draw_circle(Vector2(vp.x * 0.14, vp.y * 0.16), minf(vp.x, vp.y) * 0.18, Color(1, 0.85, 0.9, 0.35))
		draw_circle(Vector2(vp.x * 0.86, vp.y * 0.84), minf(vp.x, vp.y) * 0.22, Color(0.75, 0.9, 1.0, 0.4))


func _draw_text(pos: Vector2, text: String, size: int, col: Color, outline: bool = false) -> void:
	if outline:
		draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.25))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_hud() -> void:
	# Soft fade only — keep playroom bg visible (no solid white bar).
	if tex_hud != null:
		draw_texture_rect(tex_hud, Rect2(0, 0, vp.x, hud_h), false)

	# Big cartoon title banner (prominent)
	var banner: Texture2D = tex_title if tex_title != null else tex_title_sm
	if banner != null and title_rect.size.x > 1.0:
		draw_texture_rect(banner, title_rect, false)
	else:
		_draw_text(Vector2(vp.x * 0.18, 48), "彩色方塊逃脫", 28, Color(1.0, 0.42, 0.28), true)

	# Colorful cute badge chips: level / time / moves / score
	var gold: float = float(level_data.get("gold", 60))
	var sc: Dictionary = BoardModel.compute_score(model.moves, int(level_data.get("par", 5)), elapsed, gold, model.combo_bonus)
	var mm := int(elapsed) / 60
	var ss := int(elapsed) % 60
	var time_ok: bool = elapsed <= gold
	var items := [
		{"id": "level", "label": "關卡", "value": "%d/%d" % [level_index + 1, LevelData.level_count()], "lab": Color(0.45, 0.1, 0.28), "fg": Color(0.35, 0.05, 0.2)},
		{"id": "time", "label": "時間", "value": "%02d:%02d" % [mm, ss], "lab": Color(0.05, 0.35, 0.28), "fg": Color(0.05, 0.32, 0.25) if time_ok else Color(0.7, 0.12, 0.08)},
		{"id": "moves", "label": "步數", "value": "%d/%d" % [model.moves, int(level_data.get("par", 5))], "lab": Color(0.45, 0.22, 0.02), "fg": Color(0.4, 0.18, 0.0)},
		{"id": "score", "label": "分數", "value": "%d" % int(sc.total), "lab": Color(0.4, 0.28, 0.0), "fg": Color(0.35, 0.22, 0.0)},
	]
	for it in items:
		var id: String = str(it.id)
		if not badge_rects.has(id):
			continue
		var r: Rect2 = badge_rects[id]
		var tex: Texture2D = tex_badge.get(id) as Texture2D
		if tex != null:
			draw_texture_rect(tex, r, false)
		else:
			var fallback := {
				"level": Color(1.0, 0.55, 0.67),
				"time": Color(0.35, 0.78, 0.67),
				"moves": Color(1.0, 0.67, 0.35),
				"score": Color(1.0, 0.82, 0.28),
			}
			_round_rect(r, 14, fallback.get(id, Color(0.9, 0.9, 0.95)))
			draw_rect(r, Color(1, 1, 1, 0.55), false, 2.0)
		var lab: String = str(it.label)
		var val: String = str(it.value)
		var lab_col: Color = it.lab
		var fg: Color = it.fg
		var fs_lab := int(clampf(r.size.y * 0.30, 11.0, 14.0))
		var fs_val := int(clampf(r.size.y * 0.48, 16.0, 22.0))
		var lab_sz := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_lab)
		var val_sz := font.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_val)
		_draw_text(Vector2(r.position.x + (r.size.x - lab_sz.x) * 0.5, r.position.y + r.size.y * 0.36), lab, fs_lab, lab_col, true)
		_draw_text(Vector2(r.position.x + (r.size.x - val_sz.x) * 0.5, r.position.y + r.size.y * 0.82), val, fs_val, fg, true)
	if model.combo_bonus > 0:
		_draw_text(Vector2(vp.x - 90, hud_h - 4), "連擊 +%d" % model.combo_bonus, 13, Color(0.95, 0.4, 0.15), true)


func _draw_board() -> void:
	var br := _board_rect()
	draw_rect(Rect2(br.position + Vector2(6, 8), br.size), Color(0.4, 0.45, 0.55, 0.18), true, -1.0)
	var frame_pad := maxf(10.0, cell * 0.12)
	draw_rect(Rect2(br.position - Vector2(frame_pad, frame_pad), br.size + Vector2(frame_pad * 2, frame_pad * 2)), Color(0.98, 0.97, 0.94), true, -1.0)
	draw_rect(Rect2(br.position - Vector2(frame_pad, frame_pad), br.size + Vector2(frame_pad * 2, frame_pad * 2)), Color(0.75, 0.7, 0.65), false, 3.0)
	var rad := maxf(8.0, cell * 0.16)
	for y in BoardModel.SIZE:
		for x in BoardModel.SIZE:
			var r := _cell_rect(x, y)
			var c := Color(0.88, 0.90, 0.93) if (x + y) % 2 == 0 else Color(0.84, 0.87, 0.91)
			_round_rect(r, rad, c)


func _round_rect(r: Rect2, rad: float, col: Color) -> void:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.45)
	draw_rect(Rect2(r.position + Vector2(rad, 0), r.size - Vector2(rad * 2, 0)), col)
	draw_rect(Rect2(r.position + Vector2(0, rad), Vector2(r.size.x, r.size.y - rad * 2)), col)
	draw_circle(r.position + Vector2(rad, rad), rad, col)
	draw_circle(r.position + Vector2(r.size.x - rad, rad), rad, col)
	draw_circle(r.position + Vector2(rad, r.size.y - rad), rad, col)
	draw_circle(r.position + Vector2(r.size.x - rad, r.size.y - rad), rad, col)


func _draw_gates() -> void:
	var door_w := maxf(14.0, cell * 0.22)
	for g in model.gates:
		var cname: String = str(g.color)
		var col: Color = LevelData.COLORS.get(cname, Color.WHITE)
		var start: int = int(g.start)
		var size: int = int(g.size)
		match str(g.side):
			"right":
				for i in size:
					var r := _cell_rect(BoardModel.SIZE - 1, start + i)
					var door := Rect2(r.position.x + r.size.x + 3, r.position.y + cell * 0.1, door_w, r.size.y - cell * 0.2)
					_round_rect(door, 6, col)
					draw_rect(door, Color(1, 1, 1, 0.45), false, 2.0)
					# glossy highlight on door
					_round_rect(Rect2(door.position + Vector2(2, 3), Vector2(door.size.x * 0.35, door.size.y - 6)), 4, Color(1, 1, 1, 0.35))
			"left":
				for i in size:
					var r2 := _cell_rect(0, start + i)
					var door2 := Rect2(r2.position.x - door_w - 3, r2.position.y + cell * 0.1, door_w, r2.size.y - cell * 0.2)
					_round_rect(door2, 6, col)
					draw_rect(door2, Color(1, 1, 1, 0.45), false, 2.0)
					_round_rect(Rect2(door2.position + Vector2(door2.size.x * 0.55, 3), Vector2(door2.size.x * 0.35, door2.size.y - 6)), 4, Color(1, 1, 1, 0.35))
			"bottom":
				for i in size:
					var r3 := _cell_rect(start + i, BoardModel.SIZE - 1)
					var door3 := Rect2(r3.position.x + cell * 0.1, r3.position.y + r3.size.y + 3, r3.size.x - cell * 0.2, door_w)
					_round_rect(door3, 6, col)
					draw_rect(door3, Color(1, 1, 1, 0.45), false, 2.0)
					_round_rect(Rect2(door3.position + Vector2(3, 2), Vector2(door3.size.x - 6, door3.size.y * 0.4)), 4, Color(1, 1, 1, 0.35))
			"top":
				for i in size:
					var r4 := _cell_rect(start + i, 0)
					var door4 := Rect2(r4.position.x + cell * 0.1, r4.position.y - door_w - 3, r4.size.x - cell * 0.2, door_w)
					_round_rect(door4, 6, col)
					draw_rect(door4, Color(1, 1, 1, 0.45), false, 2.0)
					_round_rect(Rect2(door4.position + Vector2(3, door4.size.y * 0.45), Vector2(door4.size.x - 6, door4.size.y * 0.4)), 4, Color(1, 1, 1, 0.35))


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
	var rad := maxf(8.0, cell * 0.16)
	for c in b.cells:
		var r: Rect2 = _cell_rect(c.x, c.y).grow(-1)
		_round_rect(Rect2(r.position + Vector2(3, 4), r.size), rad, Color(0, 0, 0, 0.10 * alpha))
		_round_rect(r, rad, base)
	var bounds: Rect2 = _block_bounds(b).grow(1)
	draw_rect(bounds, Color(1, 1, 1, 0.22 * alpha), false, 2.0)
	_round_rect(Rect2(bounds.position + Vector2(10, 8), Vector2(bounds.size.x - 20, mini(22.0, bounds.size.y * 0.22))), 10, Color(1, 1, 1, 0.25 * alpha))
	if frozen:
		_round_rect(bounds, 12, Color(0.7, 0.9, 1.0, 0.4 * alpha))
		_draw_text(bounds.get_center() + Vector2(-14, 10), "❄", int(maxi(22, int(cell * 0.35))), Color(1, 1, 1, 0.95 * alpha))
	elif not stone:
		_draw_face(bounds.get_center(), mini(bounds.size.x, bounds.size.y) * 0.18, alpha)
	var axis: String = str(b.get("axis", ""))
	if axis != "":
		var icon := "↔" if axis == "h" else "↕"
		_draw_text(bounds.position + Vector2(8, 24), icon, 20, Color(1, 1, 1, 0.95 * alpha))
	if int(b.id) == selected_id:
		draw_rect(bounds.grow(5), Color(1, 1, 1, 0.9), false, 3.0)


func _draw_face(center: Vector2, s: float, alpha: float) -> void:
	var eye := Color(0.2, 0.2, 0.28, alpha)
	draw_circle(center + Vector2(-s * 0.45, -s * 0.25), s * 0.18, eye)
	draw_circle(center + Vector2(s * 0.45, -s * 0.25), s * 0.18, eye)
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


func _draw_controls() -> void:
	# Soft pill tray behind large bottom buttons (bg still shows through edges).
	var tray_top: float = vp.y - toolbar_h
	if tex_toolbar != null:
		draw_texture_rect(tex_toolbar, Rect2(0, tray_top, vp.x, toolbar_h), false)
	else:
		_round_rect(Rect2(12, tray_top + 8, vp.x - 24, toolbar_h - 16), 28, Color(1, 0.98, 0.96, 0.72))
	for id in btn_rects.keys():
		_draw_icon_button(str(id), btn_rects[id])


func _draw_icon_button(id: String, r: Rect2) -> void:
	var use_pressed: bool = (pressed_btn == id and press_flash_t > 0.0)
	var tex: Texture2D = null
	if use_pressed and tex_btn_pressed.has(id):
		tex = tex_btn_pressed[id]
	elif tex_btn.has(id):
		tex = tex_btn[id]
	if tex != null:
		# Keep ≥48px touch area; draw icon filling the rect
		draw_texture_rect(tex, r, false)
	else:
		var cols := {
			"undo": Color(0.55, 0.7, 0.95),
			"reset": Color(0.95, 0.7, 0.55),
			"hint": Color(0.95, 0.85, 0.4),
			"map": Color(0.7, 0.85, 0.6),
			"rules": Color(0.8, 0.75, 0.9),
		}
		_draw_button(r, id, cols.get(id, Color(0.8, 0.8, 0.85)), true)


func _side_panel_rect() -> Rect2:
	if btn_rects.is_empty():
		return Rect2()
	var min_x := 1e9
	var min_y := 1e9
	var max_x := 0.0
	var max_y := 0.0
	for r in btn_rects.values():
		min_x = minf(min_x, r.position.x)
		min_y = minf(min_y, r.position.y)
		max_x = maxf(max_x, r.position.x + r.size.x)
		max_y = maxf(max_y, r.position.y + r.size.y)
	var left: float = min_x - 24.0
	var top: float = hud_h + 12.0
	var w: float = (max_x - min_x) + 48.0
	var h: float = max_y - top + 48.0
	return Rect2(left, top, w, maxf(h, 240.0))


func _draw_button(r: Rect2, label: String, col: Color, compact: bool = false) -> void:
	_round_rect(Rect2(r.position + Vector2(2, 3), r.size), 12, Color(0, 0, 0, 0.12))
	_round_rect(r, 12, col)
	_round_rect(Rect2(r.position + Vector2(6, 4), Vector2(r.size.x - 12, mini(14.0, r.size.y * 0.28))), 8, Color(1, 1, 1, 0.25))
	var fs := 22 if compact else 20
	if compact:
		# Center emoji / short label
		var approx_w := label.length() * fs * 0.55
		_draw_text(r.position + Vector2((r.size.x - approx_w) * 0.5, r.size.y * 0.68), label, fs, Color(0.2, 0.22, 0.3))
	else:
		_draw_text(r.position + Vector2(20, r.size.y * 0.65), label, fs, Color(0.2, 0.22, 0.3))


func _hit_button(pos: Vector2) -> String:
	for k in btn_rects.keys():
		if btn_rects[k].has_point(pos):
			return str(k)
	return ""


func _modal_rect(frac_w: float = 0.72, frac_h: float = 0.78) -> Rect2:
	var w: float = clampf(vp.x * frac_w, 280.0, 880.0)
	var h: float = clampf(vp.y * frac_h, 320.0, 600.0)
	if is_narrow:
		w = vp.x - 24.0
		h = minf(vp.y - 40.0, h)
	return Rect2((vp.x - w) * 0.5, (vp.y - h) * 0.5, w, h)


func _draw_modal_dim() -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.15, 0.18, 0.25, 0.55))


func _draw_modal_rules() -> void:
	_draw_modal_dim()
	var r := _modal_rect(0.7, 0.82)
	_round_rect(r, 24, Color(1, 0.99, 0.96))
	_draw_text(r.position + Vector2(28, 44), "怎麼玩？", 28 if is_narrow else 32, Color(0.3, 0.35, 0.5))
	var lines := [
		"1. 把彩色方塊滑到同顏色的門，讓它們逃脫！",
		"2. 一次拖曳同一塊算一步；沒動就不計步。",
		"3. 灰色石頭是障礙，永遠不會離開。",
		"4. 有 ↔ / ↕ 標記的方塊只能橫／直移動。",
		"5. 結冰方塊要先讓其他顏色逃脫才解凍。",
		"6. 步數越少、時間越快，星星越多！",
		"7. 連續逃脫可獲得連擊加分。",
	]
	var fs := 15 if is_narrow else 20
	var y := 78.0 if is_narrow else 100.0
	var step := 28.0 if is_narrow else 42.0
	for line in lines:
		_draw_text(r.position + Vector2(24, y), line, fs, Color(0.35, 0.4, 0.5))
		y += step
	var bw := minf(300.0, r.size.x - 48.0)
	var bh := maxf(MIN_TOUCH, 52.0)
	_draw_button(Rect2(r.position.x + (r.size.x - bw) * 0.5, r.position.y + r.size.y - bh - 24, bw, bh), "開始遊戲！", Color(0.45, 0.85, 0.55))


func _rules_start_rect() -> Rect2:
	var r := _modal_rect(0.7, 0.82)
	var bw := minf(300.0, r.size.x - 48.0)
	var bh := maxf(MIN_TOUCH, 52.0)
	return Rect2(r.position.x + (r.size.x - bw) * 0.5, r.position.y + r.size.y - bh - 24, bw, bh)



func _draw_stars_row(center: Vector2, stars: int, star_size: float = 40.0) -> void:
	var gap := star_size * 0.15
	var total := 3.0 * star_size + 2.0 * gap
	var x := center.x - total * 0.5
	for i in 3:
		var tex: Texture2D = tex_star_on if i < stars and tex_star_on != null else tex_star_off
		var r := Rect2(x, center.y - star_size * 0.5, star_size, star_size)
		if tex != null:
			draw_texture_rect(tex, r, false)
		else:
			_draw_text(r.position + Vector2(4, star_size * 0.75), "★" if i < stars else "☆", int(star_size * 0.7), Color(1, 0.75, 0.2) if i < stars else Color(0.7, 0.7, 0.75))
		x += star_size + gap


func _draw_modal_clear() -> void:
	_draw_modal_dim()
	var r := _modal_rect(0.62, 0.7)
	_round_rect(r, 24, Color(1, 0.98, 0.92))
	_draw_text(r.position + Vector2(r.size.x * 0.28, 50), "過關啦！", 32, Color(0.85, 0.45, 0.2))
	var stars: int = int(clear_result.get("stars", 0))
	_draw_stars_row(r.position + Vector2(r.size.x * 0.5, 110), stars, 44.0 if not is_narrow else 36.0)
	_draw_text(r.position + Vector2(r.size.x * 0.28, 170), "分數 %d" % int(clear_result.get("total", 0)), 24, Color(0.3, 0.35, 0.5))
	_draw_text(r.position + Vector2(24, 210), "步數分 %d　時間分 %d　連擊 +%d" % [
		int(clear_result.get("moves", 0)),
		int(clear_result.get("time", 0)),
		int(clear_result.get("combo", 0)),
	], 15 if is_narrow else 18, Color(0.45, 0.5, 0.55))
	var bh := maxf(MIN_TOUCH, 52.0)
	var gapb := 12.0
	var row_y := r.position.y + r.size.y - bh * 2 - gapb - 28
	var half := (r.size.x - 48 - gapb) * 0.5
	_draw_button(Rect2(r.position.x + 24, row_y, half, bh), "再玩一次", Color(0.95, 0.75, 0.45))
	_draw_button(Rect2(r.position.x + 24 + half + gapb, row_y, half, bh), "下一關 ▶", Color(0.45, 0.85, 0.55))
	var mw := minf(280.0, r.size.x - 48)
	_draw_button(Rect2(r.position.x + (r.size.x - mw) * 0.5, row_y + bh + gapb, mw, bh), "關卡地圖", Color(0.7, 0.8, 0.95))


func _clear_buttons() -> Dictionary:
	var r := _modal_rect(0.62, 0.7)
	var bh := maxf(MIN_TOUCH, 52.0)
	var gapb := 12.0
	var row_y := r.position.y + r.size.y - bh * 2 - gapb - 28
	var half := (r.size.x - 48 - gapb) * 0.5
	var mw := minf(280.0, r.size.x - 48)
	return {
		"replay": Rect2(r.position.x + 24, row_y, half, bh),
		"next": Rect2(r.position.x + 24 + half + gapb, row_y, half, bh),
		"map": Rect2(r.position.x + (r.size.x - mw) * 0.5, row_y + bh + gapb, mw, bh),
	}


func _draw_modal_fail() -> void:
	_draw_modal_dim()
	var r := _modal_rect(0.55, 0.42)
	_round_rect(r, 24, Color(1, 0.95, 0.95))
	_draw_text(r.position + Vector2(r.size.x * 0.22, 56), "時間到了…", 28, Color(0.75, 0.3, 0.3))
	_draw_text(r.position + Vector2(28, 110), "超過三分鐘，再試一次吧！", 18, Color(0.45, 0.4, 0.4))
	var bw := minf(300.0, r.size.x - 48)
	var bh := maxf(MIN_TOUCH, 52.0)
	_draw_button(Rect2(r.position.x + (r.size.x - bw) * 0.5, r.position.y + r.size.y - bh - 28, bw, bh), "重新挑戰", Color(0.95, 0.6, 0.5))


func _fail_retry_rect() -> Rect2:
	var r := _modal_rect(0.55, 0.42)
	var bw := minf(300.0, r.size.x - 48)
	var bh := maxf(MIN_TOUCH, 52.0)
	return Rect2(r.position.x + (r.size.x - bw) * 0.5, r.position.y + r.size.y - bh - 28, bw, bh)


func _draw_modal_map() -> void:
	_draw_modal_dim()
	var r := _modal_rect(0.85, 0.85)
	_round_rect(r, 24, Color(0.98, 0.99, 1.0))
	_draw_text(r.position + Vector2(28, 40), "關卡地圖", 26 if is_narrow else 30, Color(0.3, 0.35, 0.5))
	var cols := 2 if is_narrow else 4
	var rows := int(ceil(float(LevelData.level_count()) / float(cols)))
	var pad := 12.0 if is_narrow else 20.0
	var close_h := maxf(MIN_TOUCH, 48.0)
	var grid_top := 70.0
	var grid_h := r.size.y - grid_top - close_h - 36.0
	var cell_w := (r.size.x - pad * (cols + 1)) / float(cols)
	var cell_h := (grid_h - pad * (rows - 1)) / float(rows)
	cell_h = minf(cell_h, 150.0)
	for i in LevelData.level_count():
		var col_i := i % cols
		var row_i := i / cols
		var br := Rect2(
			r.position + Vector2(pad + col_i * (cell_w + pad), grid_top + row_i * (cell_h + pad)),
			Vector2(cell_w, cell_h)
		)
		var locked := (i + 1) > unlocked
		var bg := Color(0.85, 0.88, 0.95) if locked else Color(0.55, 0.85, 0.7)
		if i == level_index and not locked:
			bg = Color(0.95, 0.8, 0.45)
		_round_rect(br, 14, bg)
		var ld: Dictionary = LevelData.get_level(i)
		_draw_text(br.position + Vector2(12, 32), "第 %d 關" % (i + 1), 18 if is_narrow else 22, Color(0.2, 0.25, 0.35))
		_draw_text(br.position + Vector2(12, 56), str(ld.get("title", "")), 12 if is_narrow else 14, Color(0.3, 0.35, 0.45))
		if locked:
			_draw_text(br.position + Vector2(br.size.x * 0.4, br.size.y - 36), "🔒", 24, Color(0.4, 0.4, 0.5))
		else:
			var st: int = int(best_stars[i]) if i < best_stars.size() else 0
			_draw_stars_row(br.position + Vector2(br.size.x * 0.5, br.size.y - 28), st, minf(28.0, br.size.x * 0.22))
	var cw := minf(280.0, r.size.x - 48)
	_draw_button(Rect2(r.position.x + (r.size.x - cw) * 0.5, r.position.y + r.size.y - close_h - 16, cw, close_h), "關閉", Color(0.75, 0.78, 0.85))


func _map_layout() -> Dictionary:
	var r := _modal_rect(0.85, 0.85)
	var cols := 2 if is_narrow else 4
	var rows := int(ceil(float(LevelData.level_count()) / float(cols)))
	var pad := 12.0 if is_narrow else 20.0
	var close_h := maxf(MIN_TOUCH, 48.0)
	var grid_top := 70.0
	var grid_h := r.size.y - grid_top - close_h - 36.0
	var cell_w := (r.size.x - pad * (cols + 1)) / float(cols)
	var cell_h := (grid_h - pad * (rows - 1)) / float(rows)
	cell_h = minf(cell_h, 150.0)
	var tiles: Array = []
	for i in LevelData.level_count():
		var col_i := i % cols
		var row_i := i / cols
		tiles.append(Rect2(
			r.position + Vector2(pad + col_i * (cell_w + pad), grid_top + row_i * (cell_h + pad)),
			Vector2(cell_w, cell_h)
		))
	var cw := minf(280.0, r.size.x - 48)
	return {
		"close": Rect2(r.position.x + (r.size.x - cw) * 0.5, r.position.y + r.size.y - close_h - 16, cw, close_h),
		"tiles": tiles,
	}


func _draw_toast() -> void:
	var tw := minf(400.0, vp.x - 40.0)
	var y := vp.y - toolbar_h - 52.0 if is_narrow else vp.y - 56.0
	var r := Rect2((vp.x - tw) * 0.5, y, tw, 40)
	_round_rect(r, 12, Color(0.2, 0.25, 0.35, 0.85))
	_draw_text(r.position + Vector2(24, 28), toast, 16 if is_narrow else 18, Color(1, 1, 1))


func _show_toast(msg: String) -> void:
	toast = msg
	toast_t = 2.0


func _input(event: InputEvent) -> void:
	# Keyboard always
	if event is InputEventKey and event.pressed and not event.echo:
		if show_rules:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
				show_rules = false
				running = true
				queue_redraw()
			return
		if show_fail or show_clear or show_map:
			return
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

	# Unified pointer: ScreenTouch/Drag + Mouse (deduped within 30ms)
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if active_touch_index < 0 or active_touch_index == st.index:
				active_touch_index = st.index
				last_pointer_ms = Time.get_ticks_msec()
				_pointer_down(st.position)
		else:
			if active_touch_index == st.index or active_touch_index < 0:
				last_pointer_ms = Time.get_ticks_msec()
				_pointer_up(st.position)
				active_touch_index = -1
		return

	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if active_touch_index < 0 or active_touch_index == sd.index:
			_pointer_drag(sd.position)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Skip duplicate when touch (or touch-emulation) already handled this
		if Time.get_ticks_msec() - last_pointer_ms < 50:
			return
		if event.pressed:
			last_pointer_ms = Time.get_ticks_msec()
			_pointer_down(event.position)
		else:
			last_pointer_ms = Time.get_ticks_msec()
			_pointer_up(event.position)
		return

	if event is InputEventMouseMotion and dragging:
		if Time.get_ticks_msec() - last_pointer_ms < 50 and active_touch_index >= 0:
			return
		_pointer_drag(event.position)



func _pointer_down(pos: Vector2) -> void:
	if show_rules:
		var modal := _modal_rect(0.7, 0.82)
		if modal.has_point(pos) or _rules_start_rect().has_point(pos):
			show_rules = false
			running = true
			queue_redraw()
		return
	if show_fail:
		if _fail_retry_rect().has_point(pos):
			show_fail = false
			_start_level(level_index)
			running = true
		return
	if show_clear:
		var btns := _clear_buttons()
		if btns.replay.has_point(pos):
			show_clear = false
			_start_level(level_index)
			running = true
		elif btns.next.has_point(pos):
			show_clear = false
			if level_index + 1 < LevelData.level_count():
				_start_level(level_index + 1)
			else:
				show_map = true
			running = not show_map
		elif btns.map.has_point(pos):
			show_clear = false
			show_map = true
			running = false
		return
	if show_map:
		var ml := _map_layout()
		if ml.close.has_point(pos):
			show_map = false
			running = true
			return
		var tiles: Array = ml.tiles
		for i in tiles.size():
			if tiles[i].has_point(pos) and (i + 1) <= unlocked:
				show_map = false
				_start_level(i)
				running = true
				return
		return

	var btn := _hit_button(pos)
	if btn != "":
		_press_button(btn)
		return
	var cell_pos := _cell_at(pos)
	if cell_pos.x >= 0:
		var id := model.block_at_cell(cell_pos)
		if id >= 0:
			var blk: Dictionary = model.get_block(id)
			if not bool(blk.stone) and not bool(blk.get("frozen", false)):
				selected_id = id
				dragging = true
				drag_moved = false
				gesture_counted = false
				drag_start_mouse = pos
				drag_start_cell = cell_pos
				drag_origin_xy = Vector2i(int(blk.x), int(blk.y))
				model.push_history()
				queue_redraw()


func _pointer_up(_pos: Vector2) -> void:
	if dragging:
		dragging = false
		if selected_id >= 0 and drag_moved:
			_try_auto_exit(selected_id)
		if not drag_moved and not model.history.is_empty():
			model.history.pop_back()
		queue_redraw()


func _pointer_drag(pos: Vector2) -> void:
	if not dragging or selected_id < 0:
		return
	var delta: Vector2 = pos - drag_start_mouse
	var step: float = cell + gap
	var dx := int(round(delta.x / step))
	var dy := int(round(delta.y / step))
	var blk: Dictionary = model.get_block(selected_id)
	if blk.is_empty():
		return
	var tx := drag_origin_xy.x + dx
	var ty := drag_origin_xy.y + dy
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
	pressed_btn = btn
	press_flash_t = 0.18
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
