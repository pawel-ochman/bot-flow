extends SceneTree

const LevelData = preload("res://game/core/level_data.gd")
const Rules = preload("res://game/core/rules.gd")

func _initialize() -> void:
	var errors := validate_all()
	for error in errors:
		printerr(error)
	if errors.is_empty():
		print("PASS: all published levels validated and fixture solutions completed")
	quit(0 if errors.is_empty() else 1)

static func validate_all() -> Array[String]:
	var errors: Array[String] = []
	var solutions: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/solutions.json"))
	if not solutions is Dictionary:
		return ["Solution fixtures must be an object"]
	var files := DirAccess.get_files_at("res://levels")
	var ids := {}
	var count := 0
	for file in files:
		if not file.ends_with(".json"):
			continue
		count += 1
		var parsed := LevelData.load_file("res://levels/" + file)
		if not parsed.errors.is_empty():
			for error in parsed.errors:
				errors.append(file + ": " + error)
			continue
		var level: Dictionary = parsed.level
		if ids.has(level.id):
			errors.append(file + ": duplicate level id")
		ids[level.id] = true
		if file != level.id + ".json":
			errors.append(file + ": filename must match level id")
		if not solutions.has(level.id) or not solutions[level.id] is Array:
			errors.append(file + ": missing solution fixture")
			continue
		var state := Rules.create_state(level)
		for action in solutions[level.id]:
			if not action is String or not Rules.apply_action(state, action).allowed:
				errors.append(file + ": rejected fixture action " + str(action))
				break
		if not Rules.is_complete(state):
			errors.append(file + ": fixture does not complete the level")
	if count == 0:
		errors.append("No published levels found")
	for id in solutions:
		if not ids.has(id):
			errors.append("Orphan solution fixture: " + str(id))
	return errors
