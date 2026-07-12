extends CharacterBody2D

@export var speed: float = 150.0
@export var friction: float = 50# 500.0

@export_group("Death")
@export var death_hitstop: float = 0.12
@export var death_hold: float = 0.35
@export var spawn_in_duration: float = 0.22

@onready var ray_cast_2d: RayCast2D = $RayCast2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var shoot_time: Timer = $ShootTime
@onready var sprite: AnimatedSprite2D = $Sprite

const GRAPPLING_HOOK = preload("uid://dum12y78crq6f")
const DEATH_BURST = preload("res://death_burst.tscn")

var starting_pos : Vector2

var can_shoot = true
## Active hook instance while swinging; null when free.
var active_grappling_hook: Node2D = null
## True while the arcade death sequence is playing (blocks re-entry).
var is_dying: bool = false


# Persistent movement state. The player has no walk input - all motion
# comes from cannon recoil, so `momentum` is the single source of truth
# for movement. `velocity` is driven from it each frame and synced back
# after move_and_slide() so collisions (landing / hitting a wall) reset
# the matching momentum component.
var momentum : Vector2

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
	add_to_group("player")
	starting_pos = global_position
	Gamemanager.player = self

func _physics_process(delta: float) -> void:
	if is_dying:
		return

	_set_ray_cast_direction()
	# Fire: launch the player opposite the cursor (recoil). Each shot adds a
	# fresh impulse to momentum instead of accumulating a never-decayed unit
	# vector, which is what let old vertical momentum bleed into later shots.
	# Skip fire if the click landed on UI (e.g. sound toggle) — Input still
	# reports the action even when a Control already handled the event.
	if Input.is_action_just_pressed("shoot") and can_shoot \
			and get_viewport().gui_get_hovered_control() == null:
		var mouse_pos = get_global_mouse_position()
		var direction: Vector2 = (mouse_pos - global_position).normalized()
		momentum += -direction * speed
		can_shoot = false
		shoot_time.start()
		$AudioStreamPlayer2D.play()
	
	if Input.is_action_just_pressed("interaction"):
		_use_grappling_hook()
		return

	# Horizontal momentum bleeds off over time. This now uses the `friction`
	# export (previously a hardcoded 10.0; the export did nothing). Vertical
	# momentum is NOT damped so cannon launches follow a natural gravity arc.

	# Gravity only acts while airborne.
	if not is_on_floor():
		momentum.y += (gravity / 4.0) * delta
		friction = 50
	else:
		friction = 500

	momentum.x = move_toward(momentum.x, 0.0, friction * delta)
	

	velocity = momentum
	move_and_slide()
	# Sync momentum from the post-collision velocity so landing zeroes the
	# vertical momentum and hitting a wall zeroes the horizontal momentum.
	momentum = velocity
	
	if global_position > get_global_mouse_position():
		sprite.flip_h = true
	else:
		sprite.flip_h = false
	
func _set_ray_cast_direction():
	var mouse_pos := get_global_mouse_position()
	# Point the ray at the cursor and make it long enough to reach the click.
	ray_cast_2d.target_position = ray_cast_2d.to_local(mouse_pos)

func _use_grappling_hook():
	if is_dying:
		return
	if not ray_cast_2d.is_colliding(): return
	# Don't stack hooks if somehow already attached.
	if active_grappling_hook != null and is_instance_valid(active_grappling_hook):
		return
	
	set_active(false)
	
	var grapplingHookNode = GRAPPLING_HOOK.instantiate()
	get_tree().current_scene.add_child(grapplingHookNode)
	active_grappling_hook = grapplingHookNode
	grapplingHookNode.start_hook(ray_cast_2d.get_collision_point())

## Tear down an active grapple without starting a new one.
## reactivate_player: false during death so force_release doesn't re-enable physics.
func cancel_grappling_hook(reactivate_player: bool = true) -> void:
	if active_grappling_hook != null and is_instance_valid(active_grappling_hook):
		active_grappling_hook.force_release(reactivate_player)
	active_grappling_hook = null

func clear_grappling_hook(hook: Node2D = null) -> void:
	if hook == null or active_grappling_hook == hook:
		active_grappling_hook = null

## Arcade death: hitstop flash → particle burst → hold → soft respawn at checkpoint.
## Safe to call from Area2D.body_entered.
func die() -> void:
	if is_dying:
		return
	is_dying = true
	# Keep timers/tweens alive if the camera pauses the tree mid-sequence.
	process_mode = Node.PROCESS_MODE_ALWAYS

	cancel_grappling_hook(false)
	momentum = Vector2.ZERO
	velocity = Vector2.ZERO
	set_active(false)

	var death_pos := global_position
	var cam := get_viewport().get_camera_2d()

	# Hitstop feel: bright flash + shake while still visible on the spike.
	sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)
	if cam != null and cam.has_method("shake"):
		cam.shake(death_hitstop + 0.05, 2.5)

	_spawn_burst(death_pos)

	await _death_wait(death_hitstop)

	sprite.visible = false
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE

	await _death_wait(death_hold)

	# Soft teleport — camera pans if the checkpoint is on another screen.
	global_position = starting_pos
	momentum = Vector2.ZERO
	velocity = Vector2.ZERO

	if cam != null and cam.has_method("focus_on_player"):
		await cam.focus_on_player()

	_spawn_burst(global_position, true)

	# Scale / fade back in at the checkpoint.
	sprite.visible = true
	sprite.modulate.a = 0.0
	sprite.scale = Vector2(0.4, 0.4)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 1.0, spawn_in_duration)
	tween.tween_property(sprite, "scale", Vector2.ONE, spawn_in_duration) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished

	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE
	set_active(true)
	process_mode = Node.PROCESS_MODE_INHERIT
	is_dying = false


## Instant reset (no VFX). Prefer die() for gameplay deaths.
func respawn() -> void:
	cancel_grappling_hook(false)
	global_position = starting_pos
	momentum = Vector2.ZERO
	velocity = Vector2.ZERO
	sprite.visible = true
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE
	set_active(true)
	is_dying = false
	process_mode = Node.PROCESS_MODE_INHERIT


func set_active(boolean: bool):
	set_physics_process(boolean)
	# Must be deferred: spike death runs from Area2D.body_entered (physics
	# callback), and changing shape.disabled inline is ignored/unsafe there.
	collision_shape_2d.set_deferred("disabled", not boolean)


func _spawn_burst(at: Vector2, spawn_puff: bool = false) -> void:
	var burst: Node2D = DEATH_BURST.instantiate()
	if spawn_puff:
		burst.spawn_puff = true
	# Parent first so _ready runs with spawn_puff already set.
	get_tree().current_scene.add_child(burst)
	burst.global_position = at


func _death_wait(seconds: float) -> void:
	# process_always + ignore_pause so camera screen-pauses don't stall death.
	await get_tree().create_timer(seconds, true, false, true).timeout


func _on_shoot_time_timeout() -> void:
	can_shoot = true
