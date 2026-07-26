extends Node
## Arcade death cascade: hitstop flash → particle burst → hold → soft
## respawn at checkpoint → spawn-in tween. Safe to call from
## Area2D.body_entered.

const DEATH_BURST = preload("res://death_burst.tscn")

@export var death_hitstop: float = 0.12
@export var death_hold: float = 0.35
@export var spawn_in_duration: float = 0.22

var body: CharacterBody2D
var sprite: AnimatedSprite2D
var starting_pos: Vector2 = Vector2.ZERO
var set_active: Callable = Callable()
var get_noclip: Callable = Callable()
var is_dying: bool = false


func bind(body: CharacterBody2D, sprite: AnimatedSprite2D, starting_pos: Vector2,
		set_active: Callable, get_noclip: Callable) -> void:
	self.body = body
	self.sprite = sprite
	self.starting_pos = starting_pos
	self.set_active = set_active
	self.get_noclip = get_noclip


## Returns the running sequence coroutine so the caller can await it.
## No-op if already dying (re-entrancy guard for stacked spikes).
func start() -> void:
	if is_dying:
		return
	is_dying = true
	# Keep timers/tweens alive if the camera pauses the tree mid-sequence.
	body.process_mode = Node.PROCESS_MODE_ALWAYS
	_flash_and_burst()
	await _wait(death_hitstop)
	_hide_during_hold()
	await _wait(death_hold)
	await _respawn()
	_spawn_in()
	is_dying = false
	body.process_mode = Node.PROCESS_MODE_INHERIT


## Instant reset (no VFX). Prefer start() for gameplay deaths.
## Caller is responsible for zeroing momentum/velocity before calling.
func reset() -> void:
	body.global_position = starting_pos
	sprite.visible = true
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE
	set_active.call(true)
	is_dying = false
	body.process_mode = Node.PROCESS_MODE_INHERIT


func _flash_and_burst() -> void:
	# Hitstop feel: bright flash while still visible on the spike.
	sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
	_spawn_burst(body.global_position)


func _hide_during_hold() -> void:
	sprite.visible = false
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE


func _respawn() -> void:
	# Soft teleport — camera pans if the checkpoint is on another screen.
	body.global_position = starting_pos
	var cam := body.get_viewport().get_camera_2d()
	if cam != null and cam.has_method("focus_on_player"):
		await cam.focus_on_player()
	_spawn_burst(body.global_position, true)


func _spawn_in() -> void:
	# Scale / fade back in at the checkpoint.
	sprite.visible = true
	sprite.modulate.a = 0.0
	sprite.scale = Vector2(0.4, 0.4)

	var tween := body.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 1.0, spawn_in_duration)
	tween.tween_property(sprite, "scale", Vector2.ONE, spawn_in_duration) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished

	sprite.modulate = Color(1.0, 1.0, 1.0, 0.55) if get_noclip.call() else Color.WHITE
	sprite.scale = Vector2.ONE
	set_active.call(true)


func _spawn_burst(at: Vector2, spawn_puff: bool = false) -> void:
	var burst: Node2D = DEATH_BURST.instantiate()
	if spawn_puff:
		burst.spawn_puff = true
	# Parent first, then play_at so particles never emit at (0,0).
	body.get_tree().current_scene.add_child(burst)
	burst.play_at(at)


func _wait(seconds: float) -> void:
	# process_always + ignore_pause so camera screen-pauses don't stall death.
	await body.get_tree().create_timer(seconds, true, false, true).timeout
