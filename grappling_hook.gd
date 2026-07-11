extends Node2D

@export var minRopeLength := 0.0
@export var maxRopeLength := 50.0
@export var ropeStiffness := 2000.0
@export var ropeDamping := 20.0
@export var swingImpulse := 3.0
@export var climbSpeed := 90.0

@onready var anchor: StaticBody2D = %Anchor
@onready var player_anchor: RigidBody2D = %PlayerAnchor
@onready var line_2d: Line2D = %Line2D

var current_rope_length: float
var _player: Node2D
var _released := false

func start_hook(hookPosition):
	anchor.global_position = hookPosition

	_player = get_tree().get_first_node_in_group("player")
	player_anchor.global_position = _player.global_position
	player_anchor.linear_velocity = Vector2.ZERO
	player_anchor.angular_velocity = 0.0
	_player.reparent(player_anchor)

	# Remove the editor PinJoint2D: it pins body_b to the joint's position,
	# so it would instantly snap the player to the grapple anchor.
	var old_joint := anchor.get_node_or_null("PinJoint2D")
	if old_joint:
		old_joint.queue_free()

	# Keep the player upright while on the rope; pendulum rotation just causes
	# control/visual glitches in a platformer and gets reset on release anyway.
	player_anchor.lock_rotation = true

	# Start with a slack rope exactly the current distance so there is no
	# initial yank; gravity will tension it naturally as the player swings.
	current_rope_length = player_anchor.global_position.distance_to(anchor.global_position)

func _physics_process(delta: float) -> void:
	if _player == null:
		return

	var to_anchor := anchor.global_position - player_anchor.global_position
	var distance := to_anchor.length()
	var direction := to_anchor.normalized()
	

	# Pull the player toward the anchor only when gravity/collision has
	# stretched the rope beyond its allowed length.
	if distance > current_rope_length:
		var stretch := distance - current_rope_length
		var tension := direction * stretch * ropeStiffness
		var damping := -player_anchor.linear_velocity.project(direction) * ropeDamping
		player_anchor.apply_central_force(tension + damping)

	# Swing left/right (tangent to the rope).
	if Input.is_action_pressed("right"):
		player_anchor.apply_central_impulse(player_anchor.global_transform.x * swingImpulse)
	if Input.is_action_pressed("left"):
		player_anchor.apply_central_impulse(player_anchor.global_transform.x * -swingImpulse)
	elif Input.is_action_pressed("down"):
		current_rope_length = minf(current_rope_length + climbSpeed * delta, maxRopeLength)
	elif Input.is_action_pressed("up"):
		current_rope_length = maxf(current_rope_length - climbSpeed * delta, minRopeLength)

	if Input.is_action_just_pressed("interaction"):
		_leave_rope()

func _leave_rope():
	await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(self) or _released:
		return
	_detach_player(player_anchor.linear_velocity)

## Immediate release with no delay / no carry velocity (death, forced cancel).
## Deferred: may be called from Area2D.body_entered while physics is flushing
## queries; reparenting a CharacterBody2D there is not allowed.
func force_release() -> void:
	call_deferred("_detach_player", Vector2.ZERO)

func _detach_player(release_momentum: Vector2) -> void:
	if _released or not is_instance_valid(self):
		return
	_released = true

	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		queue_free()
		return

	_player.reparent(get_tree().current_scene)
	_player.set_active(true)
	_player.momentum = release_momentum
	if _player.has_method("clear_grappling_hook"):
		_player.clear_grappling_hook(self)

	queue_free()


func _process(_delta: float) -> void:
	# Assign a whole new PackedVector2Array; indexing `line_2d.points` alone
	# mutates a copy and won't update the rendered line.
	line_2d.points = PackedVector2Array([
		line_2d.to_local(player_anchor.global_position),
		line_2d.to_local(anchor.global_position)
	])
