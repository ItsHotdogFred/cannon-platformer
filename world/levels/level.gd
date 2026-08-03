extends TileMapLayer
class_name Level

@export var camera : Camera2D
@export var LevelParticles : Array[GPUParticles2D]
@export var FragmentParticles : Array[String]

func _ready():
	var fragment := get_parent()
	if fragment == null:
		return
	camera = fragment.get("camera") as Camera2D
	if camera == null:
		return
	camera.transiton_completed.connect(_on_transiton_completed)
	check()

func _on_transiton_completed():
	check()

func check():
	var offset : Vector2 = Vector2(160.0, 90)
	if camera.global_position == global_position + offset:
		for particle in LevelParticles:
			particle.emitting = true
	else:
		for particle in LevelParticles:
			particle.emitting = false
