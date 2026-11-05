extends RefCounted
## Native progress; browser localStorage is deliberately not overwritten.
const Preferences = preload("res://scripts/preferences.gd")

var path := "user://progress.json"
var data: Dictionary = {
	"version": 1, "gold": 0, "max_combo": 0, "best_waves": 0,
	"characters": {"unknown": true}, "character": "unknown", "mode": "survival",
	"settings": Preferences.defaults(),
}

func load_progress() -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("Spielstand unlesbar; vorhandene Datei bleibt erhalten.")
		return
	for key in data:
		if not parsed.has(key):
			continue
		if data[key] is Dictionary and parsed[key] is Dictionary:
			data[key].merge(parsed[key], true)
		elif typeof(data[key]) == typeof(parsed[key]) or (data[key] is int and parsed[key] is float):
			data[key] = parsed[key]
	data.gold = maxi(0, int(data.gold))
	data.max_combo = maxi(0, int(data.max_combo))
	data.characters.unknown = true
	data.settings = Preferences.normalize(data.settings)

func save_progress() -> bool:
	# Atomic replacement prevents an interrupted write from truncating progress.
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		push_warning("Spielstand konnte nicht gespeichert werden.")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path) == OK
