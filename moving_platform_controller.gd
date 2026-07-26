extends Node2D

@export var moving_platform : PackedScene

@export var speed : float = 25.0

var current_platform : AnimatableBody2D

var next_point : int = 1

var points : Array[Node2D]

func _ready() -> void:
	for child in get_children():
		points.append(child)
	points.sort_custom(func(a, b): return a.name.to_int() < b.name.to_int())
	var platform : AnimatableBody2D = moving_platform.instantiate()
	platform.global_position = points[0].global_position
	
	add_child(platform)
	current_platform = platform
	
func _physics_process(delta: float) -> void:
	current_platform.global_position = current_platform.global_position.move_toward(
		points[next_point].global_position, speed * delta
	)
	if current_platform.global_position.distance_to(points[next_point].global_position) < 1:
		next_point = (next_point + 1) % points.size()
