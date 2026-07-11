extends Camera2D

## Metroidvania-style screen camera.
## Stays fixed on the current room (one full viewport). When the player leaves
## that room, the camera slides to the adjacent screen. Gameplay is paused for
## the duration of the slide so the player can't fall through the next room
## mid-transition (classic Super Metroid feel).

@export var transition_duration: float = 0.35

var screen_size: Vector2
var current_screen: Vector2i = Vector2i.ZERO
var is_transitioning: bool = false
var player: Node2D


func _ready() -> void:
	# Keep running while the tree is paused during a screen transition.
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen_size = get_viewport_rect().size
	make_current()
	call_deferred("_init_on_player")


func _init_on_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	_snap_to_player_screen()


func _physics_process(_delta: float) -> void:
	if is_transitioning:
		return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
		if player == null:
			return
		_snap_to_player_screen()
		return

	var player_screen := _get_screen_for_position(player.global_position)
	if player_screen != current_screen:
		_transition_to_screen(player_screen)


func _get_screen_for_position(pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(pos.x / screen_size.x),
		floori(pos.y / screen_size.y)
	)


func _screen_to_camera_center(screen: Vector2i) -> Vector2:
	# Default Camera2D anchor is the center of the view.
	return Vector2(
		screen.x * screen_size.x + screen_size.x * 0.5,
		screen.y * screen_size.y + screen_size.y * 0.5
	)


func _snap_to_player_screen() -> void:
	if player == null:
		return
	current_screen = _get_screen_for_position(player.global_position)
	global_position = _screen_to_camera_center(current_screen)


func _transition_to_screen(screen: Vector2i) -> void:
	if is_transitioning:
		return

	is_transitioning = true
	current_screen = screen
	var target := _screen_to_camera_center(screen)

	# Pause the whole scene (player, grappling physics, spikes, etc.)
	# while the camera pans. This node stays awake via PROCESS_MODE_ALWAYS.
	get_tree().paused = true
	player.velocity = Vector2(0,0)
	player.momentum = Vector2(0,0)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", target, transition_duration)
	await tween.finished

	global_position = target
	get_tree().paused = false
	is_transitioning = false

	# If the player is already past the new edge (rare), chain another pan.
	if player != null and is_instance_valid(player):
		var next_screen := _get_screen_for_position(player.global_position)
		if next_screen != current_screen:
			_transition_to_screen(next_screen)
