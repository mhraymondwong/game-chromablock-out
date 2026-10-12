extends SceneTree
## Headless smoke: validate all levels + BFS solvability + exit logic.

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
			printerr("FAIL level ", i + 1, " validate: ", msg)
			err_count += 1
		else:
			print("OK validate L", i + 1, " — ", levels[i].get("title", ""))

	err_count += _test_exit_geometry()
	err_count += _test_score_kinder()
	err_count += _test_undo()

	for i in levels.size():
		var cap := 60000 if i < 7 else 25000
		var ok := _solve_level(LevelData.get_level(i), cap)
		if not ok:
			print("  BFS miss L", i + 1, " — trying scripted…")
			ok = _scripted_solve(i)
		if ok:
			print("OK solve L", i + 1, " — ", levels[i].get("title", ""))
		else:
			printerr("FAIL solve L", i + 1, " — soft-lock or unsolvable")
			err_count += 1

	if err_count == 0:
		print("SMOKE PASS")
		quit(0)
	else:
		printerr("SMOKE FAIL errors=", err_count)
		quit(1)


func _test_exit_geometry() -> int:
	var err := 0
	var m := BoardModel.new()
	m.load_level(LevelData.get_level(0))
	var id := 0
	var dx1 := BoardModel.SIZE - 1 - int(m.get_block(id).x)
	m.try_move(id, dx1, 0)
	if not m.try_exit(id, Vector2i(1, 0), 1.0) or not m.is_clear():
		printerr("FAIL L1 scripted exit")
		err += 1
	else:
		print("OK L1 scripted exit")

	m.load_level({
		"gates": [{"side": "right", "start": 2, "size": 1, "color": "blue"}],
		"blocks": [{"shape": "1x2", "color": "blue", "x": 6, "y": 2}],
	})
	if m.can_exit(0, Vector2i(1, 0)).is_empty() or not m.try_exit(0, Vector2i(1, 0), 1.0):
		printerr("FAIL horiz 1x2 exit right")
		err += 1
	else:
		print("OK horiz 1x2 exit right")

	m.load_level({
		"gates": [{"side": "right", "start": 3, "size": 2, "color": "yellow"}],
		"blocks": [{"shape": "2x1", "color": "yellow", "x": 7, "y": 3}],
	})
	if m.can_exit(0, Vector2i(1, 0)).is_empty() or not m.try_exit(0, Vector2i(1, 0), 1.0):
		printerr("FAIL vert 2x1 exit right")
		err += 1
	else:
		print("OK vert 2x1 exit right")

	m.load_level({
		"gates": [{"side": "right", "start": 3, "size": 1, "color": "yellow"}],
		"blocks": [{"shape": "2x1", "color": "yellow", "x": 7, "y": 3}],
	})
	if not m.can_exit(0, Vector2i(1, 0)).is_empty():
		printerr("FAIL size-1 gate should block vert 2x1")
		err += 1
	else:
		print("OK size-1 gate blocks vert 2x1")

	m.load_level(LevelData.get_level(3))
	var yid := -1
	for b in m.blocks:
		if str(b.shape) == "2x1" and str(b.color) == "yellow":
			yid = int(b.id)
			break
	if yid < 0:
		printerr("FAIL L4 missing yellow 2x1")
		err += 1
	else:
		var yb: Dictionary = m.get_block(yid)
		m.try_move(yid, BoardModel.SIZE - 1 - int(yb.x), 0)
		if m.can_exit(yid, Vector2i(1, 0)).is_empty() or not m.try_exit(yid, Vector2i(1, 0), 5.0):
			printerr("FAIL L4 yellow exit")
			err += 1
		else:
			print("OK L4 yellow exit")
	return err


func _test_score_kinder() -> int:
	var err := 0
	var sc: Dictionary = BoardModel.compute_score(1, 3, 5.0, 25.0, 0)
	if int(sc.stars) < 3 or bool(sc.failed):
		printerr("FAIL score expected 3★ no-fail, got ", sc)
		err += 1
	else:
		print("OK score ", sc.total, " stars ", sc.stars)
	var sc2: Dictionary = BoardModel.compute_score(30, 5, 400.0, 30.0, 0)
	if bool(sc2.failed) or int(sc2.stars) < 1:
		printerr("FAIL kinder score should not fail slow clear ", sc2)
		err += 1
	else:
		print("OK kinder slow clear stars ", sc2.stars, " total ", sc2.total)
	return err


