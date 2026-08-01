extends GPUParticles2D

#var orginal_pos : Vector2

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var scene_root := get_tree().current_scene
	if scene_root != null and get_parent() != scene_root:
		reparent.call_deferred(scene_root, true)
		z_index = 999
		#orginal_pos = global_position
		global_position = Vector2(135,-6)

func _process(delta: float) -> void:
	#var parent = get_parent()
	#if parent:
		#global_position =- parent.camera.global_position + Vector2(160, 90) + orginal_pos
		#print(global_position)
	pass
