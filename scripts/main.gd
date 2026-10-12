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
var last_move_block_id: int = -1  # consecutive nudges of same block = 1 step
var level_tip: String = ""
var level_tip_t: float = 0.0
var taught_features: Dictionary = {"stone": false, "axis": false, "ice": false}
var active_touch_index: int = -1  # -1 = mouse / none
var last_pointer_ms: int = 0

var elapsed: float = 0.0
var running: bool = false
var show_start: bool = true
var show_rules: bool = false
var show_clear: bool = false
var show_map: bool = false
var show_fail: bool = false
var clear_result: Dictionary = {}
var hint_flash: Dictionary = {}
var hint_timer: float = 0.0
var exit_anim: Dictionary = {}
var toast: String = ""
var toast_t: float = 0.0
var skip_rules_howto: bool = false  # persisted: skip How-to on PLAY
var rules_from_button: bool = false  # opened via Rules toolbar (not start)

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
var tex_start: Texture2D
var tex_logo: Texture2D
var tex_title: Texture2D
var tex_title_sm: Texture2D
var play_hit_rect: Rect2 = Rect2()
var tex_hud: Texture2D
var tex_toolbar: Texture2D
var tex_panel: Texture2D
var tex_star_on: Texture2D
var tex_star_off: Texture2D
var tex_btn: Dictionary = {}  # id -> Texture2D
var tex_btn_pressed: Dictionary = {}
var tex_gates: Dictionary = {}  # color name -> Texture2D
var tex_badge: Dictionary = {}  # level/time/moves/score -> Texture2D
var tex_modal_rules: Texture2D
var tex_modal_clear: Texture2D
var tex_check_on: Texture2D
var tex_check_off: Texture2D
var tex_fun_orange: Texture2D
var tex_fun_green: Texture2D
var tex_fun_blue: Texture2D
var pressed_btn: String = ""
var press_flash_t: float = 0.0


func _load_ui_art() -> void:
	tex_bg = _tex("res://assets/ui/bg_playroom.png")
	tex_bg_portrait = _tex("res://assets/ui/bg_playroom_portrait.png")
	tex_start = _tex("res://assets/ui/start_page.png")
	tex_logo = _tex("res://assets/ui/logo.png")
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
	tex_modal_rules = _tex("res://assets/ui/modal_rules.png")
	tex_modal_clear = _tex("res://assets/ui/modal_clear.png")
	tex_check_on = _tex("res://assets/ui/checkbox_on.png")
	tex_check_off = _tex("res://assets/ui/checkbox_off.png")
	tex_fun_orange = _tex("res://assets/ui/btn_fun_orange.png")
	tex_fun_green = _tex("res://assets/ui/btn_fun_green.png")
	tex_fun_blue = _tex("res://assets/ui/btn_fun_blue.png")


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
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	font = load("res://assets/fonts/NotoSansCJK-Regular.ttc")
	if font == null:
		font = ThemeDB.fallback_font
	_load_ui_art()
	model = BoardModel.new()
	_load_progress()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()
	_start_level(0)
	show_start = true
	show_rules = false
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
	var top_pad := 2.0
	# Home-indicator / Safari chrome safe inset (logical px).
	var bottom_safe: float = maxf(12.0, vp.y * 0.02) + 30.0

	# Raymond bubble logo — shrink on short viewports so PLAY stays on-screen
	var banner: Texture2D = tex_logo if tex_logo != null else (tex_title if tex_title != null else tex_title_sm)
	var max_w: float = vp.x - 4.0
	# Soft caps: tall phones ~0.32; short browser chrome viewports down to ~0.22
	var max_h: float = clampf(vp.y * 0.30, 110.0, 300.0)
	if vp.y < 700.0:
		max_h = minf(max_h, vp.y * 0.24)
	var bw: float = max_w
	var bh: float = 200.0
	if banner != null:
		var aspect: float = float(banner.get_width()) / float(maxi(1, banner.get_height()))
		bw = max_w
		bh = bw / aspect
		if bh > max_h:
			bh = max_h
			bw = bh * aspect
	title_rect = Rect2((vp.x - bw) * 0.5, top_pad, bw, bh)
	# PLAY hit zone: above bottom safe area (not a fixed 0.84 that can miss short phones)
	var pw: float = vp.x * 0.62
	var ph: float = clampf(vp.y * 0.09, 64.0, 96.0)
	var play_y: float = vp.y - bottom_safe - ph
	play_hit_rect = Rect2((vp.x - pw) * 0.5, play_y, pw, ph)

	# Colorful badge chips under title
	var badge_h: float = clampf(vp.x * 0.145, 50.0, 60.0)
	var badge_gap: float = 5.0
	var badge_pad: float = 8.0
	var badge_y: float = title_rect.position.y + title_rect.size.y + 8.0
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
	var lift_tb: float = maxf(BOTTOM_PAD, maxf(12.0, vp.y * 0.02) + 24.0)
	toolbar_h = icon + lift_tb + 16.0

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
	# Lift above home indicator / browser chrome
	var lift: float = maxf(BOTTOM_PAD, maxf(12.0, vp.y * 0.02) + 24.0)
	var y: float = vp.y - lift - icon
	for id in labels:
		btn_rects[id] = Rect2(x, y, icon, icon)
		x += icon + gap_btn


