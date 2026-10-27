extends Area2D

@export var push_force: float = 14.0

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body is CharacterBody2D:
			body.momentum.y -= push_force
