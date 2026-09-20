extends Control

const LevelData = preload("res://game/core/level_data.gd")
const Rules = preload("res://game/core/rules.gd")
const Board = preload("res://game/presentation/board.gd")
const LEVEL_COUNT := 5
var level_index := 1
var level: Dictionary = {}
var state: Dictionary = {}
var board: Control
var title_label: Label
var count_label: Label
var status_label: Label
var next_button: Button
var restart_button: Button
var sound_button: Button
var progress_row: HBoxContainer
var content: VBoxContainer
var tween: Tween
var generation := 0
var muted := false
var sounds := {}

func _ready() -> void:
	build_interface()
	for sound_name in ["move", "blocked", "exit", "complete"]:
		var player := AudioStreamPlayer.new()
		player.stream = load("res://game/assets/" + sound_name + ".wav")
		player.volume_db = -12.0
		add_child(player)
		sounds[sound_name] = player
	load_level(1)
	resized.connect(layout_content)
	layout_content.call_deferred()

func label_node(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func button_node(text: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", 17)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for variant in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("9cf2c5") if primary else Color("1b2d3b")
		if variant == "hover":
			style.bg_color = style.bg_color.lightened(0.1)
		if variant == "pressed":
			style.bg_color = style.bg_color.darkened(0.15)
		style.set_corner_radius_all(14)
		style.content_margin_left = 18
		style.content_margin_right = 18
		if variant == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = Color("e5f6fa")
			style.set_border_width_all(2)
		button.add_theme_stylebox_override(variant, style)
	for variant in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(variant, Color("101f2c") if primary else Color("d8e3eb"))
	return button

func build_interface() -> void:
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var brand := label_node("BOT / FLOW", 16, Color("9cf2c5"))
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	header.add_child(label_node("PROTOTYPE  0.1", 11, Color("8097a8")))
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 5)
	content.add_child(heading)
	title_label = label_node("", 38, Color("edf5f7"))
	heading.add_child(title_label)
	count_label = label_node("", 15, Color("93a9b9"))
	heading.add_child(count_label)
	progress_row = HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 6)
	content.add_child(progress_row)
	for index in range(LEVEL_COUNT):
		var bar := ColorRect.new()
		bar.custom_minimum_size.y = 3
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		progress_row.add_child(bar)
	board = Board.new()
	content.add_child(board)
	board.robot_pressed.connect(activate)
	status_label = label_node("", 20, Color("9cf2c5"))
	status_label.custom_minimum_size.y = 28
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(status_label)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	content.add_child(controls)
	restart_button = button_node("Restart")
	restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_button.pressed.connect(func(): load_level(level_index))
	controls.add_child(restart_button)
	sound_button = button_node("Sound on")
	sound_button.pressed.connect(toggle_sound)
	controls.add_child(sound_button)
	next_button = button_node("Next level", true)
	next_button.pressed.connect(advance)
	content.add_child(next_button)
	var footer := label_node("A LITTLE ORDER. A LITTLE SATISFACTION.", 10, Color("617e91"))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(footer)

func layout_content() -> void:
	if not is_instance_valid(content):
		return
	var width := minf(432.0, size.x - 32.0)
	var other_height := content.get_combined_minimum_size().y - board.get_combined_minimum_size().y
	var board_height := minf(width, maxf(150.0, size.y - 32.0 - other_height))
	board.custom_minimum_size = Vector2(width, board_height)
	content.size = Vector2(width, other_height + board_height)
	content.position = Vector2((size.x - width) / 2.0, maxf(16.0, (size.y - other_height - board_height) / 2.0))

func load_level(index: int) -> void:
	generation += 1
	if tween != null:
		tween.kill()
	for player in sounds.values():
		player.stop()
	level_index = index
	var parsed := LevelData.load_file("res://levels/%03d.json" % index)
	if not parsed.errors.is_empty():
		status_label.text = "Level could not load"
		push_error(str(parsed.errors))
		return
	level = parsed.level
	state = Rules.create_state(level)
	board.set_state(state, index == 1)
	title_label.text = "Factory %02d" % index
	status_label.text = ""
	next_button.visible = false
	for position in range(LEVEL_COUNT):
		progress_row.get_child(position).color = Color("9cf2c5") if position < index else Color("273b49")
	update_count()
	layout_content.call_deferred()

func update_count() -> void:
	count_label.text = "%02d / %02d     ·     %d %s remaining" % [level_index, LEVEL_COUNT, state.robots.size(), "bot" if state.robots.size() == 1 else "bots"]

func activate(robot_id: String) -> void:
	if board.busy or Rules.is_complete(state):
		return
	var robot := {}
	for candidate in state.robots:
		if candidate.id == robot_id:
			robot = candidate.duplicate()
	var result := Rules.apply_action(state, robot_id)
	if not result.allowed:
		board.reject(robot_id, result)
		play_sound("blocked")
		return
	board.busy = true
	board.moving_robot = robot
	board.move_to = Vector2(result.exit)
	board.move_progress = 0.0
	play_sound("move")
	var started_generation := generation
	tween = create_tween()
	tween.tween_property(board, "move_progress", 1.0, 0.22 + result.path.size() * 0.075).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func(): finish_move(started_generation))

func finish_move(started_generation: int) -> void:
	if started_generation != generation:
		return
	board.moving_robot = {}
	board.busy = false
	board.queue_redraw()
	update_count()
	if Rules.is_complete(state):
		status_label.text = "All clear!" if level_index < LEVEL_COUNT else "Five factories. All clear."
		next_button.text = "Next level" if level_index < LEVEL_COUNT else "Play again"
		next_button.visible = true
		layout_content.call_deferred()
		play_sound("complete")
	elif Rules.is_stuck(state):
		status_label.text = "No routes left — restart"
		play_sound("blocked")
	else:
		play_sound("exit")

func advance() -> void:
	if Rules.is_complete(state) and not board.busy:
		load_level(level_index + 1 if level_index < LEVEL_COUNT else 1)

func toggle_sound() -> void:
	muted = not muted
	sound_button.text = "Sound off" if muted else "Sound on"
	if muted:
		for player in sounds.values():
			player.stop()

func play_sound(sound_name: String) -> void:
	if not muted:
		sounds[sound_name].play()
