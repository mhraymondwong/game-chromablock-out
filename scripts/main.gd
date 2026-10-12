extends Node2D
## 彩色方塊逃脫 — Color Block Escape main scene (portrait-only kids UI).

const GAP_RATIO := 0.07  # gap relative to cell
const MIN_TOUCH := 52.0  # modal / secondary touch targets
const BTN_SIZE := 80.0   # bottom toolbar icon diameter (72–88)
const GATE_PAD := 36.0   # room for glowing exit bars + arrows
const BOTTOM_PAD := 36.0 # lift toolbar off screen bottom
const BTN_LABEL_H := 18.0  # Chinese labels under toolbar icons
const FRAME_INSET_RATIO := 0.11  # wood frame border vs board span

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
var tex_gates: Dictionary = {}  # color name -> Texture2D (legacy)
var tex_gate_arrows: Dictionary = {}  # "side_color" -> Texture2D
var tex_board_frame: Texture2D
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
		for side in ["left", "right", "top", "bottom"]:
			tex_gate_arrows["%s_%s" % [side, c]] = _tex("res://assets/ui/gate_arrow_%s_%s.png" % [side, c])
	tex_board_frame = _tex("res://assets/ui/board_wood_frame.png")
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

	# Wooden hanging badge signs under title (mockup)
	var badge_h: float = clampf(vp.x * 0.165, 58.0, 72.0)
	var badge_gap: float = 6.0
	var badge_pad: float = 8.0
	var badge_y: float = title_rect.position.y + title_rect.size.y + 4.0
	var ids_b := ["level", "time", "moves", "score"]
	var n_b := ids_b.size()
	var badge_w: float = (vp.x - badge_pad * 2.0 - badge_gap * float(n_b - 1)) / float(n_b)
	badge_w = maxf(badge_w, 72.0)
	badge_rects.clear()
	var bx: float = badge_pad
	for id in ids_b:
		badge_rects[id] = Rect2(bx, badge_y, badge_w, badge_h)
		bx += badge_w + badge_gap

	hud_h = badge_y + badge_h + 12.0

	# Bottom toolbar: glossy icons + Chinese labels underneath
	var n := 5
	var side_m: float = 8.0
	var gap_btn: float = 8.0
	var icon: float = (vp.x - side_m * 2.0 - gap_btn * float(n - 1)) / float(n)
	icon = clampf(icon, 68.0, 84.0)
	gap_btn = maxf(4.0, (vp.x - side_m * 2.0 - icon * float(n)) / float(maxi(n - 1, 1)))
	var lift_tb: float = maxf(BOTTOM_PAD, maxf(12.0, vp.y * 0.02) + 24.0)
	toolbar_h = icon + BTN_LABEL_H + lift_tb + 14.0

	# Reserve space for wood frame border + outer glowing gates
	var side_reserve: float = GATE_PAD + 28.0
	var avail_w: float = vp.x - margin * 2.0 - side_reserve * 2.0
	var avail_h: float = vp.y - hud_h - toolbar_h - margin * 2.0 - side_reserve * 2.0
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
	# Lift above home indicator; leave room for Chinese labels under icons
	var lift: float = maxf(BOTTOM_PAD, maxf(12.0, vp.y * 0.02) + 24.0)
	var y: float = vp.y - lift - icon - BTN_LABEL_H
	for id in labels:
		# Hit rect includes label strip below icon
		btn_rects[id] = Rect2(x, y, icon, icon + BTN_LABEL_H)
		x += icon + gap_btn


func _load_progress() -> void:
	if FileAccess.file_exists("user://cbe_progress.cfg"):
		var cfg := ConfigFile.new()
		if cfg.load("user://cbe_progress.cfg") == OK:
			unlocked = int(cfg.get_value("p", "unlocked", 1))
			best_stars = cfg.get_value("p", "stars", best_stars)
			skip_rules_howto = bool(cfg.get_value("p", "skip_rules", false))


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("p", "unlocked", unlocked)
	cfg.set_value("p", "stars", best_stars)
	cfg.set_value("p", "skip_rules", skip_rules_howto)
	cfg.save("user://cbe_progress.cfg")