func _load_progress() -> void:
	if FileAccess.file_exists("user://cbe_progress.cfg"):
		var cfg := ConfigFile.new()
		if cfg.load("user://cbe_progress.cfg") == OK:
			unlocked = int(cfg.get_value("p", "unlocked", 1))
			best_stars = cfg.get_value("p", "stars", best_stars)
			skip_rules_howto = bool(cfg.get_value("p", "skip_rules", false))
			taught_features = {
				"stone": bool(cfg.get_value("p", "taught_stone", false)),
				"axis": bool(cfg.get_value("p", "taught_axis", false)),
				"ice": bool(cfg.get_value("p", "taught_ice", false)),
			}


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("p", "unlocked", unlocked)
	cfg.set_value("p", "stars", best_stars)
	cfg.set_value("p", "skip_rules", skip_rules_howto)
	cfg.set_value("p", "taught_stone", bool(taught_features.get("stone", false)))
	cfg.set_value("p", "taught_axis", bool(taught_features.get("axis", false)))
	cfg.set_value("p", "taught_ice", bool(taught_features.get("ice", false)))
	cfg.save("user://cbe_progress.cfg")


func _start_level(idx: int) -> void:
	level_index = clampi(idx, 0, LevelData.level_count() - 1)
	level_data = LevelData.get_level(level_index)
	model.load_level(level_data)
	selected_id = -1
	dragging = false
	active_touch_index = -1
	last_move_block_id = -1
	elapsed = 0.0
	running = not show_start and not show_rules and not show_map
	show_clear = false
	show_fail = false
	clear_result = {}
	hint_flash = {}
	exit_anim.clear()
	_maybe_teach_features()
	queue_redraw()


func _level_has_feature(feat: String) -> bool:
	for b in level_data.get("blocks", []):
		var shape: String = str(b.get("shape", ""))
		if feat == "stone" and LevelData.is_stone(shape):
			return true
		if feat == "axis" and str(b.get("axis", "")) != "":
			return true
		if feat == "ice" and int(b.get("ice", 0)) > 0:
			return true
	return false


func _maybe_teach_features() -> void:
	## First time a mechanic appears: short tip (not a wall of rules).
	level_tip = ""
	level_tip_t = 0.0
	if _level_has_feature("stone") and not bool(taught_features.get("stone", false)):
		level_tip = "灰色石頭擋路，推不走喔"
		taught_features["stone"] = true
		level_tip_t = 4.5
		_save_progress()
	elif _level_has_feature("axis") and not bool(taught_features.get("axis", false)):
		level_tip = "有 ↔ / ↕ 的方塊只能橫或直走"
		taught_features["axis"] = true
		level_tip_t = 4.5
		_save_progress()
	elif _level_has_feature("ice") and not bool(taught_features.get("ice", false)):
		level_tip = "結冰方塊要先讓其他顏色逃脫才解凍"
		taught_features["ice"] = true
		level_tip_t = 4.5
		_save_progress()


func _process(delta: float) -> void:
	if running and not show_start and not show_clear and not show_fail and not show_rules and not show_map:
		elapsed += delta
		# No hard time-fail for kids — stars soften with time instead.
	if hint_timer > 0.0:
		hint_timer -= delta
		if hint_timer <= 0.0:
			hint_flash = {}
	if toast_t > 0.0:
		toast_t -= delta
	if level_tip_t > 0.0:
		level_tip_t -= delta
		if level_tip_t <= 0.0:
			level_tip = ""
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
	if show_start:
		_draw_start_screen()
		return
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
	if level_tip_t > 0.0 and level_tip != "":
		_draw_level_tip()


