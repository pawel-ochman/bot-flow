extends RefCounted
## Strict JSON validation. Errors are returned to callers, never silently repaired.

const DIRECTIONS = ["UP", "DOWN", "LEFT", "RIGHT"]

static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"errors": ["Missing level: " + path]}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"errors": ["Invalid JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()]]}
	var errors := validate(parser.data)
	return {"errors": errors, "level": parser.data if errors.is_empty() else {}}

static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

static func validate(data: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not data is Dictionary:
		return ["Level must be an object"]
	if not integer(data.get("version")) or data.get("version") != 1:
		errors.append("version must be 1")
	if not data.get("id") is String or data.get("id", "").is_empty():
		errors.append("id must be a nonempty string")
	for dimension in ["width", "height"]:
		if not integer(data.get(dimension)) or data.get(dimension, 0) < 2 or data.get(dimension, 0) > 12:
			errors.append(dimension + " must be an integer from 2 to 12")
	for collection in ["robots", "obstacles", "exits"]:
		if not data.get(collection) is Array:
			errors.append(collection + " must be an array")
	if not errors.is_empty():
		return errors
	if data.robots.is_empty() or data.exits.is_empty():
		errors.append("At least one robot and exit are required")
	var occupied := {}
	var robot_ids := {}
	for collection in ["robots", "obstacles", "exits"]:
		for entity in data[collection]:
			if not entity is Dictionary or not integer(entity.get("x")) or not integer(entity.get("y")):
				errors.append(collection + " entries need integer x and y")
				continue
			# Validate before narrowing to Vector2i's 32-bit components.
			if entity.x < 0 or entity.y < 0 or entity.x >= data.width or entity.y >= data.height:
				errors.append("Out-of-bounds entity: " + str(entity))
				continue
			var position := Vector2i(int(entity.x), int(entity.y))
			if occupied.has(position):
				errors.append("Overlapping entities at " + str(position))
			occupied[position] = true
			if collection == "exits" and position.x != 0 and position.y != 0 and position.x != data.width - 1 and position.y != data.height - 1:
				errors.append("Exits must be on the perimeter")
			if collection == "robots":
				if not entity.get("id") is String or entity.get("id", "").is_empty():
					errors.append("Robot id must be a nonempty string")
				elif robot_ids.has(entity.id):
					errors.append("Duplicate robot id: " + entity.id)
				else:
					robot_ids[entity.id] = true
				if not entity.get("direction") in DIRECTIONS:
					errors.append("Invalid robot direction")
	return errors