func _start_level(idx: int) -> void:
	level_index = clampi(idx, 0, LevelData.level_count() - 1)
	level_data = LevelData.get_level(level_index)
	model.load_level(level_data)
	selected_id = -1
	dragging = false
	active_touch_index = -1
	elapsed = 0.0
	running = not show_start and not show_rules and not show_map
	show_clear = false
	show_fail = false
	clear_result = {}
	hint_flash = {}
	exit_anim.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if running and not show_start and not show_clear and not show_fail and not show_rules and not show_map:
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
	# Soft fade only — keep playroom sky + rainbow visible.
	if tex_hud != null:
		draw_texture_rect(tex_hud, Rect2(0, 0, vp.x, hud_h), false)

	# Bubble logo as header
	var banner: Texture2D = tex_logo if tex_logo != null else (tex_title if tex_title != null else tex_title_sm)
	if banner != null and title_rect.size.x > 1.0:
		draw_texture_rect(banner, title_rect, false)
	else:
		_draw_text(Vector2(vp.x * 0.18, 48), "彩色方塊逃脫", 28, Color(1.0, 0.42, 0.28), true)

	# Wooden hanging signs: 關卡 / 時間 / 步數 / 分數
	var gold: float = float(level_data.get("gold", 60))
	var sc: Dictionary = BoardModel.compute_score(model.moves, int(level_data.get("par", 5)), elapsed, gold, model.combo_bonus)
	var mm := int(elapsed) / 60
	var ss := int(elapsed) % 60
	var time_ok: bool = elapsed <= gold
	var wood_lab := Color(0.42, 0.26, 0.12)
	var wood_val := Color(0.35, 0.20, 0.08)
	var items := [
		{"id": "level", "label": "關卡", "value": "%d/%d" % [level_index + 1, LevelData.level_count()], "lab": wood_lab, "fg": wood_val},
		{"id": "time", "label": "時間", "value": "%02d:%02d" % [mm, ss], "lab": wood_lab, "fg": wood_val if time_ok else Color(0.75, 0.15, 0.1)},
		{"id": "moves", "label": "步數", "value": "%d/%d" % [model.moves, int(level_data.get("par", 5))], "lab": wood_lab, "fg": wood_val},
		{"id": "score", "label": "分數", "value": "%d" % int(sc.total), "lab": wood_lab, "fg": wood_val},
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
			_round_rect(Rect2(r.position + Vector2(0, 10), r.size - Vector2(0, 10)), 14, Color(0.77, 0.58, 0.38))
			draw_rect(Rect2(r.position + Vector2(0, 10), r.size - Vector2(0, 10)), Color(0.47, 0.31, 0.18), false, 2.0)
		var lab: String = str(it.label)
		var val: String = str(it.value)
		var lab_col: Color = it.lab
		var fg: Color = it.fg
		# Text sits on wood plate (below hanging pins)
		var fs_lab := int(clampf(r.size.y * 0.26, 11.0, 14.0))
		var fs_val := int(clampf(r.size.y * 0.36, 15.0, 20.0))
		var lab_sz := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_lab)
		var val_sz := font.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_val)
		var text_top: float = r.position.y + r.size.y * 0.42
		_draw_text(Vector2(r.position.x + (r.size.x - lab_sz.x) * 0.5, text_top), lab, fs_lab, lab_col, false)
		_draw_text(Vector2(r.position.x + (r.size.x - val_sz.x) * 0.5, r.position.y + r.size.y * 0.78), val, fs_val, fg, false)
		# Combo chip under score (mockup yellow sub-label)
		if id == "score" and model.combo_bonus > 0:
			var combo := "連擊 +%d" % model.combo_bonus
			var fs_c := int(clampf(r.size.y * 0.22, 10.0, 12.0))
			var csz := font.get_string_size(combo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_c)
			_draw_text(Vector2(r.position.x + (r.size.x - csz.x) * 0.5, r.position.y + r.size.y - 2.0), combo, fs_c, Color(0.95, 0.55, 0.1), true)


