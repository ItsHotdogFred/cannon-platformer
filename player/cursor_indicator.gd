extends Node2D
## Follows the mouse and draws a reload progress wheel.

@export var radius: float = 6.0
@export var thickness: float = 2.0
@export var color_ready: Color = Color.WHITE
@export var color_charge: Color = Color(1.0, 1.0, 1.0, 0.6)
@export var color_bg: Color = Color(0.25, 0.25, 0.25, 0.4)

var shoot_timer: Timer


func bind(timer: Timer) -> void:
	shoot_timer = timer


func _process(_delta: float) -> void:
	global_position = get_global_mouse_position().round()
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
