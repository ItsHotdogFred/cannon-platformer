extends Node
## Arcade death cascade: hitstop → particle burst → hold → soft
## respawn at checkpoint. Safe to call from
## Area2D.body_entered.

const DEATH_BURST = preload("res://world/props/death_burst.tscn")

@export var death_hitstop: float = 0.12
@export var death_hold: float = 0.35

var body: CharacterBody2D
var sprite: AnimatedSprite2D
var starting_pos: Vector2 = Vector2.ZERO
var set_active: Callable = Callable()
var get_noclip: Callable = Callable()
var is_dying: bool = false
var active_burst: Node


func bind(body: CharacterBody2D, sprite: AnimatedSprite2D, _starting_pos: Vector2,
		set_active: Callable, get_noclip: Callable) -> void:
	self.body = body
	self.sprite = sprite
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
	body.global_position = body.starting_pos
	sprite.visible = true
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE
	set_active.call(true)
	is_dying = false
	body.process_mode = Node.PROCESS_MODE_INHERIT


func _flash_and_burst() -> void:
	_spawn_burst(body.global_position, body.starting_pos)


func _hide_during_hold() -> void:
	sprite.visible = false
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE


func _respawn() -> void:
	# Read the player's live starting_pos (updated by checkpoints), not our cached copy.
	body.global_position = body.starting_pos
	if is_instance_valid(active_burst) and active_burst.has_method("set_rebuild_target"):
		active_burst.set_rebuild_target(body.global_position)
	var cam := body.get_viewport().get_camera_2d()
	if cam != null and cam.has_method("focus_on_player"):
		await cam.focus_on_player()
	if is_instance_valid(active_burst):
		await active_burst.rebuild_finished


func _spawn_in() -> void:
	# Reappear without changing the player's visual properties.
	sprite.visible = true
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.55) if get_noclip.call() else Color.WHITE
	sprite.scale = Vector2.ONE
	set_active.call(true)


func _spawn_burst(at: Vector2, rebuild_at: Vector2) -> void:
	var burst: Node2D = DEATH_BURST.instantiate()
	# The player lives in a SubViewport; keep the burst in that same world.
	# Parent first, then play_at so particles never emit at (0,0).
	body.get_parent().add_child(burst)
	active_burst = burst
	burst.play_at(at, rebuild_at)


func _wait(seconds: float) -> void:
	# process_always + ignore_pause so camera screen-pauses don't stall death.
	await body.get_tree().create_timer(seconds, true, false, true).timeout
