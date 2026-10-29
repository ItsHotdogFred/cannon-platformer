extends Node
## Cannon recoil + friction + gravity + collision. Owns `momentum` and the
## `set_active` deferral rule. The player script drives this every physics
## frame; it does not read input on its own.

@export var speed: float = 200.0
@export var friction_air: float = 50.0
@export var friction_ground: float = 500.0
## Multiplier on the project gravity. The cannon arc wants a floaty feel.
@export var gravity_scale: float = 0.50

var body: CharacterBody2D
var sprite: AnimatedSprite2D
var collision_shape: CollisionShape2D
var shoot_timer: Timer

## Persistent movement state. The player has no walk input - all motion comes
## from cannon recoil, so momentum is the single source of truth.
var momentum: Vector2 = Vector2.ZERO

var _can_shoot: bool = true
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _noclip: bool = false


func bind(body: CharacterBody2D, sprite: AnimatedSprite2D,
		collision_shape: CollisionShape2D, shoot_timer: Timer) -> void:
	self.body = body
	self.sprite = sprite
	self.collision_shape = collision_shape
	self.shoot_timer = shoot_timer
	shoot_timer.timeout.connect(func (): _can_shoot = true)

func jump():
	momentum.y = -200
	


func is_noclip() -> bool:
	return _noclip


func set_noclip(value: bool) -> void:
	_noclip = value
	momentum = Vector2.ZERO
	body.velocity = Vector2.ZERO
	# Deferred: changing shape.disabled inline from physics callbacks is ignored.
	collision_shape.set_deferred("disabled", _noclip)
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.55) if _noclip else Color.WHITE


## Face the cursor. Shared by cannon mode and noclip so the sprite stays
## consistent across both.
func aim_sprite() -> void:
	sprite.flip_h = body.global_position.x > body.get_global_mouse_position().x


func try_fire() -> bool:
	if not _can_shoot:
		return false
	if body.get_viewport().gui_get_hovered_control() != null:
		return false
	## Skip fire if the click landed on UI (e.g. the sound toggle) — Input
	## still reports the action even when a Control already handled it.
	var mouse_pos := body.get_global_mouse_position()
	var direction := (mouse_pos - body.global_position).normalized()
	## Each shot adds a fresh impulse to momentum instead of accumulating a
	## never-decayed unit vector (the old bug that let vertical momentum bleed
	## into later shots).
	momentum += -direction * speed
	_can_shoot = false
	shoot_timer.start()
	body.get_node("AudioStreamPlayer2D").play()
	return true


## Gravity only acts while airborne. Horizontal momentum bleeds off at
## different rates in the air vs on the ground. Vertical momentum is NOT
## damped so cannon launches follow a natural gravity arc.
func step(delta: float, celeste_momentum : Vector2) -> void:
	if not body.is_on_floor():
		momentum.y += _gravity * gravity_scale * delta
		momentum.x = move_toward(momentum.x, 0.0, friction_air * delta)
	else:
		momentum.x = move_toward(momentum.x, 0.0, friction_ground * delta)

	body.velocity = momentum + celeste_momentum


## Enable/disable physics + collision. `disabled` is deferred because spike
## death runs from Area2D.body_entered and inline shape changes are ignored
## inside physics callbacks. Stays disabled while noclipping.
func set_active(active: bool) -> void:
	body.set_physics_process(active)
	collision_shape.set_deferred("disabled", not active or _noclip)
