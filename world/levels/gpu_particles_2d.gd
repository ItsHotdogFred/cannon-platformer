extends GPUParticles2D

const DEFAULT_LEVEL_SIZE := Vector2(320.0, 180.0)

var _level_root: Node2D
var _level_bounds := Rect2()
var _player: Node2D
var _camera: Camera2D
var _world_position := Vector2.ZERO
var _outside_subviewport := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_level_root = get_parent() as Node2D
	_level_bounds = _get_level_bounds()
	_world_position = global_position
	call_deferred("_reparent_outside_subviewport")


func _reparent_outside_subviewport() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null or get_parent() == scene_root:
		return

	reparent(scene_root, true)
	# Render between the root background and the SubViewport gameplay texture.
	z_index = -1
	_outside_subviewport = true


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return

	emitting = _level_bounds.has_point(_player.global_position)

	if _outside_subviewport:
		if _camera == null or not is_instance_valid(_camera):
			_camera = get_tree().current_scene.find_child("ScreenCamera", true, false) as Camera2D
		if _camera != null:
			var viewport_center := _camera.get_viewport_rect().size * 0.5
			global_position = _world_position - (_camera.global_position + _camera.offset) + viewport_center


func _get_level_bounds() -> Rect2:
	if _level_root == null:
		return Rect2(global_position, DEFAULT_LEVEL_SIZE)

	if _level_root is TileMapLayer:
		var tile_map := _level_root as TileMapLayer
		if tile_map.tile_set != null:
			var used_rect := tile_map.get_used_rect()
			var tile_size := Vector2(tile_map.tile_set.tile_size)
			return Rect2(
				_level_root.to_global(Vector2(used_rect.position) * tile_size),
				Vector2(used_rect.size) * tile_size
			)

	return Rect2(_level_root.global_position, DEFAULT_LEVEL_SIZE)
