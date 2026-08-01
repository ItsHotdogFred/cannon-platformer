extends Node2D

@export var camera : Camera2D

func _ready():
	# Default window size via DisplayServer (more reliable on Wayland than
	# project overrides alone). Leave resize enabled so maximize works.
	DisplayServer.window_set_min_size(Vector2i(320, 180))
	DisplayServer.window_set_size(Vector2i(960, 540))
