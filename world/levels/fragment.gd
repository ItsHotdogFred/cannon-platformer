extends Node2D
class_name Fragment

@export var fragment_particles : Dictionary[GPUParticles2D, String]
@export var fragment_canvas : Dictionary[CanvasModulate, String]
@export var camera : Camera2D

var offset : Vector2 = Vector2(160.0, 90)
var levels : Array[Level] = []


func _ready():
	if camera:
		camera.transiton_completed.connect(_on_transiton_completed)
	for node in find_children("*", "Level", true, false):
		if node is Level:
			levels.append(node as Level)
	for particle in fragment_particles:
		if !particle.HiRes:
			particle.process_mode = Node.PROCESS_MODE_ALWAYS
			particle.local_coords = true
			particle.reparent(camera, true)

	check()

func _on_transiton_completed():
	check()

func check():
	var active_level: Level = null
	for level in levels:
		# Within a few pixels, not exact: some levels sit a little off the
		# 320x180 room grid to keep their 8px tiles lined up (e.g. Level_13).
		if camera and camera.global_position.distance_to(level.global_position + offset) < 8.0:
			active_level = level
			break

	for particle in fragment_particles:
		var particle_name: String = fragment_particles[particle]
		if active_level != null and particle_name in active_level.FragmentParticles:
			particle.emitting = true
		else:
			particle.emitting = false

	for canvas in fragment_canvas:
		var canvas_name: String = fragment_canvas[canvas]
		canvas.visible = active_level != null and canvas_name in active_level.FragmentCanvas
