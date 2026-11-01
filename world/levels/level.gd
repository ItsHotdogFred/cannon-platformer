extends TileMapLayer
class_name Level

@export var camera : Camera2D
@export var LevelParticles : Array[GPUParticles2D]
@export var FragmentParticles : Array[String]
@export var FragmentCanvas : Array[String]

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
	# Within a few pixels, not exact, to match fragment.gd's room check.
	if camera.global_position.distance_to(global_position + offset) < 8.0:
		for particle in LevelParticles:
			particle.emitting = true
	else:
		for particle in LevelParticles:
			particle.emitting = false