func _draw_start_screen() -> void:
	# Full-bleed cover; bias crop toward bottom so baked-in PLAY stays visible on short phones.
	if tex_start != null:
		var tw := float(tex_start.get_width())
		var th := float(tex_start.get_height())
		var scale: float = maxf(vp.x / tw, vp.y / th)
		var dw := tw * scale
		var dh := th * scale
		var ox := (vp.x - dw) * 0.5
		var oy_center := (vp.y - dh) * 0.5
		var oy_bottom := vp.y - dh
		# Prefer lower portion (PLAY + hand) when we must crop vertically.
		var oy := lerpf(oy_center, oy_bottom, 0.7) if dh > vp.y else oy_center
		draw_texture_rect(tex_start, Rect2(ox, oy, dw, dh), false)
	else:
		_draw_background()
		_draw_text(Vector2(vp.x * 0.22, vp.y * 0.4), "彩色方塊逃脫", 28, Color(1.0, 0.42, 0.28), true)
	# Soft pulse over PLAY hit zone (kids-friendly).
	var r := play_hit_rect
	if r.size.x > 1.0:
		var pulse: float = 0.12 + 0.08 * abs(sin(Time.get_ticks_msec() * 0.004))
		draw_rect(r.grow(6.0), Color(1, 1, 1, pulse), false, 3.0)


func _draw_background() -> void:
	# Cover full vp (scale-to-cover, center crop) — no letterbox on tall/short phones.
	var bg: Texture2D = tex_bg_portrait if tex_bg_portrait != null else tex_bg
	if bg != null:
		var tw := float(bg.get_width())
		var th := float(bg.get_height())
		var scale: float = maxf(vp.x / tw, vp.y / th)
		var dw := tw * scale
		var dh := th * scale
		var ox := (vp.x - dw) * 0.5
		var oy := (vp.y - dh) * 0.5
		draw_texture_rect(bg, Rect2(ox, oy, dw, dh), false)
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

	# Raymond bubble logo as header (large & clear)
	var banner: Texture2D = tex_logo if tex_logo != null else (tex_title if tex_title != null else tex_title_sm)
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


func _selected_color() -> String:
	if selected_id < 0:
		return ""
	var blk: Dictionary = model.get_block(selected_id)
	if blk.is_empty() or bool(blk.stone):
		return ""
	return str(blk.color)


func _draw_gates() -> void:
	## Gates sit on the frame edge; width = cells accepted.
	## When a block is selected, only matching-color gate(s) glow.
	var door_w := maxf(16.0, cell * 0.28)
	var sel: String = _selected_color()
	var pulse: float = 0.55 + 0.45 * abs(sin(Time.get_ticks_msec() * 0.006))
	for g in model.gates:
		var cname: String = str(g.color)
		var col: Color = LevelData.COLORS.get(cname, Color.WHITE)
		var start: int = int(g.start)
		var size: int = int(g.size)
		var matched: bool = (sel == "" or sel == cname)
		var dimmed: bool = (sel != "" and sel != cname)
		var alpha: float = 0.28 if dimmed else (1.0 if matched and sel != "" else 0.92)
		col.a = alpha
		var glow: Color = col
		glow.a = alpha * (0.55 + 0.35 * pulse if (matched and sel != "") else 0.35)
		match str(g.side):
			"right":
				for i in size:
					var r := _cell_rect(BoardModel.SIZE - 1, start + i)
					var door := Rect2(r.position.x + r.size.x + 2, r.position.y + cell * 0.08, door_w, r.size.y - cell * 0.16)
					if matched and sel != "":
						_round_rect(door.grow(4), 8, glow)
					_round_rect(door, 6, col)
					draw_rect(door, Color(1, 1, 1, 0.5 * alpha), false, 2.0)
					_round_rect(Rect2(door.position + Vector2(2, 3), Vector2(door.size.x * 0.35, door.size.y - 6)), 4, Color(1, 1, 1, 0.35 * alpha))
				if matched:
					_draw_gate_arrow("right", start, size, col, alpha)
			"left":
				for i in size:
					var r2 := _cell_rect(0, start + i)
					var door2 := Rect2(r2.position.x - door_w - 2, r2.position.y + cell * 0.08, door_w, r2.size.y - cell * 0.16)
					if matched and sel != "":
						_round_rect(door2.grow(4), 8, glow)
					_round_rect(door2, 6, col)
					draw_rect(door2, Color(1, 1, 1, 0.5 * alpha), false, 2.0)
					_round_rect(Rect2(door2.position + Vector2(door2.size.x * 0.55, 3), Vector2(door2.size.x * 0.35, door2.size.y - 6)), 4, Color(1, 1, 1, 0.35 * alpha))
				if matched:
					_draw_gate_arrow("left", start, size, col, alpha)
			"bottom":
				for i in size:
					var r3 := _cell_rect(start + i, BoardModel.SIZE - 1)
					var door3 := Rect2(r3.position.x + cell * 0.08, r3.position.y + r3.size.y + 2, r3.size.x - cell * 0.16, door_w)
					if matched and sel != "":
						_round_rect(door3.grow(4), 8, glow)
					_round_rect(door3, 6, col)
					draw_rect(door3, Color(1, 1, 1, 0.5 * alpha), false, 2.0)
					_round_rect(Rect2(door3.position + Vector2(3, 2), Vector2(door3.size.x - 6, door3.size.y * 0.4)), 4, Color(1, 1, 1, 0.35 * alpha))
				if matched:
					_draw_gate_arrow("bottom", start, size, col, alpha)
			"top":
				for i in size:
					var r4 := _cell_rect(start + i, 0)
					var door4 := Rect2(r4.position.x + cell * 0.08, r4.position.y - door_w - 2, r4.size.x - cell * 0.16, door_w)
					if matched and sel != "":
						_round_rect(door4.grow(4), 8, glow)
					_round_rect(door4, 6, col)
					draw_rect(door4, Color(1, 1, 1, 0.5 * alpha), false, 2.0)
					_round_rect(Rect2(door4.position + Vector2(3, door4.size.y * 0.45), Vector2(door4.size.x - 6, door4.size.y * 0.4)), 4, Color(1, 1, 1, 0.35 * alpha))
				if matched:
					_draw_gate_arrow("top", start, size, col, alpha)


