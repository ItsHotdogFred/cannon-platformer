extends StaticBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

func destroy():
	animated_sprite_2d.hide()
	collision_shape_2d.disabled = true
	await get_tree().create_timer(1).timeout
	var tween = get_tree().create_tween()
	animated_sprite_2d.scale = Vector2(0,0)
	animated_sprite_2d.show()
	tween.tween_property(animated_sprite_2d, "scale", Vector2(1,1), 0.5)
	tween.tween_callback(func() -> void:
		collision_shape_2d.disabled = false
	)
