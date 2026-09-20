extends Control
## One board view. Hit testing uses the same layout as drawing, never physics.

signal robot_pressed(robot_id: String)

const Rules = preload("res://game/core/rules.gd")
const INK := Color("101f2c")
const MINT := Color("9cf2c5")
const CORAL := Color("ff8b79")
var state: Dictionary = {}
var moving_robot: Dictionary = {}
var move_to := Vector2.ZERO
var move_progress := 0.0
var rejected_id := ""
var rejection_time := 0.0
var blocker := Vector2i(-99, -99)
var elapsed := 0.0
var first_level := false
var busy := false

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	elapsed += delta
	var rejection_was_active := rejection_time > 0.0
	rejection_time = maxf(0.0, rejection_time - delta)
	if first_level or busy or rejection_was_active:
		queue_redraw()

func set_state(value: Dictionary, pulse: bool) -> void:
	state = value
	first_level = pulse
	moving_robot = {}
	move_progress = 0.0
	rejection_time = 0.0
	busy = false
	queue_redraw()

func reject(robot_id: String, result: Dictionary) -> void:
	rejected_id = robot_id
	blocker = result.get("blocker", Vector2i(-99, -99))
	rejection_time = 0.45
	queue_redraw()

func cell_size() -> float:
	if state.is_empty():
		return 1.0
	return minf(size.x / float(state.width), size.y / float(state.height))

func origin() -> Vector2:
	return (size - Vector2(state.width, state.height) * cell_size()) / 2.0

func center(position: Vector2) -> Vector2:
	return origin() + (position + Vector2(0.5, 0.5)) * cell_size()

func _gui_input(event: InputEvent) -> void:
	# Touch is converted to mouse by the project setting; do not handle it twice.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not busy and not state.is_empty():
		var local: Vector2 = (event.position - origin()) / cell_size()
		var selected := Vector2i(floori(local.x), floori(local.y))
		for robot in state.robots:
			if Rules.cell(robot) == selected:
				robot_pressed.emit(robot.id)
				accept_event()
				return

func rounded(rect: Rect2, color: Color, radius: int = 12, border: Color = Color.TRANSPARENT) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0 else 0)
	draw_style_box(style, rect)

func arrow(at: Vector2, direction: Vector2, scale_value: float, color: Color) -> void:
	var side := Vector2(-direction.y, direction.x)
	draw_line(at - direction * scale_value * 0.48, at + direction * scale_value * 0.45, color, 3.0, true)
	draw_polyline(PackedVector2Array([at + direction * scale_value * 0.05 + side * scale_value * 0.4, at + direction * scale_value * 0.48, at + direction * scale_value * 0.05 - side * scale_value * 0.4]), color, 3.0, true)

func _draw() -> void:
	if state.is_empty():
		return
	var unit := cell_size()
	for y in range(state.height):
		for x in range(state.width):
			var rect := Rect2(origin() + Vector2(x, y) * unit + Vector2(3, 3), Vector2.ONE * (unit - 6))
			rounded(rect, Color("142431"), 10, Color("203342"))
			draw_circle(rect.position + Vector2(8, 8), 1.3, Color("314451"))
	for gate in state.exits:
		var at := center(Vector2(gate.x, gate.y))
		rounded(Rect2(at - Vector2.ONE * unit * 0.43, Vector2.ONE * unit * 0.86), Color("204f44"), 12, MINT)
		var outward := Vector2.UP
		if gate.y == state.height - 1:
			outward = Vector2.DOWN
		elif gate.x == 0:
			outward = Vector2.LEFT
		elif gate.x == state.width - 1:
			outward = Vector2.RIGHT
		arrow(at, outward, unit * 0.35, MINT)
		draw_line(at - outward * unit * 0.3 + Vector2(-outward.y, outward.x) * unit * 0.17, at - outward * unit * 0.3 - Vector2(-outward.y, outward.x) * unit * 0.17, MINT, 2.0, true)
	for obstacle in state.obstacles:
		var at := center(Vector2(obstacle.x, obstacle.y))
		rounded(Rect2(at - Vector2.ONE * unit * 0.38, Vector2.ONE * unit * 0.76), Color("52606b"), 8, Color("77828a"))
		for offset in [-0.17, 0.0, 0.17]:
			draw_line(at + Vector2(-0.19, offset - 0.09) * unit, at + Vector2(0.19, offset + 0.09) * unit, Color("283744"), 5.0, true)
	for robot in state.robots:
		paint_robot(robot, center(Vector2(robot.x, robot.y)), 1.0)
	if not moving_robot.is_empty():
		var start := Vector2(moving_robot.x, moving_robot.y)
		paint_robot(moving_robot, center(start.lerp(move_to, move_progress)), 1.0 - maxf(0.0, move_progress - 0.8) * 5.0)
	if rejection_time > 0.0:
		draw_rect(Rect2(center(Vector2(blocker)) - Vector2.ONE * unit * 0.43, Vector2.ONE * unit * 0.86), CORAL, false, 3.0)

func paint_robot(robot: Dictionary, at: Vector2, opacity: float) -> void:
	var unit := cell_size()
	var direction: Vector2 = Vector2(Rules.STEPS[robot.direction])
	if robot.id == rejected_id and rejection_time > 0:
		at += direction * sin(rejection_time * 65.0) * 5.0
	var body := Color("f4cb78")
	if robot.id == rejected_id and rejection_time > 0:
		body = CORAL
	body.a = opacity
	if first_level and not busy:
		draw_arc(at, unit * (0.43 + sin(elapsed * 3.5) * 0.025), 0.0, TAU, 48, Color(0.96, 0.8, 0.47, 0.3 + sin(elapsed * 3.5) * 0.12), 2.0, true)
	var shadow := Color(0.02, 0.04, 0.06, opacity * 0.65)
	rounded(Rect2(at - Vector2.ONE * unit * 0.34 + Vector2(0, 4), Vector2.ONE * unit * 0.68), shadow, 14)
	rounded(Rect2(at - Vector2.ONE * unit * 0.34, Vector2.ONE * unit * 0.68), body, 14)
	var dark := INK
	dark.a = opacity
	arrow(at + direction * unit * 0.03, direction, unit * 0.38, dark)
	var side := Vector2(-direction.y, direction.x)
	for offset in [-1, 1]:
		draw_circle(at - direction * unit * 0.22 + side * unit * 0.12 * offset, unit * 0.025, dark)