func _draw_gate_arrow(side: String, start: int, size: int, col: Color, alpha: float) -> void:
	var mid := start + (size - 1) * 0.5
	var cx: float
	var cy: float
	var pts: PackedVector2Array
	var s := maxf(8.0, cell * 0.22)
	match side:
		"right":
			var r := _cell_rect(BoardModel.SIZE - 1, int(round(mid)))
			cx = r.position.x + r.size.x + maxf(16.0, cell * 0.28) + s * 0.9
			cy = board_origin.y + mid * (cell + gap) + cell * 0.5
			pts = PackedVector2Array([Vector2(cx - s, cy - s), Vector2(cx + s * 0.6, cy), Vector2(cx - s, cy + s)])
		"left":
			var r2 := _cell_rect(0, int(round(mid)))
			cx = r2.position.x - maxf(16.0, cell * 0.28) - s * 0.9
			cy = board_origin.y + mid * (cell + gap) + cell * 0.5
			pts = PackedVector2Array([Vector2(cx + s, cy - s), Vector2(cx - s * 0.6, cy), Vector2(cx + s, cy + s)])
		"bottom":
			var r3 := _cell_rect(int(round(mid)), BoardModel.SIZE - 1)
			cx = board_origin.x + mid * (cell + gap) + cell * 0.5
			cy = r3.position.y + r3.size.y + maxf(16.0, cell * 0.28) + s * 0.9
			pts = PackedVector2Array([Vector2(cx - s, cy - s), Vector2(cx, cy + s * 0.6), Vector2(cx + s, cy - s)])
		"top":
			var r4 := _cell_rect(int(round(mid)), 0)
			cx = board_origin.x + mid * (cell + gap) + cell * 0.5
			cy = r4.position.y - maxf(16.0, cell * 0.28) - s * 0.9
			pts = PackedVector2Array([Vector2(cx - s, cy + s), Vector2(cx, cy - s * 0.6), Vector2(cx + s, cy + s)])
		_:
			return
	var ac := col
	ac.a = alpha
	draw_colored_polygon(pts, ac)


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
	# Ghost footprint under blocks when hint is active
	if not hint_flash.is_empty() and hint_timer > 0.0:
		_draw_hint_ghost()
	for b in model.blocks:
		_draw_one_block(b, 1.0)
	if not hint_flash.is_empty() and hint_timer > 0.0:
		var hb: Dictionary = model.get_block(int(hint_flash.get("id", -1)))
		if not hb.is_empty():
			var r := _block_bounds(hb)
			var pulse: float = 0.4 + 0.4 * abs(sin(hint_timer * 8.0))
			draw_rect(r.grow(6), Color(1, 1, 0.3, pulse), false, 4.0)


