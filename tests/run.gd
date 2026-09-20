extends SceneTree

const LevelData = preload("res://game/core/level_data.gd")
const Rules = preload("res://game/core/rules.gd")
const Validator = preload("res://tools/validate_levels.gd")
var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func base_level(direction: String = "UP") -> Dictionary:
	return {"version": 1, "id": "fixture", "width": 5, "height": 5, "robots": [{"id": "A", "x": 2, "y": 2, "direction": direction}], "obstacles": [], "exits": [{"x": 2, "y": 0}, {"x": 2, "y": 4}, {"x": 0, "y": 2}, {"x": 4, "y": 2}]}

func _initialize() -> void:
	run_rules()
	run_validation()
	var level_errors := Validator.validate_all()
	check(level_errors.is_empty(), "Published level regression: " + str(level_errors))
	call_deferred("run_presentation")

func run_rules() -> void:
	for direction in Rules.STEPS:
		var original := base_level(direction)
		var state := Rules.create_state(original)
		var result := Rules.apply_action(state, "A")
		check(result.allowed and result.path.size() == 2, direction + " traverses two cells to exit")
		check(result.exit == Vector2i(2, 2) + Rules.STEPS[direction] * 2, direction + " reaches correct exit")
		check(Rules.is_complete(state) and not Rules.is_stuck(state), "Completed state is not stuck")
		check(original.robots.size() == 1, "State mutation does not change level")
		check(not Rules.apply_action(state, "A").allowed, "Already exited robot cannot act again")
	var level := base_level()
	level.obstacles.append({"x": 2, "y": 1})
	var before := level.duplicate(true)
	var blocked := Rules.apply_action(level, "A")
	check(not blocked.allowed and blocked.reason == "obstacle" and blocked.blocker == Vector2i(2, 1), "Obstacle rejects with position")
	check(level == before, "Rejected move preserves all state")
	check(Rules.is_stuck(level), "Permanent blocker is stuck")
	level = base_level()
	level.exits = [{"x": 0, "y": 0}]
	check(Rules.inspect_action(level, "A").reason == "edge", "Unmarked edge rejects")
	level = base_level()
	level.robots.append({"id": "B", "x": 2, "y": 1, "direction": "UP"})
	check(Rules.valid_actions(level) == ["B"], "Front robot is the only legal move")
	check(Rules.inspect_action(level, "A").reason == "robot", "Robot blocks robot")
	check(Rules.apply_action(level, "B").allowed and Rules.apply_action(level, "A").allowed, "Reusable exit supports dependency chain")
	check(Rules.is_complete(level), "Chain completes")
	level = base_level()
	# Valid perimeter exit encountered before a later obstacle along the ray.
	level.robots[0].x = 0
	level.robots[0].y = 3
	level.exits = [{"x": 0, "y": 1}]
	level.obstacles = [{"x": 0, "y": 0}]
	check(Rules.apply_action(level, "A").allowed, "Path ends at first exit, ignores later obstacle")
	level = base_level("RIGHT")
	level.robots = [{"id": "A", "x": 1, "y": 2, "direction": "RIGHT"}, {"id": "B", "x": 3, "y": 2, "direction": "LEFT"}]
	check(Rules.is_stuck(level), "Facing robots form a deadlock")
	var independent := LevelData.load_file("res://levels/002.json").level as Dictionary
	for order in [["A", "B"], ["B", "A"]]:
		var state := Rules.create_state(independent)
		for id in order:
			check(Rules.apply_action(state, id).allowed, "Independent move remains legal")
		check(Rules.is_complete(state), "Both independent orders complete")

func run_validation() -> void:
	check(LevelData.validate(base_level()).is_empty(), "Valid schema accepted")
	for invalid in [null, [], "level", 2]:
		check(not LevelData.validate(invalid).is_empty(), "Nonobject rejected")
	for field in ["version", "id", "width", "height", "robots", "exits", "obstacles"]:
		var data := base_level()
		data.erase(field)
		check(not LevelData.validate(data).is_empty(), "Missing " + field + " rejected")
	for value in [0, -1, 2.5, "5", 13, true]:
		var data := base_level()
		data.width = value
		check(not LevelData.validate(data).is_empty(), "Invalid width rejected: " + str(value))
	for patch in [{"x": -1}, {"x": 5}, {"x": 4294967298}, {"y": 4294967298}, {"y": 2.5}, {"direction": "NORTH"}, {"id": ""}, {"id": 1}]:
		var data := base_level()
		data.robots[0].merge(patch, true)
		check(not LevelData.validate(data).is_empty(), "Invalid robot rejected: " + str(patch))
	var data := base_level()
	data.robots.append({"id": "A", "x": 1, "y": 1, "direction": "UP"})
	check(not LevelData.validate(data).is_empty(), "Duplicate robot id rejected")
	for collection in ["robots", "obstacles", "exits"]:
		data = base_level()
		data[collection].append({"id": "B", "x": 2, "y": 2, "direction": "UP"})
		check(not LevelData.validate(data).is_empty(), "Overlapping " + collection + " rejected")
	data = base_level()
	data.exits = [{"x": 1, "y": 1}]
	check(not LevelData.validate(data).is_empty(), "Interior exit rejected")
	check(not LevelData.load_file("res://tests/fixtures/missing.json").errors.is_empty(), "Missing file reported")
	check(not LevelData.load_file("res://tests/fixtures/malformed.json").errors.is_empty(), "Malformed JSON reported")

func run_presentation() -> void:
	var game = load("res://game/main.tscn").instantiate()
	# Test state/animation behavior without starting the asynchronous audio mixer.
	game.muted = true
	root.add_child(game)
	await process_frame
	game.activate("A")
	check(game.board.busy and game.state.robots.is_empty(), "Accepted action locks input during animation")
	game.activate("A")
	check(game.state.robots.is_empty(), "Repeated tap does not duplicate move")
	game.load_level(1)
	await create_timer(0.7).timeout
	check(game.state.robots.size() == 1 and not game.board.busy and not game.next_button.visible, "Restart cancels stale completion callback")
	game.load_level(2)
	game.activate("A")
	game.activate("B")
	check(game.state.robots.size() == 1 and game.state.robots[0].id == "B", "Another robot cannot activate during movement")
	await create_timer(0.7).timeout
	game.activate("B")
	check(game.state.robots.is_empty(), "Another robot can activate after movement")
	game.load_level(3)
	game.activate("B")
	check(game.state.robots.size() == 2 and not game.board.busy, "Blocked input does not mutate or lock board")
	game.load_level(1)
	game.activate("A")
	await create_timer(0.7).timeout
	check(game.next_button.visible and not game.board.busy, "Animation completion reveals next control")
	game.advance()
	check(game.level_index == 2 and game.state.robots.size() == 2, "Next loads new level")
	game.queue_free()
	await process_frame
	for failure in failures:
		printerr("FAIL: " + failure)
	print("%d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
