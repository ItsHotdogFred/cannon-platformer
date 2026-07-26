extends AnimatableBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var animated_sprite_2d_empty: AnimatedSprite2D = $Area2D/AnimatedSprite2D

var going_down : bool = false

var starting_pos : Vector2

func _ready() -> void:
	starting_pos = global_position
	animated_sprite_2d.frame = 0

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		animated_sprite_2d.frame = 1
		await get_tree().create_timer(1).timeout
		going_down = true
		await get_tree().create_timer(3).timeout
		going_down = false
		animated_sprite_2d.frame = 0
		global_position = starting_pos
		var tween = get_tree().create_tween()
		animated_sprite_2d.scale = Vector2(0,0)
		tween.tween_property(animated_sprite_2d, "scale", Vector2(1,1), 0.5)
		
		
		
		
func _physics_process(delta: float) -> void:
	if going_down:
		global_position.y += 50 * delta
		animated_sprite_2d_empty.show()
		animated_sprite_2d_empty.global_position = starting_pos
		return
	animated_sprite_2d_empty.hide()
	
		
