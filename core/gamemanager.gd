extends Node

var player : CharacterBody2D
var starLabel : Label
var stars : int = 0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
