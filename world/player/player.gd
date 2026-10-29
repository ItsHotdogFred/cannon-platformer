extends CharacterBody2D

const MovementScript = preload("res://world/player/movement.gd")
const GrappleScript = preload("res://world/player/grapple_controller.gd")
const DeathScript = preload("res://world/player/death_sequence.gd")
const CelesteMovementScript = preload("res://world/player/celeste_movement.gd")
const LandingSound = preload("res://happy-wheels-oh-my-leg.mp3")
const MessageFont = preload("res://fonts/silkscreen/Silkscreen-Regular.ttf")

@export var noclip_speed: float = 200.0
## When false the player can't fire the grapple; turning it off mid-grapple
## releases the current hook.
@export var can_grapple: bool = true:
	set(value):
		can_grapple = value
		if not value and is_node_ready():
			grapple.cancel()

## When false walk/jump/shoot/grapple input is ignored; gravity still applies.
@export var can_move: bool = true
@export var can_jump: bool = true
@export var can_shoot: bool = true
@onready var sprite: AnimatedSprite2D = $Sprite

@onready var movement = MovementScript.new()
@onready var grapple = GrappleScript.new()
@onready var death = DeathScript.new()
@onready var celeste = CelesteMovementScript.new()

var starting_pos: Vector2

var falling : bool = false
var _landing_sound_playing : bool = false

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
	
	var current_pos = global_position
	

	
	var celeste_momentum := Vector2.ZERO
	if can_move:
		celeste_momentum = celeste.movement(delta)
	else:
		sprite.play("default")
	
	if death.is_dying:
		return
	if Input.is_action_just_pressed("noclip"):
		_toggle_noclip()
	if movement.is_noclip():
		_noclip_move(delta)
		return

	grapple.aim()
	movement.aim_sprite()
	if Input.is_action_just_pressed("shoot") and can_shoot and can_move:
		if movement.try_fire():
			_breakable_hit()
	if can_move and can_grapple and Input.is_action_just_pressed("interaction"):
		if grapple.try_attach():
			return
	if can_move and can_jump and Input.is_action_just_pressed("jump") and is_on_floor():
		movement.jump()
			
	
	movement.step(delta, celeste_momentum)
	
	var pre_velocity := velocity
	move_and_slide()
	if pre_velocity.x != 0.0:
		movement.momentum.x *= velocity.x / pre_velocity.x
	if pre_velocity.y != 0.0:
		movement.momentum.y *= velocity.y / pre_velocity.y
	if not can_move and not _landing_sound_playing and is_on_floor():
		_play_landing_sound()
		
	if falling == true:
		
		sprite.rotate(5 * delta)
		global_position = current_pos
		$PointLight2D.hide()

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


## Plays once on landing while frozen, then hands control back.
func _play_landing_sound() -> void:
	_landing_sound_playing = true
	var sfx := AudioStreamPlayer.new()
	sfx.stream = LandingSound
	add_child(sfx)
	sfx.play()
	await sfx.finished
	sfx.queue_free()
	_landing_sound_playing = false
	can_move = true
	_show_message("Your legs have been crushed! You can still walk, but jumping is out of the question. Thankfully, a hand cannon has magically appeared in your pocket. Use it to get around from now on.")


## Fades a centred message in, holds it, then fades it out. Same style as the
## prolog transition text.
func _show_message(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", MessageFont)
	label.add_theme_font_size_override("font_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate.a = 0.0
	layer.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 1.0)
	tween.tween_interval(5.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(layer.queue_free)


func _breakable_hit() -> void:
	$RayCast2D.force_raycast_update()
	if not $RayCast2D.is_colliding():
		return
	var collider: Node = $RayCast2D.get_collider() as Node
	if collider != null and collider.is_in_group("breakable"):
		if collider.has_method("destroy"):
			collider.call("destroy")
