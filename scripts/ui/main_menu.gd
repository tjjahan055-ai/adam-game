extends Control
## Mission map (greybox): lists the levels with stars. Locked levels are shown but disabled.

const ROUTE_SCENE := "res://scenes/route_level.tscn"


func _ready() -> void:
	var col := UiKit.screen(self)
	col.add_child(UiKit.label("ADAM", 64, UiKit.ACCENT))
	col.add_child(UiKit.label("City Fixer · prototype", 30, UiKit.TEXT_DIM))
	col.add_child(UiKit.label("The power is out across the district. Bring it back, one street at a time.", 28))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	col.add_child(spacer)
	var ids := LevelLoader.route_level_ids()
	for i in ids.size():
		var id: String = ids[i]
		var board := LevelLoader.load_route(id)
		var title := board.title if board else id
		var b := UiKit.button("")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if SaveGame.is_unlocked(id):
			b.text = "%d.  %s    %s" % [i + 1, title, _stars_text(SaveGame.stars_for(id))]
			b.pressed.connect(_open.bind(id))
		else:
			b.text = "%d.  Locked" % (i + 1)
			b.disabled = true
		col.add_child(b)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fill)
	col.add_child(UiKit.label("Progress is saved on this device only. Nothing is sent anywhere.", 22, UiKit.TEXT_DIM))


static func _stars_text(n: int) -> String:
	if n <= 0:
		return ""
	return "%d of 3 stars" % n


func _open(id: String) -> void:
	SaveGame.current_level = id
	get_tree().change_scene_to_file(ROUTE_SCENE)
