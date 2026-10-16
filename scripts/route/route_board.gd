class_name RouteBoard
extends RefCounted
## Rules of the routing puzzle (Mechanic 2), with no drawing or input code.
## Each cell may hold one tile. A tile has open sides stored as a bitmask.
## Two neighbouring tiles are linked when both have an open side facing each other.
## Power flows from every source through linked tiles. The level is solved when
## every target is powered.

const N := 1
const E := 2
const S := 4
const W := 8
const DIRS := [N, E, S, W]
const OFFSETS := {N: Vector2i(0, -1), E: Vector2i(1, 0), S: Vector2i(0, 1), W: Vector2i(-1, 0)}

## Piece kinds the player can place, with their open sides in the default rotation.
const PIECE_SIDES := {
	"straight": E | W,
	"corner": N | E,
	"tee": E | S | W,
}

enum Kind { EMPTY, BLOCK, SOURCE, TARGET, WIRE }

var width := 0
var height := 0
var par := 0
var title := ""
var hint_text := ""
## Dictionary[Vector2i, Dictionary] with keys: kind, sides, fixed, piece
var cells := {}
## Dictionary[String, int]: pieces still in the player's hand.
var inventory := {}


static func opposite(dir: int) -> int:
	match dir:
		N: return S
		E: return W
		S: return N
		_: return E


static func rotate_sides(sides: int, turns: int = 1) -> int:
	var s := sides
	for i in range(posmod(turns, 4)):
		s = ((s << 1) | (s >> 3)) & 0xF
	return s


static func sides_from_string(text: String) -> int:
	var s := 0
	for ch in text.to_upper():
		match ch:
			"N": s |= N
			"E": s |= E
			"S": s |= S
			"W": s |= W
	return s


func duplicate_board() -> RouteBoard:
	var b := RouteBoard.new()
	b.width = width
	b.height = height
	b.par = par
	b.title = title
	b.hint_text = hint_text
	for pos in cells:
		b.cells[pos] = cells[pos].duplicate()
	b.inventory = inventory.duplicate()
	return b


func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < width and pos.y < height


func kind_at(pos: Vector2i) -> int:
	if not cells.has(pos):
		return Kind.EMPTY
	return cells[pos].kind


func sides_at(pos: Vector2i) -> int:
	if not cells.has(pos):
		return 0
	return cells[pos].sides


func is_player_piece(pos: Vector2i) -> bool:
	return cells.has(pos) and cells[pos].kind == Kind.WIRE and not cells[pos].fixed


func can_place(pos: Vector2i, piece: String) -> bool:
	return in_bounds(pos) and kind_at(pos) == Kind.EMPTY and inventory.get(piece, 0) > 0


## Places a piece from the inventory. Returns false (and changes nothing) if not allowed.
func place(pos: Vector2i, piece: String, turns: int = 0) -> bool:
	if not can_place(pos, piece):
		return false
	cells[pos] = {"kind": Kind.WIRE, "sides": rotate_sides(PIECE_SIDES[piece], turns), "fixed": false, "piece": piece}
	inventory[piece] -= 1
	return true


func rotate_at(pos: Vector2i) -> bool:
	if not is_player_piece(pos):
		return false
	cells[pos].sides = rotate_sides(cells[pos].sides, 1)
	return true


## Returns a player piece to the inventory.
func remove_at(pos: Vector2i) -> bool:
	if not is_player_piece(pos):
		return false
	var piece: String = cells[pos].piece
	cells.erase(pos)
	inventory[piece] = inventory.get(piece, 0) + 1
	return true


func pieces_used() -> int:
	var n := 0
	for pos in cells:
		if is_player_piece(pos):
			n += 1
	return n


func linked(a: Vector2i, dir: int) -> bool:
	var b: Vector2i = a + OFFSETS[dir]
	if not in_bounds(b):
		return false
	return (sides_at(a) & dir) != 0 and (sides_at(b) & opposite(dir)) != 0


## Set of cells that carry power (Dictionary used as a set).
func powered_cells() -> Dictionary:
	var seen := {}
	var queue: Array[Vector2i] = []
	for pos in cells:
		if cells[pos].kind == Kind.SOURCE:
			seen[pos] = true
			queue.append(pos)
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for dir in DIRS:
			var nxt: Vector2i = cur + OFFSETS[dir]
			if not seen.has(nxt) and linked(cur, dir):
				seen[nxt] = true
				queue.append(nxt)
	return seen


func targets() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for pos in cells:
		if cells[pos].kind == Kind.TARGET:
			out.append(pos)
	return out


func powered_target_count() -> int:
	var powered := powered_cells()
	var n := 0
	for t in targets():
		if powered.has(t):
			n += 1
	return n


func is_solved() -> bool:
	var t := targets()
	return not t.is_empty() and powered_target_count() == t.size()
