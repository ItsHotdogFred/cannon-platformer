extends Node2D
## Follows the mouse and draws a reload progress wheel.

@export var radius: float = 6.0
@export var thickness: float = 2.0
@export var color_ready: Color = Color.WHITE
@export var color_charge: Color = Color(1.0, 1.0, 1.0, 0.6)
@export var color_bg: Color = Color(0.25, 0.25, 0.25, 0.4)
@export var player: Node2D

var shoot_timer: Timer


func _ready() -> void:
	# The camera pauses gameplay during room transitions, but the cursor should
	# remain visible and pinned to the viewport mouse position.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		shoot_timer = player.get_node_or_null("ShootTime") as Timer


func _process(_delta: float) -> void:
	# CursorIndicator is a child of ScreenCamera, whose origin is the center
	# of the gameplay viewport. Keep the wheel in camera-local screen space.
	position = (get_viewport().get_mouse_position()
		- get_viewport_rect().size * 0.5).round()
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(shoot_timer):
		return

	var progress: float = 1.0
	if not shoot_timer.is_stopped():
		progress = 1.0 - (shoot_timer.time_left / shoot_timer.wait_time)

	draw_arc(Vector2.ZERO, radius, 0, TAU, 16, color_bg, thickness)

	var sweep := TAU * progress
	if sweep > 0.01:
		var from := -PI / 2.0
		draw_arc(Vector2.ZERO, radius, from, from + sweep, 16,
				color_ready if progress >= 0.99 else color_charge, thickness)