func _draw_hint_ghost() -> void:
	var cells: Array = hint_flash.get("ghost_cells", [])
	if cells.is_empty():
		return
	var pulse: float = 0.35 + 0.35 * abs(sin(hint_timer * 7.0))
	var hb: Dictionary = model.get_block(int(hint_flash.get("id", -1)))
	var col: Color = LevelData.COLORS.get(str(hb.get("color", "yellow")), Color(1, 1, 0.4))
	col.a = pulse
	var rad := maxf(8.0, cell * 0.16)
	for c in cells:
		if c.x < 0 or c.y < 0 or c.x >= BoardModel.SIZE or c.y >= BoardModel.SIZE:
			# Outside board = exit ghost: draw soft blob past the rim
			var edge := Vector2i(clampi(c.x, 0, BoardModel.SIZE - 1), clampi(c.y, 0, BoardModel.SIZE - 1))
			var r0 := _cell_rect(edge.x, edge.y)
			var off := Vector2(signi(c.x - edge.x), signi(c.y - edge.y)) * (cell * 0.55)
			_round_rect(Rect2(r0.position + off, r0.size).grow(-2), rad, col)
		else:
			var r := _cell_rect(c.x, c.y).grow(-2)
			_round_rect(r, rad, col)
			draw_rect(r, Color(1, 1, 1, pulse * 0.7), false, 2.0)


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
		w = vp.x - 20.0
		# Sit below logo so full title stays visible behind/above modal
		var top: float = title_rect.position.y + title_rect.size.y + 6.0
		var bottom_pad: float = 12.0
		h = minf(vp.y - top - bottom_pad, h)
		h = maxf(h, 300.0)
		return Rect2((vp.x - w) * 0.5, top, w, h)
	return Rect2((vp.x - w) * 0.5, (vp.y - h) * 0.5, w, h)


func _draw_modal_dim() -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.15, 0.18, 0.25, 0.55))


func _draw_modal_rules() -> void:
	_draw_modal_dim()
	var r := _modal_rect(0.92, 0.86)
	# Cartoon candy panel
	if tex_modal_rules != null:
		draw_texture_rect(tex_modal_rules, r, false)
	else:
		_round_rect(r, 28, Color(1.0, 0.99, 0.94))
		draw_rect(r, Color(1.0, 0.55, 0.28), false, 5.0)
	# Big playful title
	var title := "怎麼玩？"
	var fs_title := 34 if is_narrow else 40
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_title).x
	_draw_text(Vector2(r.position.x + (r.size.x - tw) * 0.5, r.position.y + 72), title, fs_title, Color(1.0, 0.45, 0.25), true)
	_draw_text(Vector2(r.position.x + (r.size.x - tw) * 0.5 + 1, r.position.y + 73), title, fs_title, Color(1.0, 0.55, 0.2), false)

	var lines: Array = [
		"① 把彩色方塊滑到同色門，讓它們逃脫！",
		"② 連續拖同一塊只算一步；換一塊才加步。",
	]
	# Teach stone / axis / ice only when this level (or toolbar help) uses them
	var show_all: bool = rules_from_button
	if show_all or _level_has_feature("stone"):
		lines.append("③ 灰色石頭是障礙，永遠不會離開。")
	if show_all or _level_has_feature("axis"):
		lines.append("④ 有 ↔ / ↕ 的方塊只能橫／直走。")
	if show_all or _level_has_feature("ice"):
		lines.append("⑤ 結冰方塊要先讓其他顏色逃脫才解凍。")
	lines.append("⑥ 步數少一點 → 星星更多！")
	lines.append("⑦ 連續逃脫可拿連擊加分喔～")
	# Reserve bottom for checkbox + start so rules text never covers controls
	var cb := _rules_checkbox_rect()
	var br := _rules_start_rect()
	var text_bottom := cb.position.y - 10.0
	var fs := 15 if is_narrow else 18
	var y0 := 108.0
	var avail := maxf(120.0, text_bottom - (r.position.y + y0))
	var step := minf(36.0 if not is_narrow else 30.0, avail / float(maxi(lines.size(), 1)))
	step = maxf(22.0, step)
	var colors := [
		Color(0.95, 0.35, 0.4), Color(0.95, 0.55, 0.15), Color(0.2, 0.55, 0.9),
		Color(0.25, 0.65, 0.35), Color(0.55, 0.4, 0.85), Color(0.9, 0.5, 0.2), Color(0.35, 0.45, 0.6),
	]
	for i in lines.size():
		_draw_text(r.position + Vector2(28, y0 + step * float(i)), str(lines[i]), fs, colors[i % colors.size()], true)

	# Checkbox: 下次不要再顯示 (large touch target; label is part of hit rect)
	var ctex: Texture2D = tex_check_on if skip_rules_howto and tex_check_on != null else tex_check_off
	if ctex != null:
		draw_texture_rect(ctex, cb, false)
	else:
		_round_rect(cb, 10, Color(1, 1, 1))
		draw_rect(cb, Color(0.35, 0.55, 0.95), false, 3.0)
		if skip_rules_howto:
			_draw_text(cb.position + Vector2(cb.size.x * 0.22, cb.size.y * 0.72), "✓", int(cb.size.y * 0.55), Color(0.2, 0.7, 0.35))
	var lab := "下次不要再顯示"
	var lab_fs := 17 if is_narrow else 18
	_draw_text(Vector2(cb.position.x + cb.size.x + 12, cb.position.y + cb.size.y * 0.70), lab, lab_fs, Color(0.35, 0.4, 0.5), true)

	# Big green start button
	_draw_fun_button(br, "開始遊戲！", Color(0.4, 0.85, 0.5), tex_fun_green)


