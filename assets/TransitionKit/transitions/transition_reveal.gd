extends TransitionRect
## Starts fully covered and fades away to reveal the scene, then removes itself.

@export var reveal_time: float = 1.0

func _ready() -> void:
	# Show ourselves in-game even if hidden in the editor (handy for level
	# editing, since we'd otherwise cover the whole screen there).
	show()
	material.set_shader_parameter("factor", 1.0)
	var tween = create_tween()
	tween.tween_property(material, "shader_parameter/factor", 0.0, reveal_time)
	await tween.finished
	queue_free()
