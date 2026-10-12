extends SceneTree
## Headless smoke: validate all levels + exercise exit logic (incl. horizontal bar).

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
		# Move 1x1 onto gate row then out of the way / exit first
		var mono: Dictionary = m.get_block(mono_id)
		m.push_history()
		# Slide mono to gate row (y=2) then to right edge
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
		# Now horizontal bar → right edge on gate row
		var bar: Dictionary = m.get_block(bar_id)
		if bar.is_empty():
			printerr("FAIL L2 bar missing after mono exit")
			err_count += 1
		else:
			m.try_move(bar_id, 0, gate_y - int(bar.y))
			bar = m.get_block(bar_id)
			# 1x2 origin must land at SIZE-2 so rightmost cell is SIZE-1
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
