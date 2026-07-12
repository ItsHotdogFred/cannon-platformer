extends Node2D
## One-shot arcade particle burst. Spawns at a world position, emits, then frees.

## Set before add_child() so _ready can tune the emitter first.
var spawn_puff: bool = false

@onready var particles: CPUParticles2D = $CPUParticles2D


func _ready() -> void:
	if spawn_puff:
		_configure_as_spawn_puff()
	particles.finished.connect(queue_free)
	particles.restart()
	particles.emitting = true


## Soft checkpoint re-entry puff (fewer, slower particles).
func _configure_as_spawn_puff() -> void:
	particles.amount = 8
	particles.initial_velocity_min = 12.0
	particles.initial_velocity_max = 40.0
	particles.scale_amount_min = 0.35
	particles.scale_amount_max = 0.7
	particles.explosiveness = 0.85
	particles.color = Color(1.0, 0.95, 0.7, 1.0)
