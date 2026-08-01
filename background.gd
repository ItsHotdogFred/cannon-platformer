extends Node2D

## The background is intentionally outside the SubViewport so it can render
## behind the viewport texture. Mirror the SubViewport camera here because
## Parallax2D only tracks cameras in its own viewport.

@export var camera_path: NodePath = NodePath("../SubViewportContainer/SubViewport/ScreenCamera")

var _camera: Camera2D
var _camera_origin := Vector2.ZERO
var _origin_set := false
var _layers: Array[Parallax2D] = []
var _base_positions: Array[Vector2] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for child in get_children():
		if child is Parallax2D:
			_layers.append(child)
			_base_positions.append(child.position)


func _process(_delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_node_or_null(camera_path) as Camera2D
		if _camera == null:
			return

	var camera_position := _camera.global_position + _camera.offset
	if not _origin_set:
		_camera_origin = camera_position
		_origin_set = true

	var camera_delta := camera_position - _camera_origin
	for index in _layers.size():
		_layers[index].position = _base_positions[index] - camera_delta * _layers[index].scroll_scale