func _test_undo() -> int:
	var err := 0
	var m := BoardModel.new()
	m.load_level(LevelData.get_level(0))
	m.push_history()
	m.try_move(0, 1, 0)
	m.moves += 1
	if not m.undo() or m.moves != 0:
		printerr("FAIL undo")
		err += 1
	else:
		print("OK undo")
	return err


func _state_key(m: BoardModel) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var ids: Array = []
	for b in m.blocks:
		ids.append(int(b.id))
	ids.sort()
	for id in ids:
		var b: Dictionary = m.get_block(id)
		parts.append("%d:%d:%d:%d" % [id, int(b.x), int(b.y), 1 if bool(b.get("frozen", false)) else 0])
	return "%d|%s" % [m.exits_done, ",".join(parts)]


func _slide_max(m: BoardModel, bid: int, d: Vector2i) -> int:
	## Slide as far as possible in direction d; return cells moved.
	var n := 0
	while m.try_move(bid, d.x, d.y):
		n += 1
		if n > BoardModel.SIZE:
			break
	return n


func _solve_level(data: Dictionary, max_states: int = 120000) -> bool:
	var m := BoardModel.new()
	m.load_level(data)
	if m.is_clear():
		return true
	var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var queue: Array = []
	var visited: Dictionary = {}
	var start_snap: Dictionary = m.snapshot()
	queue.append(start_snap)
	visited[_state_key(m)] = true
	var processed := 0
	var qi := 0
	while qi < queue.size() and processed < max_states:
		var snap: Dictionary = queue[qi]
		qi += 1
		processed += 1
		m.restore(snap)
		if m.is_clear():
			print("  BFS solved expansions=", processed, " moves=", m.moves)
			return true
		var bids: Array = []
		for b in m.blocks:
			if bool(b.stone) or bool(b.get("frozen", false)):
				continue
			bids.append(int(b.id))
		for bid in bids:
			for d in dirs:
				# Exit if possible
				m.restore(snap)
				if not m.can_exit(bid, d).is_empty():
					if m.try_exit(bid, d, 1.0):
						var k := _state_key(m)
						if not visited.has(k):
							visited[k] = true
							var ns: Dictionary = m.snapshot()
							ns["moves"] = int(snap.moves) + 1
							queue.append(ns)
				# Slide cell-by-cell; enqueue every stop (need mid-lane stops for gates)
				m.restore(snap)
				var steps := 0
				while steps < BoardModel.SIZE:
					if not m.try_move(bid, d.x, d.y):
						break
					steps += 1
					var k2 := _state_key(m)
					if not visited.has(k2):
						visited[k2] = true
						var ns2: Dictionary = m.snapshot()
						ns2["moves"] = int(snap.moves) + 1
						queue.append(ns2)
					# Exit from this cell if flush with matching gate
					if not m.can_exit(bid, d).is_empty():
						var m2 := BoardModel.new()
						m2.gates = m.gates
						m2.restore(m.snapshot())
						if m2.try_exit(bid, d, 1.0):
							var k3 := _state_key(m2)
							if not visited.has(k3):
								visited[k3] = true
								var ns3: Dictionary = m2.snapshot()
								ns3["moves"] = int(snap.moves) + 1
								queue.append(ns3)
	print("  BFS exhausted processed=", processed, " visited=", visited.size())
	return false


func _find_id(m: BoardModel, shape: String, color: String = "") -> int:
	for b in m.blocks:
		if str(b.shape) == shape and (color == "" or str(b.color) == color):
			return int(b.id)
	return -1


func _go(m: BoardModel, bid: int, dx: int, dy: int) -> bool:
	if bid < 0:
		return false
	return m.try_move(bid, dx, dy)


func _exit(m: BoardModel, bid: int, d: Vector2i) -> bool:
	if bid < 0:
		return false
	return m.try_exit(bid, d, 1.0)