func _draw_board() -> void:
	var br := _board_rect()
	# Soft drop shadow under wood frame
	var frame_pad := _frame_pad()
	var fr := Rect2(br.position - Vector2(frame_pad, frame_pad), br.size + Vector2(frame_pad * 2, frame_pad * 2))
	draw_rect(Rect2(fr.position + Vector2(5, 8), fr.size), Color(0.35, 0.25, 0.15, 0.22), true, -1.0)
	if tex_board_frame != null:
		draw_texture_rect(tex_board_frame, fr, false)
	else:
		_round_rect(fr, 18, Color(0.72, 0.52, 0.32))
		_round_rect(br.grow(4.0), 12, Color(0.92, 0.86, 0.76))
		# corner screws fallback
		for p in [fr.position + Vector2(12, 12), Vector2(fr.end.x - 12, fr.position.y + 12), Vector2(fr.position.x + 12, fr.end.y - 12), fr.end - Vector2(12, 12)]:
			draw_circle(p, 5.0, Color(0.78, 0.80, 0.82))
			draw_circle(p, 2.0, Color(0.45, 0.48, 0.5))
	# Rounded beige cells (mockup soft inset tiles)
	var rad := maxf(10.0, cell * 0.22)
	for y in BoardModel.SIZE:
		for x in BoardModel.SIZE:
			var r := _cell_rect(x, y).grow(-1.5)
			var c := Color(0.93, 0.87, 0.76) if (x + y) % 2 == 0 else Color(0.90, 0.83, 0.70)
			_round_rect(r, rad, c)
			# soft inner rim
			draw_rect(r, Color(1, 1, 1, 0.18), false, 1.5)


func _round_rect(r: Rect2, rad: float, col: Color) -> void:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.45)
	draw_rect(Rect2(r.position + Vector2(rad, 0), r.size - Vector2(rad * 2, 0)), col)
	draw_rect(Rect2(r.position + Vector2(0, rad), Vector2(r.size.x, r.size.y - rad * 2)), col)
	draw_circle(r.position + Vector2(rad, rad), rad, col)
	draw_circle(r.position + Vector2(r.size.x - rad, rad), rad, col)
	draw_circle(r.position + Vector2(rad, r.size.y - rad), rad, col)
	draw_circle(r.position + Vector2(r.size.x - rad, r.size.y - rad), rad, col)


func _frame_pad() -> float:
	var br := _board_rect()
	return clampf(br.size.x * FRAME_INSET_RATIO, 16.0, 36.0)


