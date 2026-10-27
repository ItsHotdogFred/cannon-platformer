extends Camera2D

@export var viewport : SubViewportContainer
@export var player : CharacterBody2D

func _physics_process(delta: float) -> void:
	if player.position == Vector2(0,0):
		global_position.x = player.get_parent().global_position.x
	else:
		global_position.x = player.position.x
	# limit_left only clamps the view, not this node, so children (the UI)
	# would drift off screen. Clamp the node itself so they stay put.
	var half_width := get_viewport_rect().size.x / 2.0 / zoom.x
	global_position.x = max(global_position.x, limit_left + half_width)
