extends StaticBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@export var empty_node : AnimatedSprite2D

const ICY_BLOCK_SPRITEFRAMES = preload("uid://dcmwa4isi1kwm")

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
		var new_sprite : AnimatedSprite2D = AnimatedSprite2D.new()
		new_sprite.sprite_frames = ICY_BLOCK_SPRITEFRAMES
		new_sprite.animation = "default"
		new_sprite.frame = 2
		add_child(new_sprite)
		new_sprite.global_position = starting_pos
		new_sprite.top_level = true
		new_sprite.z_index = 999
		empty_node = new_sprite
		await get_tree().create_timer(1).timeout
		going_down = false
		new_sprite.queue_free()
		animated_sprite_2d.frame = 0
		global_position = starting_pos
		
		
		
		
func _physics_process(delta: float) -> void:
	if going_down:
		global_position.y += 30 * delta
