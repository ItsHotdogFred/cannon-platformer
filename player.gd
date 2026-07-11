extends CharacterBody2D

@export var speed: float = 150.0
@export var friction: float = 50# 500.0

@onready var ray_cast_2d: RayCast2D = $RayCast2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var shoot_time: Timer = $ShootTime

const GRAPPLING_HOOK = preload("uid://dum12y78crq6f")

var starting_pos : Vector2

var can_shoot = true
## Active hook instance while swinging; null when free.
var active_grappling_hook: Node2D = null


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
	_set_ray_cast_direction()
	# Fire: launch the player opposite the cursor (recoil). Each shot adds a
	# fresh impulse to momentum instead of accumulating a never-decayed unit
	# vector, which is what let old vertical momentum bleed into later shots.
	if Input.is_action_just_pressed("shoot") and can_shoot:
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
		$Sprite.flip_h = true
	else:
		$Sprite.flip_h = false
	
func _set_ray_cast_direction():
	var mouse_pos := get_global_mouse_position()
	# Point the ray at the cursor and make it long enough to reach the click.
	ray_cast_2d.target_position = ray_cast_2d.to_local(mouse_pos)

func _use_grappling_hook():
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
func cancel_grappling_hook() -> void:
	if active_grappling_hook != null and is_instance_valid(active_grappling_hook):
		active_grappling_hook.force_release()
	active_grappling_hook = null

func clear_grappling_hook(hook: Node2D = null) -> void:
	if hook == null or active_grappling_hook == hook:
		active_grappling_hook = null

## Reset after death: detach rope first so the player isn't stuck under PlayerAnchor.
## Safe to call from Area2D.body_entered — force_release defers reparent.
func respawn() -> void:
	cancel_grappling_hook()
	# global_position works while still parented; deferred reparent keeps it.
	global_position = starting_pos
	momentum = Vector2.ZERO
	velocity = Vector2.ZERO
	set_active(true)

func set_active(boolean: bool):
	set_physics_process(boolean)
	# Must be deferred: spike death runs from Area2D.body_entered (physics
	# callback), and changing shape.disabled inline is ignored/unsafe there.
	collision_shape_2d.set_deferred("disabled", not boolean)


func _on_shoot_time_timeout() -> void:
	can_shoot = true
