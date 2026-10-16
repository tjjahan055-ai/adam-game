class_name LevelLoader
extends RefCounted
## Loads level files (JSON) from res://levels/. Levels are data, so new levels need no new code.

const ROUTE_DIR := "res://levels/route/"
const ROUTE_LEVELS := ["r01.json", "r02.json", "r03.json"]


static func route_level_ids() -> Array[String]:
	var ids: Array[String] = []
	for f in ROUTE_LEVELS:
		ids.append(f.get_basename())
	return ids


## Returns a RouteBoard, or null with an error printed if the file is missing or invalid.
static func load_route(level_id: String) -> RouteBoard:
	var path := ROUTE_DIR + level_id + ".json"
	if not FileAccess.file_exists(path):
		push_error("Level file not found: " + path)
		return null
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Level file is not valid JSON: " + path)
		return null
	return parse_route(data, path)


static func parse_route(data: Dictionary, source: String = "level") -> RouteBoard:
	var b := RouteBoard.new()
	b.width = int(data.get("width", 0))
	b.height = int(data.get("height", 0))
	b.par = int(data.get("par", 0))
	b.title = str(data.get("title", ""))
	b.hint_text = str(data.get("intro", ""))
	if b.width < 1 or b.height < 1 or b.width > 8 or b.height > 10:
		push_error("%s: grid size out of range" % source)
		return null
	var kinds := {"block": RouteBoard.Kind.BLOCK, "source": RouteBoard.Kind.SOURCE,
		"target": RouteBoard.Kind.TARGET, "wire": RouteBoard.Kind.WIRE}
	for c in data.get("cells", []):
		var pos := Vector2i(int(c.get("x", -1)), int(c.get("y", -1)))
		var kind_name := str(c.get("type", ""))
		if not b.in_bounds(pos) or not kinds.has(kind_name) or b.cells.has(pos):
			push_error("%s: bad cell %s" % [source, str(c)])
			return null
		var sides := RouteBoard.sides_from_string(str(c.get("sides", "")))
		if kind_name == "target" and sides == 0:
			sides = RouteBoard.N | RouteBoard.E | RouteBoard.S | RouteBoard.W
		b.cells[pos] = {"kind": kinds[kind_name], "sides": sides, "fixed": true, "piece": ""}
	for piece in data.get("inventory", {}):
		if not RouteBoard.PIECE_SIDES.has(piece):
			push_error("%s: unknown piece %s" % [source, piece])
			return null
		b.inventory[piece] = int(data["inventory"][piece])
	return b