func _scripted_solve(level_index: int) -> bool:
	## Hand-checked paths as fallback when BFS times out.
	var m := BoardModel.new()
	m.load_level(LevelData.get_level(level_index))
	match level_index:
		0:
			var a := 0
			_go(m, a, 5, 0)
			_exit(m, a, Vector2i(1, 0))
		1:
			var bar := _find_id(m, "1x2", "blue")
			var mono := _find_id(m, "1x1", "blue")
			_go(m, mono, 0, -2)
			_go(m, mono, 3, 0)
			_exit(m, mono, Vector2i(1, 0))
			_go(m, bar, 5, 0)
			_exit(m, bar, Vector2i(1, 0))
		2:
			var r1 := _find_id(m, "1x1", "red")
			# first red is lower id
			var reds: Array = []
			for b in m.blocks:
				if str(b.color) == "red":
					reds.append(int(b.id))
			var blue := _find_id(m, "2x1", "blue")
			# Move first red right out
			_go(m, reds[0], 6, 0)
			_exit(m, reds[0], Vector2i(1, 0))
			# Second red up to row 2 then right
			_go(m, reds[1], 0, -2)
			_go(m, reds[1], 2, 0)
			_exit(m, reds[1], Vector2i(1, 0))
			# Blue down and out
			_go(m, blue, 0, 4)
			_exit(m, blue, Vector2i(0, 1))
		3:
			var green := _find_id(m, "1x2", "green")
			var y1 := _find_id(m, "1x1", "yellow")
			var y2 := _find_id(m, "2x1", "yellow")
			_go(m, green, -1, 0)
			_exit(m, green, Vector2i(-1, 0))
			_go(m, y1, 0, 3)
			_go(m, y1, 2, 0)
			# may need align to gate y=4..5 — 1x1 can use any cell of size-2 gate
			_go(m, y1, 0, 1)
			_exit(m, y1, Vector2i(1, 0))
			_go(m, y2, 0, 0)  # already near
			_go(m, y2, 1, 0)
			_exit(m, y2, Vector2i(1, 0))
		4:
			var orange := _find_id(m, "2x2", "orange")
			var purple := _find_id(m, "1x1", "purple")
			_go(m, purple, 0, -3)
			_exit(m, purple, Vector2i(0, -1))
			_go(m, orange, 0, 4)
			_exit(m, orange, Vector2i(0, 1))
		5:
			var red3 := _find_id(m, "1x3", "red")
			var blue3 := _find_id(m, "3x1", "blue")
			var red1 := _find_id(m, "1x1", "red")
			_go(m, red1, 0, 1)
			_go(m, red1, 1, 0)
			# red1 to gate y=2
			_go(m, red1, 0, 0)
			_exit(m, red1, Vector2i(1, 0))
			_go(m, red3, 4, 0)
			_exit(m, red3, Vector2i(1, 0))
			_go(m, blue3, 0, 3)
			_exit(m, blue3, Vector2i(0, 1))
		6:
			var green := _find_id(m, "L_se", "green")
			var ybar := _find_id(m, "1x2", "yellow")
			var yv := _find_id(m, "2x1", "yellow")
			var purp := _find_id(m, "1x1", "purple")
			# Slide L left to gate rows 2-3
			_go(m, green, -2, 0)
			_exit(m, green, Vector2i(-1, 0))
			_go(m, purp, 0, 2)
			_exit(m, purp, Vector2i(0, 1))
			_go(m, yv, 1, 0)
			_exit(m, yv, Vector2i(1, 0))
			_go(m, ybar, 0, -1)
			_go(m, ybar, 2, 0)
			_exit(m, ybar, Vector2i(1, 0))
		7:
			# L8: blue bar top → red left (ice unlocks) → blue mono top → orange right
			var bbar := _find_id(m, "1x2", "blue")
			var b1 := _find_id(m, "1x1", "blue")
			var red := _find_id(m, "1x1", "red")
			var orange := _find_id(m, "2x2", "orange")
			# blue 1x2 at (3,1) already aligned to top gate 3-4
			_go(m, bbar, 0, -1)
			_exit(m, bbar, Vector2i(0, -1))
			# red at (1,5) → left gate y=5
			_go(m, red, -1, 0)
			_exit(m, red, Vector2i(-1, 0))
			# ice unlocked; blue 1x1 at (5,3) → top via x=3 or x=4
			_go(m, b1, -1, 0)
			_go(m, b1, 0, -3)
			_exit(m, b1, Vector2i(0, -1))
			# orange 2x2 at (3,4) → right gate rows 4-5
			_go(m, orange, 3, 0)
			_exit(m, orange, Vector2i(1, 0))
		_:
			return false
	if m.is_clear():
		print("  scripted solve OK moves=", m.moves)
		return true
	print("  scripted incomplete remaining=", m.colored_remaining(), " blocks=", m.blocks)
	return false
