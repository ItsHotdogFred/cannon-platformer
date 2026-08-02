extends GPUParticles2D
class_name BackgroundParticle

@export var HiRes : bool = false

func _ready() -> void:
	if HiRes:
		process_mode = Node.PROCESS_MODE_ALWAYS
		var scene_root := get_tree().current_scene
		if scene_root != null and get_parent() != scene_root:
			reparent.call_deferred(scene_root, true)
			z_index = 999
			#orginal_pos = global_position
			global_position = Vector2(135,-6)
