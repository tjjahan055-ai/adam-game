extends Node
## Local progress, saved on the device only (autoload "SaveGame").
## Nothing is sent anywhere. Before each save the previous file is copied to a
## backup, and loading falls back to the backup if the main file is damaged.

const VERSION := 1

var save_path := "user://save.json"
var backup_path := "user://save.bak"
var data := {"version": VERSION, "levels": {}}
## Level being played this session (not saved).
var current_level := "r01"


func _ready() -> void:
	load_game()


func reset() -> void:
	data = {"version": VERSION, "levels": {}}
	save_game()


func load_game() -> void:
	for path in [save_path, backup_path]:
		var loaded = _read(path)
		if loaded != null:
			data = loaded
			return
	data = {"version": VERSION, "levels": {}}


func _read(path: String):
	if not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("levels")) != TYPE_DICTIONARY:
		push_warning("Save file unreadable, ignoring: " + path)
		return null
	return parsed


func save_game() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(backup_path))
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("Could not write save file: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data))
	f.close()


func stars_for(level_id: String) -> int:
	return int(data.levels.get(level_id, {}).get("stars", 0))


func is_completed(level_id: String) -> bool:
	return data.levels.has(level_id)


## The first level is always open; each later level opens when the one before is completed.
func is_unlocked(level_id: String) -> bool:
	var ids := LevelLoader.route_level_ids()
	var i := ids.find(level_id)
	return i == 0 or (i > 0 and is_completed(ids[i - 1]))


func record_result(level_id: String, stars: int) -> void:
	var best: int = maxi(stars, stars_for(level_id))
	data.levels[level_id] = {"stars": best}
	save_game()
