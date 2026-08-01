extends TileMapLayer

@export var camera : Camera2D
@export var snow_particles_2d: GPUParticles2D 

func _physics_process(delta: float) -> void:
	var offset : Vector2 = Vector2(160.0, 90)
	if camera.global_position == global_position + offset:
		snow_particles_2d.emitting = true
	else:
		snow_particles_2d.emitting = false
		
