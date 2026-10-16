class_name RouteView
extends Control
## Draws a RouteBoard and turns taps into moves.
## Tap an empty cell: place the selected piece. Tap your piece: turn it.
## Press and hold your piece: take it back.

signal board_changed
signal message(text: String)

const HOLD_SECONDS := 0.45

const COL_CELL := Color("2c3a42")
const COL_BLOCK := Color("1d272c")
const COL_BLOCK_LINE := Color("3b4a52")
const COL_WIRE_OFF := Color("8a9aa5")
const COL_WIRE_ON := Color("ffc93c")
const COL_SOURCE := Color("4fb286")
const COL_TARGET_OFF := Color("c9d2d7")
const COL_TARGET_ON := Color("ffc93c")
const COL_HINT := Color(1, 1, 1, 0.35)

var board: RouteBoard
var selected_piece := ""
var hint_move = null  # {pos, piece, sides} or null

var _press_cell := Vector2i(-1, -1)
var _press_time := 0.0
var _pressing := false
var _hold_fired := false
var _flash := {}  # Vector2i -> seconds left


func set_board(b: RouteBoard) -> void:
	board = b
	hint_move = null
	queue_redraw()


func _process(delta: float) -> void:
	if _pressing and not _hold_fired:
		_press_time += delta
		if _press_time >= HOLD_SECONDS:
			_hold_fired = true
			_on_hold(_press_cell)
	if not _flash.is_empty():
		for k in _flash.keys():
			_flash[k] -= delta
			if _flash[k] <= 0.0:
				_flash.erase(k)
		queue_redraw()


func cell_size() -> float:
	if board == null:
		return 0.0
	return floor(min(size.x / board.width, size.y / board.height))


func grid_origin() -> Vector2:
	var cs := cell_size()
	return (size - Vector2(board.width, board.height) * cs) / 2.0


func cell_at(local: Vector2) -> Vector2i:
	var cs := cell_size()
	if cs <= 0.0:
		return Vector2i(-1, -1)
	var p := (local - grid_origin()) / cs
	return Vector2i(floori(p.x), floori(p.y))


func _gui_input(event: InputEvent) -> void:
	if board == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_cell = cell_at(event.position)
			_press_time = 0.0
			_pressing = true
			_hold_fired = false
		elif _pressing:
			_pressing = false
			if not _hold_fired and cell_at(event.position) == _press_cell:
				_on_tap(_press_cell)
		accept_event()


func _on_tap(cell: Vector2i) -> void:
	if not board.in_bounds(cell):
		return
	match board.kind_at(cell):
		RouteBoard.Kind.EMPTY:
			if selected_piece == "" or board.inventory.get(selected_piece, 0) <= 0:
				message.emit("No cables of that kind left. Pick another kind below, or hold a placed cable to take it back.")
				return
			var turns := 0
			if hint_move != null and hint_move.pos == cell and hint_move.piece == selected_piece:
				turns = _turns_for(hint_move.piece, hint_move.sides)
				hint_move = null
			board.place(cell, selected_piece, turns)
			_changed(cell)
		RouteBoard.Kind.WIRE:
			if board.rotate_at(cell):
				_changed(cell)
			else:
				message.emit("This cable is part of the street. It can't be moved.")
		RouteBoard.Kind.SOURCE:
			message.emit("Substation: power comes out of here.")
		RouteBoard.Kind.TARGET:
			message.emit("This building needs power.")
		RouteBoard.Kind.BLOCK:
			message.emit("Can't lay cable here.")


func _on_hold(cell: Vector2i) -> void:
	if board.remove_at(cell):
		_changed(cell)
		message.emit("Cable back in your hand.")


func _changed(cell: Vector2i) -> void:
	_flash[cell] = 0.25
	queue_redraw()
	board_changed.emit()


static func _turns_for(piece: String, sides: int) -> int:
	for t in range(4):
		if RouteBoard.rotate_sides(RouteBoard.PIECE_SIDES[piece], t) == sides:
			return t
	return 0


func _draw() -> void:
	if board == null:
		return
	var cs := cell_size()
	var origin := grid_origin()
	var powered := board.powered_cells()
	for y in range(board.height):
		for x in range(board.width):
			var pos := Vector2i(x, y)
			var r := Rect2(origin + Vector2(x, y) * cs, Vector2(cs, cs)).grow(-2)
			_draw_cell(pos, r, powered.has(pos))
	if hint_move != null:
		var r := Rect2(origin + Vector2(hint_move.pos) * cs, Vector2(cs, cs)).grow(-2)
		draw_rect(r, COL_HINT, false, 3.0)
		_draw_wire(r, hint_move.sides, COL_HINT)


func _draw_cell(pos: Vector2i, r: Rect2, is_powered: bool) -> void:
	var kind := board.kind_at(pos)
	if kind == RouteBoard.Kind.BLOCK:
		draw_rect(r, COL_BLOCK)
		var step := r.size.x / 4.0
		for i in range(1, 4):
			draw_line(r.position + Vector2(step * i, 0), r.position + Vector2(0, step * i), COL_BLOCK_LINE, 2.0)
			draw_line(r.end - Vector2(step * i, 0), r.end - Vector2(0, step * i), COL_BLOCK_LINE, 2.0)
		return
	var bg := COL_CELL
	if _flash.has(pos):
		bg = bg.lightened(0.25)
	draw_rect(r, bg)
	match kind:
		RouteBoard.Kind.WIRE:
			var col := COL_WIRE_ON if is_powered else COL_WIRE_OFF
			if board.cells[pos].fixed:
				col = col.darkened(0.15)
			_draw_wire(r, board.sides_at(pos), col)
		RouteBoard.Kind.SOURCE:
			_draw_wire(r, board.sides_at(pos), COL_WIRE_ON)
			draw_rect(r.grow(-r.size.x * 0.22), COL_SOURCE)
			_draw_bolt(r)
		RouteBoard.Kind.TARGET:
			_draw_house(r, COL_TARGET_ON if is_powered else COL_TARGET_OFF, is_powered)


func _draw_wire(r: Rect2, sides: int, col: Color) -> void:
	var c := r.get_center()
	var w := r.size.x * 0.16
	var half := r.size.x / 2.0 + 2.0
	for dir in RouteBoard.DIRS:
		if sides & dir:
			draw_line(c, c + Vector2(RouteBoard.OFFSETS[dir]) * half, col, w)
	draw_circle(c, w * 0.6, col)


func _draw_bolt(r: Rect2) -> void:
	var c := r.get_center()
	var s := r.size.x * 0.18
	var pts := PackedVector2Array([
		c + Vector2(0.2, -1.2) * s, c + Vector2(-0.6, 0.15) * s, c + Vector2(0.0, 0.15) * s,
		c + Vector2(-0.2, 1.2) * s, c + Vector2(0.6, -0.15) * s, c + Vector2(0.0, -0.15) * s])
	draw_colored_polygon(pts, Color("1b2327"))


func _draw_house(r: Rect2, col: Color, lit: bool) -> void:
	var b := r.grow(-r.size.x * 0.2)
	var body := Rect2(b.position + Vector2(0, b.size.y * 0.4), Vector2(b.size.x, b.size.y * 0.6))
	draw_rect(body, col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(b.position.x - 4, body.position.y), Vector2(b.get_center().x, b.position.y),
		Vector2(b.end.x + 4, body.position.y)]), col)
	var win := Rect2(body.get_center() - Vector2(body.size.x * 0.15, body.size.y * 0.2), Vector2(body.size.x * 0.3, body.size.y * 0.35))
	draw_rect(win, Color("fff4c2") if lit else Color("56646b"))
