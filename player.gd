extends CharacterBody2D

const MovementScript = preload("res://player/movement.gd")
const GrappleScript = preload("res://player/grapple_controller.gd")
const DeathScript = preload("res://player/death_sequence.gd")
const CelesteMovementScript = preload("res://player/celeste_movement.gd")

@export var noclip_speed: float = 200.0
@onready var sprite: AnimatedSprite2D = $Sprite

@onready var movement = MovementScript.new()
@onready var grapple = GrappleScript.new()
@onready var death = DeathScript.new()
@onready var celeste = CelesteMovementScript.new()

var starting_pos: Vector2

signal just_died

func _ready() -> void:
	add_to_group("player")
	starting_pos = global_position
	Gamemanager.player = self

	movement.name = "Movement"
	add_child(movement)
	grapple.name = "Grapple"
	add_child(grapple)
	death.name = "Death"
	add_child(death)

	movement.bind(self, $Sprite, $CollisionShape2D, $ShootTime)
	grapple.bind(self, $RayCast2D)
	grapple.on_attach = func (): movement.set_active(false)
	grapple.on_release = func (): movement.set_active(true)
	death.bind(self, $Sprite, starting_pos,
			func (active: bool): movement.set_active(active),
		func (): return movement.is_noclip())
	celeste.bind(self, movement)


func _physics_process(delta: float) -> void:
	
	var celeste_momentum = celeste.movement(delta)
	
	if death.is_dying:
		return
	if Input.is_action_just_pressed("noclip"):
		_toggle_noclip()
	if movement.is_noclip():
		_noclip_move(delta)
		return

	grapple.aim()
	movement.aim_sprite()
	if Input.is_action_just_pressed("shoot"):
		movement.try_fire()
	if Input.is_action_just_pressed("interaction"):
		if grapple.try_attach():
			return
	movement.step(delta, celeste_momentum)
	
	var pre_velocity := velocity
	move_and_slide()
	if pre_velocity.x != 0.0:
		movement.momentum.x *= velocity.x / pre_velocity.x
	if pre_velocity.y != 0.0:
		movement.momentum.y *= velocity.y / pre_velocity.y


# --- Public surface other systems call -------------------------------

func die() -> void:
	if death.is_dying:
		return
	grapple.cancel(false)
	movement.momentum = Vector2.ZERO
	velocity = Vector2.ZERO
	movement.set_active(false)
	just_died.emit()
	await death.start()


func respawn() -> void:
	grapple.cancel(false)
	movement.momentum = Vector2.ZERO
	velocity = Vector2.ZERO
	death.reset()


## Set by the grappling hook on attach/release. Player proxies these to
## movement so the hook script's API doesn't change.
func set_active(active: bool) -> void:
	movement.set_active(active)


## Public so grappling_hook.gd can write to it (releases preserve momentum).
var momentum: Vector2:
	get: return movement.momentum
	set(value): movement.momentum = value


## Self-clear callback from grappling_hook.gd when it detaches.
func clear_grappling_hook(hook: Node2D = null) -> void:
	grapple.clear(hook)


# --- Internal --------------------------------------------------------

func _toggle_noclip() -> void:
	grapple.cancel()
	movement.set_noclip(not movement.is_noclip())


func _noclip_move(delta: float) -> void:
	var dir := Vector2(
		Input.get_axis("left", "right"),
		Input.get_axis("up", "down")
	)
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	global_position += dir * noclip_speed * delta
	movement.aim_sprite()