func _rules_checkbox_rect() -> Rect2:
	## Visual checkbox square (also used as the left part of the hit target).
	var r := _modal_rect(0.92, 0.86)
	var side := maxf(MIN_TOUCH, 52.0)
	var start := _rules_start_rect()
	return Rect2(r.position.x + 24, start.position.y - side - 16, side, side)


func _rules_checkbox_hit_rect() -> Rect2:
	## Full tap target: checkbox + label strip (kids / fat-finger friendly).
	var r := _modal_rect(0.92, 0.86)
	var cb := _rules_checkbox_rect()
	var start := _rules_start_rect()
	# Stay clear of the start button vertically; stretch across most of the modal width
	var w := minf(r.size.x - 48.0, start.position.x - cb.position.x - 8.0)
	if w < cb.size.x + 80.0:
		# Narrow overlap case: still cover label area above the button
		w = minf(r.size.x - 48.0, cb.size.x + 200.0)
	var h := maxf(cb.size.y + 12.0, MIN_TOUCH + 8.0)
	var y := cb.position.y + (cb.size.y - h) * 0.5
	# Never overlap the start button
	if y + h > start.position.y - 4.0:
		h = maxf(MIN_TOUCH, start.position.y - 4.0 - y)
	return Rect2(cb.position.x - 4.0, y, w, h)


func _rules_start_rect() -> Rect2:
	var r := _modal_rect(0.92, 0.86)
	var bw := minf(320.0, r.size.x - 48.0)
	var bh := maxf(MIN_TOUCH + 8.0, 60.0)
	return Rect2(r.position.x + (r.size.x - bw) * 0.5, r.position.y + r.size.y - bh - 24, bw, bh)


func _draw_fun_button(r: Rect2, label: String, col: Color, tex: Texture2D = null) -> void:
	if tex != null:
		draw_texture_rect(tex, r, false)
	else:
		_round_rect(Rect2(r.position + Vector2(2, 4), r.size), 18, Color(0, 0, 0, 0.15))
		_round_rect(r, 18, col)
		_round_rect(Rect2(r.position + Vector2(8, 6), Vector2(r.size.x - 16, mini(16.0, r.size.y * 0.3))), 10, Color(1, 1, 1, 0.3))
	var fs := int(clampf(r.size.y * 0.42, 20.0, 28.0))
	var sz := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	_draw_text(Vector2(r.position.x + (r.size.x - sz.x) * 0.5, r.position.y + r.size.y * 0.68), label, fs, Color(1, 1, 1), true)


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
	var r := _modal_rect(0.9, 0.78)
	if tex_modal_clear != null:
		draw_texture_rect(tex_modal_clear, r, false)
	else:
		_round_rect(r, 28, Color(1.0, 0.98, 0.9))
		draw_rect(r, Color(1.0, 0.7, 0.25), false, 5.0)
	var title := "過關啦！"
	var fs_title := 38
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_title).x
	_draw_text(Vector2(r.position.x + (r.size.x - tw) * 0.5 + 2, r.position.y + 68), title, fs_title, Color(0.9, 0.35, 0.1), true)
	_draw_text(Vector2(r.position.x + (r.size.x - tw) * 0.5, r.position.y + 66), title, fs_title, Color(1.0, 0.5, 0.15), false)
	var tsec := Time.get_ticks_msec() * 0.004
	for i in 8:
		var ang := i * PI * 0.25 + tsec
		var px := r.position.x + r.size.x * 0.5 + cos(ang) * (70.0 + (i % 3) * 12.0)
		var py := r.position.y + 118.0 + sin(ang) * 18.0
		draw_circle(Vector2(px, py), 4.0 + (i % 3), Color(1.0, 0.85, 0.3, 0.85))

	var stars: int = int(clear_result.get("stars", 0))
	_draw_stars_row(r.position + Vector2(r.size.x * 0.5, 138), stars, 52.0)

	# Three clear lines: moves / time / combo (kid-readable)
	var move_count: int = int(clear_result.get("move_count", model.moves))
	var par: int = int(level_data.get("par", 5))
	var el: float = float(clear_result.get("elapsed", elapsed))
	var mm := int(el) / 60
	var ss := int(el) % 60
	var lines := [
		"步數  %d（目標 %d）" % [move_count, par],
		"時間  %02d:%02d" % [mm, ss],
		"連擊  +%d" % int(clear_result.get("combo", 0)),
	]
	var y0 := r.position.y + 178.0
	for i in lines.size():
		var line: String = str(lines[i])
		var fs_l := 17
		var lw := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_l).x
		_draw_text(Vector2(r.position.x + (r.size.x - lw) * 0.5, y0 + i * 28.0), line, fs_l, Color(0.4, 0.35, 0.3), true)

	var score_txt := "分數 %d" % int(clear_result.get("total", 0))
	var fs_sc := 26
	var sw := font.get_string_size(score_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_sc).x
	_draw_text(Vector2(r.position.x + (r.size.x - sw) * 0.5, y0 + 96.0), score_txt, fs_sc, Color(0.95, 0.45, 0.15), true)

	var btns := _clear_buttons()
	# Big primary Next; secondary replay / map
	_draw_fun_button(btns.next, "下一關 ▶", Color(0.35, 0.82, 0.48), tex_fun_green)
	_draw_fun_button(btns.replay, "再玩一次", Color(1.0, 0.65, 0.3), tex_fun_orange)
	_draw_fun_button(btns.map, "關卡地圖", Color(0.45, 0.7, 0.95), tex_fun_blue)


