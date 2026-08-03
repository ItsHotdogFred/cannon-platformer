extends Area2D

const SPIKE = preload("uid://c5dq5f1nbpq8b")

var spike : Area2D

func _on_body_exited(body: Node2D) -> void:
	if !spike:
		var new_spike : Area2D = SPIKE.instantiate()
		add_child.call_deferred(new_spike)
		#new_spike.global_rotation = global_rotation
		spike = new_spike
		var tween = get_tree().create_tween()
		var collision_shape: CollisionShape2D = new_spike.get_node("CollisionShape2D")
		collision_shape.disabled = true
		new_spike.get_node("Sprite2D").scale = Vector2(0, 0)
		tween.tween_property(new_spike.get_node("Sprite2D"), "scale", Vector2(1, 1), 0.5)
		tween.tween_callback(func() -> void: collision_shape.disabled = false)
