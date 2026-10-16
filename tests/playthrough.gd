extends SceneTree
## Visual smoke test: opens the map and each level, solves it by sending real
## taps through the input system, and saves screenshots. Needs a display:
##   xvfb-run godot --path . --script res://tests/playthrough.gd -- <out_dir>

var out_dir := "user://shots"
var problems := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _run() -> void:
	await _frames(1)
	var save = root.get_node("/root/SaveGame")
	save.reset()
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(10)
	_shot("00-map")
	for id in LevelLoader.route_level_ids():
		save.current_level = id
		change_scene_to_file("res://scenes/route_level.tscn")
		await _frames(10)
		_shot(id + "-start")
		var level = current_scene
		var view: RouteView = level.view
		var sol = RouteSolver.solve(level.board)
		for m in sol:
			level._select(m.piece)
			var turns := RouteView._turns_for(m.piece, m.sides)
			await _tap(view, m.pos)
			for t in range(turns):
				await _tap(view, m.pos)
		await _frames(5)
		if not level.finished:
			problems += 1
			printerr("FAIL: %s not solved by taps" % id)
		_shot(id + "-won")
		print("%s: solved=%s stars=%d" % [id, level.finished, save.stars_for(id)])
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _frames(10)
	_shot("99-map-after")
	quit(1 if problems > 0 else 0)


func _tap(view: RouteView, cell: Vector2i) -> void:
	var cs := view.cell_size()
	var local := view.grid_origin() + (Vector2(cell) + Vector2(0.5, 0.5)) * cs
	var screen_pos := view.get_global_transform_with_canvas() * local
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = screen_pos
		e.global_position = screen_pos
		Input.parse_input_event(e)
		await _frames(2)


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