func _clear_buttons() -> Dictionary:
	var r := _modal_rect(0.9, 0.78)
	var bh := maxf(MIN_TOUCH + 10.0, 62.0)
	var gapb := 10.0
	var next_w := minf(320.0, r.size.x - 48.0)
	var next_y := r.position.y + r.size.y - bh * 2 - gapb - 28
	var half := (r.size.x - 48 - gapb) * 0.5
	return {
		"next": Rect2(r.position.x + (r.size.x - next_w) * 0.5, next_y, next_w, bh),
		"replay": Rect2(r.position.x + 24, next_y + bh + gapb, half, bh * 0.92),
		"map": Rect2(r.position.x + 24 + half + gapb, next_y + bh + gapb, half, bh * 0.92),
	}


func _draw_modal_fail() -> void:
	_draw_modal_dim()
	var r := _modal_rect(0.88, 0.42)
	if tex_modal_clear != null:
		draw_texture_rect(tex_modal_clear, r, false)
	else:
		_round_rect(r, 28, Color(1, 0.95, 0.95))
	var title := "時間到了…"
	var fs_t := 30
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_t).x
	_draw_text(Vector2(r.position.x + (r.size.x - tw) * 0.5, r.position.y + 80), title, fs_t, Color(0.9, 0.35, 0.35), true)
	var msg := "超過三分鐘，再試一次吧！"
	var fs_m := 16
	var mw2 := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_m).x
	_draw_text(Vector2(r.position.x + (r.size.x - mw2) * 0.5, r.position.y + 130), msg, fs_m, Color(0.5, 0.4, 0.4), true)
	_draw_fun_button(_fail_retry_rect(), "重新挑戰", Color(1.0, 0.55, 0.45), tex_fun_orange)


func _fail_retry_rect() -> Rect2:
	var r := _modal_rect(0.88, 0.42)
	var bw := minf(300.0, r.size.x - 48)
	var bh := maxf(MIN_TOUCH + 8.0, 58.0)
	return Rect2(r.position.x + (r.size.x - bw) * 0.5, r.position.y + r.size.y - bh - 32, bw, bh)


func _draw_modal_map() -> void:
	_draw_modal_dim()
	var r := _modal_rect(0.92, 0.88)
	if tex_modal_rules != null:
		draw_texture_rect(tex_modal_rules, r, false)
	else:
		_round_rect(r, 28, Color(0.98, 0.99, 1.0))
	var title := "關卡地圖"
	var fs_t := 28
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_t).x
	_draw_text(Vector2(r.position.x + (r.size.x - tw) * 0.5, r.position.y + 58), title, fs_t, Color(1.0, 0.45, 0.25), true)
	var cols := 2 if is_narrow else 4
	var rows := int(ceil(float(LevelData.level_count()) / float(cols)))
	var pad := 12.0 if is_narrow else 20.0
	var close_h := maxf(MIN_TOUCH + 8.0, 56.0)
	var grid_top := 90.0
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
	_draw_fun_button(Rect2(r.position.x + (r.size.x - cw) * 0.5, r.position.y + r.size.y - close_h - 20, cw, close_h), "關閉", Color(0.75, 0.78, 0.85), tex_fun_blue)


func _map_layout() -> Dictionary:
	var r := _modal_rect(0.92, 0.88)
	var cols := 2 if is_narrow else 4
	var rows := int(ceil(float(LevelData.level_count()) / float(cols)))
	var pad := 12.0 if is_narrow else 20.0
	var close_h := maxf(MIN_TOUCH + 8.0, 56.0)
	var grid_top := 90.0
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
		"close": Rect2(r.position.x + (r.size.x - cw) * 0.5, r.position.y + r.size.y - close_h - 20, cw, close_h),
		"tiles": tiles,
	}


