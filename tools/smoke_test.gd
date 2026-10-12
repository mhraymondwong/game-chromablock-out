extends SceneTree
## Headless smoke: validate all levels + exit logic (bars, vertical, flush swipe).

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var err_count := 0
	var levels: Array = LevelData.all_levels()
	print("Color Block Escape smoke — SIZE=", BoardModel.SIZE, " levels:", levels.size())
	if BoardModel.SIZE != 8:
		printerr("FAIL: BoardModel.SIZE must be 8, got ", BoardModel.SIZE)
		err_count += 1
	if levels.size() < 8:
		printerr("FAIL: need at least 8 levels, got ", levels.size())
		err_count += 1
	for i in levels.size():
		var msg: String = BoardModel.validate_level(levels[i])
		if msg != "":
			printerr("FAIL level ", i + 1, ": ", msg)
			err_count += 1
		else:
			print("OK level ", i + 1, " — ", levels[i].get("title", ""), " par=", levels[i].get("par", 0))

	# --- Level 1: 1x1 slides right and exits ---
	var m := BoardModel.new()
	m.load_level(LevelData.get_level(0))
	if m.colored_remaining() != 1:
		printerr("FAIL L1 start remaining")
		err_count += 1
	var id := 0
	m.push_history()
	var dx1 := BoardModel.SIZE - 1 - int(m.get_block(id).x)
	if not m.try_move(id, dx1, 0):
		printerr("FAIL L1 move right")
		err_count += 1
	else:
		m.moves += 1
	if m.try_exit(id, Vector2i(1, 0), 1.0):
		print("OK L1 exit")
	else:
		printerr("FAIL L1 exit")
		err_count += 1
	if not m.is_clear():
		printerr("FAIL L1 not clear")
		err_count += 1

	# --- Level 2: horizontal 1x2 must be able to exit right when flush ---
	m.load_level(LevelData.get_level(1))
	var bar_id := -1
	var mono_id := -1
	for b in m.blocks:
		if str(b.shape) == "1x2":
			bar_id = int(b.id)
		elif str(b.shape) == "1x1":
			mono_id = int(b.id)
	if bar_id < 0 or mono_id < 0:
		printerr("FAIL L2 missing pieces")
		err_count += 1
	else:
		var mono: Dictionary = m.get_block(mono_id)
		m.push_history()
		var gate_y := 2
		m.try_move(mono_id, 0, gate_y - int(mono.y))
		mono = m.get_block(mono_id)
		m.try_move(mono_id, BoardModel.SIZE - 1 - int(mono.x), 0)
		if m.can_exit(mono_id, Vector2i(1, 0)).is_empty():
			printerr("FAIL L2 1x1 cannot exit at edge")
			err_count += 1
		elif not m.try_exit(mono_id, Vector2i(1, 0), 2.0):
			printerr("FAIL L2 1x1 try_exit")
			err_count += 1
		else:
			print("OK L2 1x1 exit")
		var bar: Dictionary = m.get_block(bar_id)
		if bar.is_empty():
			printerr("FAIL L2 bar missing after mono exit")
			err_count += 1
		else:
			m.try_move(bar_id, 0, gate_y - int(bar.y))
			bar = m.get_block(bar_id)
			var target_x := BoardModel.SIZE - 2
			m.try_move(bar_id, target_x - int(bar.x), 0)
			bar = m.get_block(bar_id)
			print("L2 bar at (", bar.x, ",", bar.y, ") cells=", bar.cells)
			if m.can_exit(bar_id, Vector2i(1, 0)).is_empty():
				printerr("FAIL L2 1x2 cannot exit — horizontal bar bug")
				err_count += 1
			elif not m.try_exit(bar_id, Vector2i(1, 0), 3.0):
				printerr("FAIL L2 1x2 try_exit")
				err_count += 1
			elif not m.is_clear():
				printerr("FAIL L2 not clear after both exits")
				err_count += 1
			else:
				print("OK L2 1x2 exit + clear")

	# --- Synthetic: vertical 1x2 (shape 2x1) exits right through size-2 gate ---
	m.load_level({
		"gates": [{"side": "right", "start": 3, "size": 2, "color": "yellow"}],
		"blocks": [{"shape": "2x1", "color": "yellow", "x": 6, "y": 3}],
	})
	var vid := 0
	m.try_move(vid, 1, 0)  # flush at x=7
	if m.can_exit(vid, Vector2i(1, 0)).is_empty():
		printerr("FAIL synth vertical 2x1 cannot exit right")
		err_count += 1
	elif not m.try_exit(vid, Vector2i(1, 0), 1.0):
		printerr("FAIL synth vertical 2x1 try_exit")
		err_count += 1
	else:
		print("OK synth vertical 2x1 exit right")

	# Gate too small must refuse
	m.load_level({
		"gates": [{"side": "right", "start": 3, "size": 1, "color": "yellow"}],
		"blocks": [{"shape": "2x1", "color": "yellow", "x": 7, "y": 3}],
	})
	if not m.can_exit(0, Vector2i(1, 0)).is_empty():
		printerr("FAIL synth size-1 gate should block vertical 2x1")
		err_count += 1
	else:
		print("OK synth size-1 gate blocks vertical 2x1")

	# --- Synthetic: horizontal 1x2 exits bottom through size-2 gate ---
	m.load_level({
		"gates": [{"side": "bottom", "start": 2, "size": 2, "color": "blue"}],
		"blocks": [{"shape": "1x2", "color": "blue", "x": 2, "y": 7}],
	})
	if m.can_exit(0, Vector2i(0, 1)).is_empty():
		printerr("FAIL synth horizontal 1x2 cannot exit bottom")
		err_count += 1
	elif not m.try_exit(0, Vector2i(0, 1), 1.0):
		printerr("FAIL synth horizontal 1x2 try_exit bottom")
		err_count += 1
	else:
		print("OK synth horizontal 1x2 exit bottom")

	# --- Flush piece: try_exit works without further move ---
	m.load_level({
		"gates": [{"side": "right", "start": 4, "size": 2, "color": "yellow"}],
		"blocks": [{"shape": "2x1", "color": "yellow", "x": 7, "y": 4}],
	})
	if m.can_exit(0, Vector2i(1, 0)).is_empty():
		printerr("FAIL flush vertical cannot can_exit")
		err_count += 1
	elif not m.try_exit(0, Vector2i(1, 0), 4.0):
		printerr("FAIL flush vertical try_exit")
		err_count += 1
	else:
		print("OK flush vertical exits on directed try_exit")

	# --- Level 4: yellow 2x1 at right edge must exit ---
	m.load_level(LevelData.get_level(3))
	var yid := -1
	for b in m.blocks:
		if str(b.shape) == "2x1" and str(b.color) == "yellow":
			yid = int(b.id)
			break
	if yid < 0:
		printerr("FAIL L4 missing yellow 2x1")
		err_count += 1
	else:
		var yb: Dictionary = m.get_block(yid)
		m.try_move(yid, BoardModel.SIZE - 1 - int(yb.x), 0)
		yb = m.get_block(yid)
		print("L4 yellow at (", yb.x, ",", yb.y, ") cells=", yb.cells)
		if m.can_exit(yid, Vector2i(1, 0)).is_empty():
			printerr("FAIL L4 yellow 2x1 stuck at gate (gate too small?)")
			err_count += 1
		elif not m.try_exit(yid, Vector2i(1, 0), 5.0):
			printerr("FAIL L4 yellow try_exit")
			err_count += 1
		else:
			print("OK L4 yellow 2x1 exit")

	var sc: Dictionary = BoardModel.compute_score(1, 3, 5.0, 25.0, 0)
	if int(sc.total) < 85:
		printerr("FAIL score expected high, got ", sc.total)
		err_count += 1
	else:
		print("OK score ", sc.total, " stars ", sc.stars)

	m.load_level(LevelData.get_level(0))
	m.push_history()
	m.try_move(0, 1, 0)
	m.moves += 1
	if not m.undo():
		printerr("FAIL undo")
		err_count += 1
	elif m.moves != 0:
		printerr("FAIL undo moves")
		err_count += 1
	else:
		print("OK undo")

	if err_count == 0:
		print("SMOKE PASS")
		quit(0)
	else:
		printerr("SMOKE FAIL errors=", err_count)
		quit(1)
