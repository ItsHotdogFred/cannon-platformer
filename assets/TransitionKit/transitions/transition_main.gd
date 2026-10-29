extends TransitionRect

@onready var label: Label = $Label
@onready var label_2: Label = $Label2

@export var text_fade_time: float = 1.0
@export var text_hold_time: float = 2.0

@export var next_scene : PackedScene

var editable_falling_points : Array[Node2D]

var first_time : bool = true

var times : int = 0 

func _ready() -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(self.material, "shader_parameter/factor", 1.0, 1)
	await get_tree().create_timer(1.25).timeout
	fade_in_text()

func fade_in_text() -> void:
	for l in [label, label_2]:
		l.modulate.a = 0.0
		l.show()
	var text_tween = create_tween().set_parallel()
	text_tween.tween_property(label, "modulate:a", 1.0, text_fade_time)
	text_tween.tween_property(label_2, "modulate:a", 1.0, text_fade_time)
	await text_tween.finished
	await get_tree().create_timer(text_hold_time).timeout

	var player = get_tree().get_first_node_in_group("player")
	var falling_down := get_tree().current_scene.find_child("Fallingdown", true, false) as Node2D
	if player == null or falling_down == null:
		push_error("transition_main: couldn't find Player or Fallingdown")
		return
	player.global_position = falling_down.global_position
	player.falling = true
	# Stop smooth_camera.gd from following the player and centre it on the fall area
	var camera : Camera2D = get_tree().get_first_node_in_group("grapple_screen_camera")
	camera.set_physics_process(false)
	camera.global_position = falling_down.global_position
	await fade_out_text()
	var falling_points : Array[Node2D]
	for child in falling_down.get_children():
		falling_points.append(child)
	if first_time == true:
		first_time = false
		editable_falling_points = falling_points.duplicate()
	while times < 3:
		var next_pos = editable_falling_points.pick_random()

		var player_tween = create_tween().set_parallel()
		player_tween.tween_property(player, "position", next_pos.global_position, 2)

		await player_tween.finished
		
		editable_falling_points.erase(next_pos)
		if editable_falling_points.is_empty():
			editable_falling_points = falling_points.duplicate()
		
		times += 1

	# Cover the screen again so the scene swap isn't visible
	var cover = create_tween()
	cover.tween_property(self.material, "shader_parameter/factor", 1.0, 1)
	await cover.finished
	get_tree().change_scene_to_packed(next_scene)

	
	
func fade_out_text() -> void:
	var text_tween = create_tween().set_parallel()
	text_tween.tween_property(label, "modulate:a", 0, text_fade_time)
	text_tween.tween_property(label_2, "modulate:a", 0, text_fade_time)
	await text_tween.finished
	var tween = get_tree().create_tween()
	tween.tween_property(self.material, "shader_parameter/factor", 0, 1)
	await tween.finished
	
	
	