func _draw_gates() -> void:
	# Glowing exit bars sit OUTSIDE the wood frame (mockup).
	var fp: float = _frame_pad()
	var br := _board_rect()
	for g in model.gates:
		var cname: String = str(g.color)
		var col: Color = LevelData.COLORS.get(cname, Color.WHITE)
		var start: int = int(g.start)
		var size: int = int(g.size)
		var side: String = str(g.side)
		var end_i: int = start + size - 1
		var pulse: float = 0.85 + 0.15 * abs(sin(Time.get_ticks_msec() * 0.004))
		match side:
			"right":
				var top_r := _cell_rect(BoardModel.SIZE - 1, start)
				var bot_r := _cell_rect(BoardModel.SIZE - 1, end_i)
				var h: float = (bot_r.position.y + bot_r.size.y) - top_r.position.y
				var bar_w: float = maxf(20.0, cell * 0.34)
				var door := Rect2(br.position.x + br.size.x + fp + 2.0, top_r.position.y, bar_w, h)
				_draw_gate_capsule(door, col, pulse, true)
				# Arrow pointing outward (right)
				var tip := Vector2(door.position.x + door.size.x + 10.0, door.get_center().y)
				draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-14, -11), tip + Vector2(-14, 11)]), col)
			"left":
				var top_l := _cell_rect(0, start)
				var bot_l := _cell_rect(0, end_i)
				var h2: float = (bot_l.position.y + bot_l.size.y) - top_l.position.y
				var bar_w2: float = maxf(20.0, cell * 0.34)
				var door2 := Rect2(br.position.x - fp - bar_w2 - 2.0, top_l.position.y, bar_w2, h2)
				_draw_gate_capsule(door2, col, pulse, true)
				# Arrow pointing inward toward board (rightward)
				var tip2 := Vector2(door2.position.x + door2.size.x + 12.0, door2.get_center().y)
				draw_colored_polygon(PackedVector2Array([tip2, tip2 + Vector2(-14, -11), tip2 + Vector2(-14, 11)]), col)
			"bottom":
				var left_b := _cell_rect(start, BoardModel.SIZE - 1)
				var right_b := _cell_rect(end_i, BoardModel.SIZE - 1)
				var w3: float = (right_b.position.x + right_b.size.x) - left_b.position.x
				var bar_h3: float = maxf(20.0, cell * 0.34)
				var door3 := Rect2(left_b.position.x, br.position.y + br.size.y + fp + 2.0, w3, bar_h3)
				_draw_gate_capsule(door3, col, pulse, false)
				var tip3 := Vector2(door3.get_center().x, door3.position.y + door3.size.y + 10.0)
				draw_colored_polygon(PackedVector2Array([tip3, tip3 + Vector2(-11, -14), tip3 + Vector2(11, -14)]), col)
			"top":
				var left_t := _cell_rect(start, 0)
				var right_t := _cell_rect(end_i, 0)
				var w4: float = (right_t.position.x + right_t.size.x) - left_t.position.x
				var bar_h4: float = maxf(20.0, cell * 0.34)
				var door4 := Rect2(left_t.position.x, br.position.y - fp - bar_h4 - 2.0, w4, bar_h4)
				_draw_gate_capsule(door4, col, pulse, false)
				var tip4 := Vector2(door4.get_center().x, door4.position.y + door4.size.y + 12.0)
				draw_colored_polygon(PackedVector2Array([tip4, tip4 + Vector2(-11, -14), tip4 + Vector2(11, -14)]), col)


func _draw_gate_capsule(door: Rect2, col: Color, pulse: float, vertical: bool) -> void:
	var glow := col
	glow.a = 0.35 * pulse
	_round_rect(door.grow(5.0), 12, glow)
	var face := col
	face.a = 0.95
	_round_rect(door, 10, face)
	draw_rect(door, Color(1, 1, 1, 0.55), false, 2.0)
	if vertical:
		_round_rect(Rect2(door.position + Vector2(3, 6), Vector2(door.size.x * 0.35, door.size.y - 12)), 6, Color(1, 1, 1, 0.35))
	else:
		_round_rect(Rect2(door.position + Vector2(6, 3), Vector2(door.size.x - 12, door.size.y * 0.4)), 6, Color(1, 1, 1, 0.35))


