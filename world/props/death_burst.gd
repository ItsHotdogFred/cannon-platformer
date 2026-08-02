extends Node2D

signal rebuild_finished

## The particle resource stores the player mask. The drawn pixels give each
## point an explosion phase followed by its own checkpoint-bound path.

@export var explosion_duration: float = 0.28
@export var rebuild_duration: float = 1.1
@export var pixel_size: float = 1.0

@onready var particles: GPUParticles2D = $GPUParticles2D

var _origin := Vector2.ZERO
var _target := Vector2.ZERO
var _elapsed := 0.0
var _points: Array[Vector2] = []
var _colors: Array[Color] = []


func _ready() -> void:
	# GPU particles cannot steer each masked point to a different destination.
	# Keep the node as the mask source, but render the controllable pixels below.
	particles.emitting = false
	particles.visible = false
	var process_material := particles.process_material as ParticleProcessMaterial
	if process_material == null:
		return
	var point_texture := process_material.emission_point_texture
	var color_texture := process_material.emission_color_texture
	if point_texture == null or color_texture == null:
		return

	var point_image := point_texture.get_image()
	var color_image := color_texture.get_image()
	var count := mini(process_material.emission_point_count, point_image.get_width())
	for index in count:
		var point := point_image.get_pixel(index, 0)
		_points.append(Vector2(point.r, point.g))
		_colors.append(color_image.get_pixel(index, 0))

	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= explosion_duration + rebuild_duration:
		rebuild_finished.emit()
		queue_free()


## Place at the death position and send the masked pixels to the respawn.
func play_at(world_pos: Vector2, rebuild_at: Vector2 = Vector2.INF) -> void:
	global_position = world_pos
	_origin = world_pos
	_target = world_pos if rebuild_at == Vector2.INF else rebuild_at
	_elapsed = 0.0
	queue_redraw()


func set_rebuild_target(world_pos: Vector2) -> void:
	_target = world_pos
	queue_redraw()


func _draw() -> void:
	if _points.is_empty():
		return
	var explosion := clampf(_elapsed / explosion_duration, 0.0, 1.0)
	var travel := clampf((_elapsed - explosion_duration) / rebuild_duration, 0.0, 1.0)
	for index in _points.size():
		# A small stagger makes the player resolve pixel-by-pixel instead of
		# appearing as one rigid sprite at the checkpoint.
		var delay := float(index % 23) / 23.0 * 0.18
		var progress := clampf((travel - delay) / (1.0 - delay), 0.0, 1.0)
		progress = 1.0 - pow(1.0 - progress, 2.0)
		var source := _origin + _points[index]
		var destination := _target + _points[index]
		var explosion_direction := _points[index].normalized()
		if explosion_direction == Vector2.ZERO:
			explosion_direction = Vector2.from_angle(float(index) * 2.39996)
		var exploded := source + explosion_direction * 14.0 * (1.0 - pow(1.0 - explosion, 2.0))
		var pixel_position := exploded.lerp(destination, progress) - global_position
		draw_rect(Rect2(pixel_position, Vector2.ONE * pixel_size), _colors[index])
