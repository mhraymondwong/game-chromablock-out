extends SceneTree
## Headless smoke: validate all levels + auto-solve level 1.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var err_count := 0
	var levels: Array = LevelData.all_levels()
	print("Color Block Escape smoke — levels:", levels.size())
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
	var m := BoardModel.new()
	m.load_level(LevelData.get_level(0))
	if m.colored_remaining() != 1:
		printerr("FAIL L1 start remaining")
		err_count += 1
	var id := 0
	m.push_history()
	if not m.try_move(id, 4, 0):
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