func _draw_gate_arrow_tex(tex: Texture2D, center: Vector2, span: float, col: Color, side: String) -> void:
	var s: float = clampf(span * 0.85, 40.0, 90.0)
	if tex != null:
		draw_texture_rect(tex, Rect2(center - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		return
	# Procedural arrow fallback
	var tip: Vector2
	var a: Vector2
	var b: Vector2
	match side:
		"right":
			tip = center + Vector2(18, 0)
			a = center + Vector2(2, -12)
			b = center + Vector2(2, 12)
		"left":
			tip = center + Vector2(16, 0)
			a = center + Vector2(0, -12)
			b = center + Vector2(0, 12)
		"bottom":
			tip = center + Vector2(0, 18)
			a = center + Vector2(-12, 2)
			b = center + Vector2(12, 2)
		_:
			tip = center + Vector2(0, 16)
			a = center + Vector2(-12, 0)
			b = center + Vector2(12, 0)
	draw_colored_polygon(PackedVector2Array([tip, a, b]), col)


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
	var rad := maxf(10.0, cell * 0.22)
	for c in b.cells:
		var r: Rect2 = _cell_rect(c.x, c.y).grow(-1)
		_round_rect(Rect2(r.position + Vector2(3, 4), r.size), rad, Color(0, 0, 0, 0.12 * alpha))
		_round_rect(r, rad, base)
		if stone:
			# soft pebble highlight
			_round_rect(Rect2(r.position + Vector2(6, 5), Vector2(r.size.x * 0.45, r.size.y * 0.28)), 8, Color(1, 1, 1, 0.18 * alpha))
	var bounds: Rect2 = _block_bounds(b).grow(1)
	draw_rect(bounds, Color(1, 1, 1, 0.28 * alpha), false, 2.0)
	if not stone:
		_round_rect(Rect2(bounds.position + Vector2(10, 8), Vector2(bounds.size.x - 20, mini(22.0, bounds.size.y * 0.22))), 10, Color(1, 1, 1, 0.28 * alpha))
	if frozen:
		_round_rect(bounds, 12, Color(0.7, 0.9, 1.0, 0.4 * alpha))
		_draw_text(bounds.get_center() + Vector2(-14, 10), "❄", int(maxi(22, int(cell * 0.35))), Color(1, 1, 1, 0.95 * alpha))
	elif stone:
		_draw_face(bounds.get_center() + Vector2(0, -bounds.size.y * 0.06), mini(bounds.size.x, bounds.size.y) * 0.16, alpha)
		_draw_stone_grass(bounds, alpha)
	else:
		_draw_face(bounds.get_center(), mini(bounds.size.x, bounds.size.y) * 0.18, alpha)
	var axis: String = str(b.get("axis", ""))
	if axis != "" and not stone:
		var icon := "↔" if axis == "h" else "↕"
		_draw_text(bounds.position + Vector2(8, 24), icon, 20, Color(1, 1, 1, 0.95 * alpha))
	if int(b.id) == selected_id:
		draw_rect(bounds.grow(5), Color(1, 1, 1, 0.95), false, 3.5)


func _draw_stone_grass(bounds: Rect2, alpha: float) -> void:
	# Small green grass tufts at stone base (mockup)
	var base_y: float = bounds.position.y + bounds.size.y - 4.0
	var cx: float = bounds.get_center().x
	var gcol := Color(0.35, 0.72, 0.32, 0.95 * alpha)
	for ox in [-10.0, -3.0, 5.0, 12.0]:
		var tip := Vector2(cx + ox, base_y - 10.0 - abs(ox) * 0.15)
		var left := Vector2(cx + ox - 3.5, base_y + 1.0)
		var right := Vector2(cx + ox + 3.5, base_y + 1.0)
		draw_colored_polygon(PackedVector2Array([tip, left, right]), gcol)


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
	# No hard tray — glossy round buttons float on sky (mockup).
	for id in btn_rects.keys():
		_draw_icon_button(str(id), btn_rects[id])


func _draw_icon_button(id: String, r: Rect2) -> void:
	var use_pressed: bool = (pressed_btn == id and press_flash_t > 0.0)
	var tex: Texture2D = null
	if use_pressed and tex_btn_pressed.has(id):
		tex = tex_btn_pressed[id]
	elif tex_btn.has(id):
		tex = tex_btn[id]
	# Icon circle occupies top of hit rect; Chinese label underneath
	var icon_r := Rect2(r.position, Vector2(r.size.x, r.size.x))
	if use_pressed:
		icon_r.position.y += 2.0
	if tex != null:
		draw_texture_rect(tex, icon_r, false)
	else:
		var cols := {
			"undo": Color(0.40, 0.65, 0.95),
			"reset": Color(0.92, 0.35, 0.38),
			"hint": Color(1.0, 0.68, 0.22),
			"map": Color(0.35, 0.78, 0.47),
			"rules": Color(0.67, 0.51, 0.92),
		}
		_draw_button(icon_r, id, cols.get(id, Color(0.8, 0.8, 0.85)), true)
	var zh := {
		"undo": "撤銷",
		"reset": "重置",
		"hint": "提示",
		"map": "網格",
		"rules": "幫助",
	}
	var lab: String = str(zh.get(id, id))
	var fs := int(clampf(r.size.x * 0.22, 11.0, 14.0))
	var lsz := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var ly: float = r.position.y + r.size.x + fs * 0.85
	_draw_text(Vector2(r.position.x + (r.size.x - lsz.x) * 0.5, ly), lab, fs, Color(0.28, 0.22, 0.18), false)


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

	var lines := [
		"① 把彩色方塊滑到同色門，讓它們逃脫！",
		"② 一次拖同一塊算一步；沒動就不計。",
		"③ 灰色石頭是障礙，永遠不會離開。",
		"④ 有 ↔ / ↕ 的方塊只能橫／直走。",
		"⑤ 結冰方塊要先讓其他顏色逃脫才解凍。",
		"⑥ 步數少、時間快 → 星星越多！",
		"⑦ 連續逃脫可拿連擊加分喔～",
	]
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
	var r := _modal_rect(0.9, 0.72)
	if tex_modal_clear != null:
		draw_texture_rect(tex_modal_clear, r, false)
	else:
		_round_rect(r, 28, Color(1.0, 0.98, 0.9))
		draw_rect(r, Color(1.0, 0.7, 0.25), false, 5.0)
	# Burst title
	var title := "過關啦！"
	var fs_title := 38
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_title).x
	_draw_text(Vector2(r.position.x + (r.size.x - tw) * 0.5 + 2, r.position.y + 78), title, fs_title, Color(0.9, 0.35, 0.1), true)
	_draw_text(Vector2(r.position.x + (r.size.x - tw) * 0.5, r.position.y + 76), title, fs_title, Color(1.0, 0.5, 0.15), false)
	# Confetti sparkles
	var tsec := Time.get_ticks_msec() * 0.004
	for i in 8:
		var ang := i * PI * 0.25 + tsec
		var px := r.position.x + r.size.x * 0.5 + cos(ang) * (70.0 + (i % 3) * 12.0)
		var py := r.position.y + 130.0 + sin(ang) * 18.0
		draw_circle(Vector2(px, py), 4.0 + (i % 3), Color(1.0, 0.85, 0.3, 0.85))

	var stars: int = int(clear_result.get("stars", 0))
	_draw_stars_row(r.position + Vector2(r.size.x * 0.5, 155), stars, 52.0)

	var score_txt := "分數 %d" % int(clear_result.get("total", 0))
	var fs_sc := 28
	var sw := font.get_string_size(score_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_sc).x
	_draw_text(Vector2(r.position.x + (r.size.x - sw) * 0.5, r.position.y + 220), score_txt, fs_sc, Color(0.95, 0.45, 0.15), true)

	var detail := "步數分 %d　時間分 %d　連擊 +%d" % [
		int(clear_result.get("moves", 0)),
		int(clear_result.get("time", 0)),
		int(clear_result.get("combo", 0)),
	]
	var fs_d := 14
	var dw := font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_d).x
	_draw_text(Vector2(r.position.x + (r.size.x - dw) * 0.5, r.position.y + 252), detail, fs_d, Color(0.5, 0.45, 0.4), true)

	var btns := _clear_buttons()
	_draw_fun_button(btns.replay, "再玩一次", Color(1.0, 0.65, 0.3), tex_fun_orange)
	_draw_fun_button(btns.next, "下一關 ▶", Color(0.4, 0.85, 0.5), tex_fun_green)
	_draw_fun_button(btns.map, "關卡地圖", Color(0.45, 0.7, 0.95), tex_fun_blue)


func _clear_buttons() -> Dictionary:
	var r := _modal_rect(0.9, 0.72)
	var bh := maxf(MIN_TOUCH + 8.0, 58.0)
	var gapb := 12.0
	var row_y := r.position.y + r.size.y - bh * 2 - gapb - 36
	var half := (r.size.x - 48 - gapb) * 0.5
	var mw := minf(300.0, r.size.x - 48)
	return {
		"replay": Rect2(r.position.x + 24, row_y, half, bh),
		"next": Rect2(r.position.x + 24 + half + gapb, row_y, half, bh),
		"map": Rect2(r.position.x + (r.size.x - mw) * 0.5, row_y + bh + gapb, mw, bh),
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


func _show_toast(msg: String) -> void:
	toast = msg
	toast_t = 2.0


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
				model.moves += 1
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
					model.moves += 1
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
