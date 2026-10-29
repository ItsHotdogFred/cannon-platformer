extends Area2D

@export var Transition : PackedScene

var triggered := false

func _on_body_entered(body: Node2D) -> void:
	print("WDA")
	if body is CharacterBody2D and not triggered:
		triggered = true
		var layer := CanvasLayer.new()
		layer.layer = 10
		add_child(layer)
		var trans = Transition.instantiate()
		layer.add_child(trans)