func _draw_toast() -> void:
	var tw := minf(400.0, vp.x - 40.0)
	var y := vp.y - toolbar_h - 52.0 if is_narrow else vp.y - 56.0
	var r := Rect2((vp.x - tw) * 0.5, y, tw, 40)
	_round_rect(r, 12, Color(0.2, 0.25, 0.35, 0.85))
	_draw_text(r.position + Vector2(24, 28), toast, 16 if is_narrow else 18, Color(1, 1, 1))


func _draw_level_tip() -> void:
	var tw := minf(vp.x - 28.0, 420.0)
	var th := 48.0
	var y := hud_h + 6.0
	var r := Rect2((vp.x - tw) * 0.5, y, tw, th)
	var fade: float = clampf(level_tip_t / 0.4, 0.0, 1.0) if level_tip_t < 0.4 else 1.0
	_round_rect(r, 14, Color(0.18, 0.35, 0.55, 0.88 * fade))
	draw_rect(r, Color(1, 1, 1, 0.35 * fade), false, 2.0)
	var fs := 15
	var sw := font.get_string_size(level_tip, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_draw_text(Vector2(r.position.x + (r.size.x - sw) * 0.5, r.position.y + r.size.y * 0.68), level_tip, fs, Color(1, 1, 1, fade), true)


func _show_toast(msg: String) -> void:
	toast = msg
	toast_t = 2.2


func _input(event: InputEvent) -> void:
	# Keyboard always
	if event is InputEventKey and event.pressed and not event.echo:
		if show_start:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
				_leave_start_screen()
			return
		if show_rules:
			if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
				show_rules = false
				rules_from_button = false
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




func _count_move_if_needed(block_id: int) -> void:
	## Consecutive nudges of the SAME block count as 1 step until another block is touched.
	if block_id < 0:
		return
	if block_id != last_move_block_id:
		model.moves += 1
		last_move_block_id = block_id


func _pointer_down(pos: Vector2) -> void:
	if show_start:
		# Tap PLAY button / hand area, or anywhere on lower half as fallback
		if play_hit_rect.has_point(pos) or pos.y > vp.y * 0.72:
			_leave_start_screen()
		return
	if show_rules:
		if _rules_checkbox_hit_rect().has_point(pos):
			skip_rules_howto = not skip_rules_howto
			_save_progress()
			queue_redraw()
			return
		if _rules_start_rect().has_point(pos):
			show_rules = false
			rules_from_button = false
			running = true
			queue_redraw()
			return
		# Tap outside modal while opened from toolbar: dismiss
		var modal := _modal_rect(0.92, 0.86)
		if rules_from_button and not modal.has_point(pos):
			show_rules = false
			rules_from_button = false
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
				_count_move_if_needed(selected_id)
				gesture_counted = true
			drag_moved = true
			_try_auto_exit(selected_id)
		else:
			# Already flush with the rim: one more swipe toward the gate exits
			# (matches keyboard path when try_move fails).
			var edir := Vector2i.ZERO
			if absi(want.x) >= absi(want.y):
				edir = Vector2i(signi(want.x), 0)
			else:
				edir = Vector2i(0, signi(want.y))
			if edir != Vector2i.ZERO and not model.can_exit(selected_id, edir).is_empty():
				if not gesture_counted:
					_count_move_if_needed(selected_id)
					gesture_counted = true
				drag_moved = true
				if model.try_exit(selected_id, edir, elapsed):
					_on_exit_visual(selected_id, edir)
					selected_id = -1
					dragging = false
					_check_clear()
	queue_redraw()


func _keyboard_move(d: Vector2i) -> void:
	if selected_id < 0:
		return
	model.push_history()
	var moved := model.try_move(selected_id, d.x, d.y)
	if moved:
		_count_move_if_needed(selected_id)
		_try_auto_exit(selected_id)
	else:
		if model.try_exit(selected_id, d, elapsed):
			_count_move_if_needed(selected_id)
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
		last_move_block_id = -1
		_show_toast("已復原")
	else:
		_show_toast("沒有可以復原的步驟")
	queue_redraw()


func _do_hint() -> void:
	hint_flash = model.hint()
	hint_timer = 3.0
	if hint_flash.is_empty():
		_show_toast("暫時沒有提示")
	else:
		selected_id = int(hint_flash.id)
		_show_toast(str(hint_flash.get("msg", "試試這塊方塊！")))
	queue_redraw()


func _leave_start_screen() -> void:
	show_start = false
	rules_from_button = false
	if skip_rules_howto:
		show_rules = false
		running = true
	else:
		show_rules = true
		running = false
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
			rules_from_button = true
			show_rules = true
			running = false
	queue_redraw()
