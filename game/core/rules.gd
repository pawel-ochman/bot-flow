extends RefCounted
## Logical state is a deep copy of a validated level. Never use pixel coordinates here.

const STEPS = {"UP": Vector2i.UP, "DOWN": Vector2i.DOWN, "LEFT": Vector2i.LEFT, "RIGHT": Vector2i.RIGHT}

static func create_state(level: Dictionary) -> Dictionary:
	return level.duplicate(true)

static func cell(entity: Dictionary) -> Vector2i:
	return Vector2i(int(entity.x), int(entity.y))

static func inspect_action(state: Dictionary, robot_id: String) -> Dictionary:
	var robot := {}
	for candidate in state.robots:
		if candidate.id == robot_id:
			robot = candidate
			break
	if robot.is_empty():
		return {"allowed": false, "reason": "unknown_robot", "path": []}
	var step: Vector2i = STEPS[robot.direction]
	var position := cell(robot) + step
	var path: Array[Vector2i] = []
	while position.x >= 0 and position.y >= 0 and position.x < state.width and position.y < state.height:
		path.append(position)
		for obstacle in state.obstacles:
			if cell(obstacle) == position:
				return {"allowed": false, "reason": "obstacle", "path": path, "blocker": position}
		for other in state.robots:
			if cell(other) == position:
				return {"allowed": false, "reason": "robot", "path": path, "blocker": position}
		for gate in state.exits:
			if cell(gate) == position:
				return {"allowed": true, "reason": "exit", "path": path, "exit": position}
		position += step
	return {"allowed": false, "reason": "edge", "path": path, "blocker": position}

static func apply_action(state: Dictionary, robot_id: String) -> Dictionary:
	var result := inspect_action(state, robot_id)
	if result.allowed:
		for index in range(state.robots.size()):
			if state.robots[index].id == robot_id:
				state.robots.remove_at(index)
				break
	return result

static func valid_actions(state: Dictionary) -> Array[String]:
	var actions: Array[String] = []
	for robot in state.robots:
		if inspect_action(state, robot.id).allowed:
			actions.append(robot.id)
	return actions

static func is_complete(state: Dictionary) -> bool:
	return state.robots.is_empty()

static func is_stuck(state: Dictionary) -> bool:
	# Immediate lack of moves, not a general solvability search (deferred to M3).
	return not is_complete(state) and valid_actions(state).is_empty()
