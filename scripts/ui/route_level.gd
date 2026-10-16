extends Control
## One routing level: header, board, cable tray, hint/reset, and the result panel.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const PIECE_NAMES := {"straight": "Straight", "corner": "Corner", "tee": "Splitter"}

var level_id := ""
var board: RouteBoard
var start_board: RouteBoard
var hints_used := 0
var finished := false

var view: RouteView
var title_label: Label
var goal_label: Label
var message_label: Label
var tray: HBoxContainer
var piece_buttons := {}
var result_panel: PanelContainer


func _ready() -> void:
	level_id = SaveGame.current_level
	start_board = LevelLoader.load_route(level_id)
	var col := UiKit.screen(self)
	if start_board == null:
		col.add_child(UiKit.label("This level could not be loaded.", 32))
		var back := UiKit.button("Back to map")
		back.pressed.connect(_to_menu)
		col.add_child(back)
		return
	_build(col)
	_restart()


func _build(col: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	var menu := UiKit.button("Map", 72)
	menu.pressed.connect(_to_menu)
	top.add_child(menu)
	title_label = UiKit.label("", 36, UiKit.ACCENT)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(title_label)
	col.add_child(top)
	goal_label = UiKit.label("", 30)
	col.add_child(goal_label)
	message_label = UiKit.label(start_board.hint_text, 26, UiKit.TEXT_DIM)
	message_label.custom_minimum_size = Vector2(0, 70)
	col.add_child(message_label)

	view = RouteView.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.board_changed.connect(_on_board_changed)
	view.message.connect(func(t): message_label.text = t)
	col.add_child(view)

	col.add_child(UiKit.label("Tap a square to lay cable · tap a cable to turn it · hold to take it back", 22, UiKit.TEXT_DIM))
	tray = HBoxContainer.new()
	tray.add_theme_constant_override("separation", 12)
	col.add_child(tray)
	for piece in start_board.inventory:
		var b := UiKit.button("")
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select.bind(piece))
		tray.add_child(b)
		piece_buttons[piece] = b

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	var hint := UiKit.button("Hint")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.pressed.connect(_on_hint)
	actions.add_child(hint)
	var reset := UiKit.button("Start again")
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(_restart)
	actions.add_child(reset)
	col.add_child(actions)


func _restart() -> void:
	board = start_board.duplicate_board()
	finished = false
	view.set_board(board)
	title_label.text = board.title
	message_label.text = board.hint_text
	if result_panel:
		result_panel.queue_free()
		result_panel = null
	var first := ""
	for piece in board.inventory:
		if board.inventory[piece] > 0:
			first = piece
			break
	_select(first)
	_refresh()


func _select(piece: String) -> void:
	view.selected_piece = piece
	for p in piece_buttons:
		piece_buttons[p].button_pressed = (p == piece)


func _refresh() -> void:
	var total := board.targets().size()
	goal_label.text = "Power every building: %d of %d lit" % [board.powered_target_count(), total]
	for p in piece_buttons:
		piece_buttons[p].text = "%s ×%d" % [PIECE_NAMES.get(p, p), board.inventory.get(p, 0)]
		piece_buttons[p].disabled = finished


func _on_board_changed() -> void:
	if finished:
		return
	if view.selected_piece != "" and board.inventory.get(view.selected_piece, 0) <= 0:
		for p in board.inventory:
			if board.inventory[p] > 0:
				_select(p)
				break
	_refresh()
	if board.is_solved():
		_win()


func _on_hint() -> void:
	if finished:
		return
	var sol = RouteSolver.solve(board)
	if sol == null:
		message_label.text = "Something is in the way. Hold a cable to take it back, or tap Start again."
		return
	if sol.is_empty():
		return
	hints_used += 1
	var move: Dictionary = sol[0]
	view.hint_move = move
	_select(move.piece)
	view.queue_redraw()
	message_label.text = "Try a %s on the outlined square." % PIECE_NAMES.get(move.piece, move.piece).to_lower()


func _win() -> void:
	finished = true
	view.hint_move = null
	view.queue_redraw()
	_refresh()
	var used := board.pieces_used()
	var star_par := used <= board.par
	var star_nohint := hints_used == 0
	var stars := 1 + int(star_par) + int(star_nohint)
	SaveGame.record_result(level_id, stars)
	# Let the player see the street light up before the result panel appears.
	await get_tree().create_timer(0.8).timeout
	if not finished:
		return  # player restarted during the pause

	result_panel = PanelContainer.new()
	# Sits over the cable tray at the bottom so the lit-up street stays visible.
	result_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	result_panel.offset_left = 24
	result_panel.offset_right = -24
	result_panel.offset_bottom = -24
	result_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	result_panel.add_child(box)
	box.add_child(UiKit.label("Lights on!  %d of 3 stars" % stars, 40, UiKit.ACCENT))
	box.add_child(UiKit.label("Got it: every building powered", 26))
	box.add_child(UiKit.label("%s: used %d cables (best is %d)" % ["Got it" if star_par else "Missed", used, board.par], 26))
	box.add_child(UiKit.label("%s: no hints" % ("Got it" if star_nohint else "Missed"), 26))
	var ids := LevelLoader.route_level_ids()
	var i := ids.find(level_id)
	if i >= 0 and i + 1 < ids.size():
		var next := UiKit.primary_button("Next street")
		next.pressed.connect(_open.bind(ids[i + 1]))
		box.add_child(next)
	else:
		box.add_child(UiKit.label("That's every street in this prototype.", 26, UiKit.TEXT_DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var again := UiKit.panel_button("Play again" if stars < 3 else "Replay")
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func():
		hints_used = 0
		_restart())
	row.add_child(again)
	var map := UiKit.panel_button("Map")
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.pressed.connect(_to_menu)
	row.add_child(map)
	add_child(result_panel)


func _open(id: String) -> void:
	SaveGame.current_level = id
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
