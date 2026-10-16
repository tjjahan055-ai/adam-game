class_name RouteSolver
extends RefCounted
## Finds the shortest list of placements that solves a RouteBoard.
## Used by the automated level tests (every level must be solvable within par)
## and by the in-game hint (it shows the first move of a shortest solution).
##
## Search: iterative deepening. A piece is only worth placing on an empty cell
## that a powered tile points into, so the search grows the powered network
## outward one piece at a time. Extra pieces never help, so this finds a
## shortest solution if one exists within the inventory.

const MAX_DEPTH := 12


## Returns an Array of moves {pos: Vector2i, piece: String, sides: int},
## [] if the board is already solved, or null if no solution exists.
static func solve(board: RouteBoard, max_depth: int = MAX_DEPTH):
	if board.is_solved():
		return []
	var limit := 0
	for piece in board.inventory:
		limit += board.inventory[piece]
	limit = min(limit, max_depth)
	for depth in range(1, limit + 1):
		var visited := {}
		var path: Array = []
		if _search(board.duplicate_board(), depth, path, visited):
			return path
	return null


static func _search(board: RouteBoard, depth: int, path: Array, visited: Dictionary) -> bool:
	if board.is_solved():
		return true
	if depth == 0:
		return false
	var key := _key(board)
	if visited.get(key, -1) >= depth:
		return false
	visited[key] = depth
	var powered := board.powered_cells()
	var tried := {}
	for pos in powered:
		for dir in RouteBoard.DIRS:
			if (board.sides_at(pos) & dir) == 0:
				continue
			var cell: Vector2i = pos + RouteBoard.OFFSETS[dir]
			if not board.in_bounds(cell) or board.kind_at(cell) != RouteBoard.Kind.EMPTY:
				continue
			var need := RouteBoard.opposite(dir)
			for piece in board.inventory:
				if board.inventory[piece] <= 0:
					continue
				for turns in range(4):
					var sides := RouteBoard.rotate_sides(RouteBoard.PIECE_SIDES[piece], turns)
					if (sides & need) == 0:
						continue
					var move_key := "%d,%d,%s,%d" % [cell.x, cell.y, piece, sides]
					if tried.has(move_key):
						continue
					tried[move_key] = true
					board.place(cell, piece, turns)
					path.append({"pos": cell, "piece": piece, "sides": sides})
					if _search(board, depth - 1, path, visited):
						return true
					path.pop_back()
					board.remove_at(cell)
	return false


static func _key(board: RouteBoard) -> String:
	var parts: PackedStringArray = []
	for pos in board.cells:
		if board.is_player_piece(pos):
			parts.append("%d,%d:%d" % [pos.x, pos.y, board.cells[pos].sides])
	parts.sort()
	return ";".join(parts)
