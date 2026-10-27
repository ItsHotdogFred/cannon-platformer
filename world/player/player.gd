extends CharacterBody2D

const MovementScript = preload("res://world/player/movement.gd")
const GrappleScript = preload("res://world/player/grapple_controller.gd")
const DeathScript = preload("res://world/player/death_sequence.gd")
const CelesteMovementScript = preload("res://world/player/celeste_movement.gd")

@export var noclip_speed: float = 200.0
## When false the player can't fire the grapple; turning it off mid-grapple
## releases the current hook.
@export var can_grapple: bool = true:
	set(value):
		can_grapple = value
		if not value and is_node_ready():
			grapple.cancel()

@export var can_jump: bool = true
@export var can_shoot: bool = true
@onready var sprite: AnimatedSprite2D = $Sprite

@onready var movement = MovementScript.new()
@onready var grapple = GrappleScript.new()
@onready var death = DeathScript.new()
@onready var celeste = CelesteMovementScript.new()

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

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
	if Input.is_action_just_pressed("shoot") and can_shoot:
		if movement.try_fire():
			_breakable_hit()
	if can_grapple and Input.is_action_just_pressed("interaction"):
		if grapple.try_attach():
			return
	if can_jump and Input.is_action_just_pressed("jump") and is_on_floor():
		movement.jump()
			
	
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
	# Grapple detachment is deferred because death can originate from a physics
	# callback. Let it reparent the player before the death burst captures its
	# world position and before the respawn sequence moves the player.
	await get_tree().process_frame
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


func _breakable_hit() -> void:
	$RayCast2D.force_raycast_update()
	if not $RayCast2D.is_colliding():
		return
	var collider: Node = $RayCast2D.get_collider() as Node
	if collider != null and collider.is_in_group("breakable"):
		if collider.has_method("destroy"):
			collider.call("destroy")
