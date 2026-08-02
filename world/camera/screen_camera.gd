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

var _shake_time: float = 0.0
var _shake_intensity: float = 0.0

signal transiton_completed

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


func _process(delta: float) -> void:
	if _shake_time <= 0.0:
		return
	_shake_time = maxf(0.0, _shake_time - delta)
	# Decay intensity as the timer runs out.
	var strength := _shake_intensity * clampf(_shake_time / 0.12, 0.0, 1.0)
	offset = Vector2(
		randf_range(-strength, strength),
		randf_range(-strength, strength)
	)
	if _shake_time <= 0.0:
		offset = Vector2.ZERO
		_shake_intensity = 0.0


func _physics_process(_delta: float) -> void:
	if is_transitioning:
		return

	# Hold camera on the death scene while the burst plays.
	if player != null and is_instance_valid(player) \
			and player.get("is_dying") == true:
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


## Pixel-friendly screen shake (Camera2D.offset). duration in seconds.
func shake(duration: float = 0.15, intensity: float = 2.5) -> void:
	_shake_time = duration
	_shake_intensity = intensity


## After a soft respawn: pan (or snap) to the player's new screen.
func focus_on_player() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return

	var target_screen := _get_screen_for_position(player.global_position)
	if target_screen == current_screen:
		return

	await _transition_to_screen(target_screen)


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
	if player != null and is_instance_valid(player):
		player.velocity = Vector2(0, 0)
		player.momentum = Vector2(0, 0)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", target, transition_duration)
	await tween.finished

	global_position = target
	get_tree().paused = false
	transiton_completed.emit()
	is_transitioning = false

	# If the player is already past the new edge (rare), chain another pan.
	if player != null and is_instance_valid(player):
		var next_screen := _get_screen_for_position(player.global_position)
		if next_screen != current_screen:
			await _transition_to_screen(next_screen)
