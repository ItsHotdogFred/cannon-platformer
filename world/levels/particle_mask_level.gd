@tool
extends TileMapLayer

const MASK_SIZE := Vector2i(320, 180)

@export var camera: Camera2D
@export var snow_particles_2d: GPUParticles2D
@export var particle_mask: Texture2D
@export_tool_button("Generate Particle Mask", "Callable") var generate_particle_mask_action = generate_particle_mask

var _mask_path: String


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mask_path = _get_mask_path()
	if Engine.is_editor_hint():
		return

	if snow_particles_2d == null:
		snow_particles_2d = find_child("GPUParticles2D", true, false) as GPUParticles2D
		if snow_particles_2d == null:
			snow_particles_2d = find_child("SnowParticles2D", true, false) as GPUParticles2D
	if particle_mask == null:
		particle_mask = _build_runtime_mask()
	_apply_active_mask()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if camera == null:
		camera = get_tree().get_first_node_in_group("grapple_screen_camera") as Camera2D
	if camera == null:
		return

	var active := camera.global_position == global_position + Vector2(160.0, 90.0)
	# Keep particles emitting while switching the active room's mask.
	#snow_particles_2d.emitting = active
	if active:
		_apply_active_mask()


func generate_particle_mask() -> void:
	if not Engine.is_editor_hint() or tile_set == null:
		return

	var image := _build_mask_image()
	var error := image.save_png(_get_mask_path())
	if error != OK:
		push_error("Could not save particle mask: %s" % error)
		return

	particle_mask = load(_get_mask_path())
	notify_property_list_changed()


func _apply_active_mask() -> void:
	if particle_mask == null:
		return
	var particles := get_tree().get_nodes_in_group("particle_mask_particles")
	if particles.is_empty() and snow_particles_2d != null:
		particles = [snow_particles_2d]
	for particle in particles:
		particle.set_mask_texture(particle_mask)


func _build_runtime_mask() -> Texture2D:
	return ImageTexture.create_from_image(_build_mask_image())


func _build_mask_image() -> Image:
	var image := Image.create(MASK_SIZE.x, MASK_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var tile_size := Vector2(tile_set.tile_size)

	for cell in get_used_cells():
		var center := map_to_local(cell)
		var top_left := (center - tile_size * 0.5).floor()
		var start := Vector2i(top_left)
		var end := start + Vector2i(tile_size)
		for y in range(start.y, end.y):
			for x in range(start.x, end.x):
				if Rect2i(Vector2i.ZERO, MASK_SIZE).has_point(Vector2i(x, y)):
					image.set_pixel(x, y, Color.WHITE)

	return image


func _get_mask_path() -> String:
	var level_name := scene_file_path.get_file().get_basename()
	return "res://world/levels/%s_particle_mask.png" % level_name
