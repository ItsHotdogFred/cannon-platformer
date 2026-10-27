extends Node2D

@export var minRopeLength := 0.0
@export var maxRopeLength := 50.0
@export var ropeStiffness := 2000.0
@export var ropeDamping := 20.0
@export var swingImpulse := 3.0
@export var climbSpeed := 90.0

const ROPE_TEXTURE = preload("res://assets/jumpstart/Jumpstart Legacy/Tilesets/rope.png")
## rope.png is drawn vertically, but Line2D tiles along the texture's X axis.
static var _rope_line_texture: Texture2D

@onready var anchor: StaticBody2D = %Anchor
@onready var player_anchor: RigidBody2D = %PlayerAnchor
@onready var line_2d: Line2D = %Line2D

var current_rope_length: float
var _player: Node2D
var _player_parent: Node
var _attached_body: Node2D
var _attached_local_position := Vector2.ZERO
var _released := false
var _rope_viewport: SubViewport
var _screen_camera: Camera2D


func _ready() -> void:
	# Keep rope rendering alive while the camera pans with the tree paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _rope_line_texture == null:
		var image := ROPE_TEXTURE.get_image()
		image.rotate_90(CLOCKWISE)
		_rope_line_texture = ImageTexture.create_from_image(image)
	line_2d.texture = _rope_line_texture


func start_hook(hook_position: Vector2, attached_body: Node2D = null) -> void:
	anchor.global_position = hook_position
	if attached_body != null:
		_attached_body = attached_body
		_attached_local_position = attached_body.to_local(hook_position)

	# PlayerAnchor is also in the player group while grappling because it is the
	# body that interacts with hazards. Resolve the actual player explicitly.
	_player = Gamemanager.player
	_player_parent = _player.get_parent()
	_rope_viewport = get_tree().get_first_node_in_group("grapple_rope_viewport") as SubViewport
	_screen_camera = get_tree().get_first_node_in_group("grapple_screen_camera") as Camera2D
	if is_instance_valid(_screen_camera):
		line_2d.reparent(_screen_camera, false)
		line_2d.position = Vector2.ZERO
		line_2d.z_index = 100
		line_2d.visible = true
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
	if get_tree().paused:
		return

	_update_anchor_position()
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

## Keeps an attachment at the same point on a moving/rotating collider.
func _update_anchor_position() -> void:
	if _attached_body != null and is_instance_valid(_attached_body):
		anchor.global_position = _attached_body.to_global(_attached_local_position)
	else:
		_attached_body = null

func _leave_rope():
	await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(self) or _released:
		return
	_detach_player(player_anchor.linear_velocity)

## Immediate release with no delay / no carry velocity (death, forced cancel).
## Deferred: may be called from Area2D.body_entered while physics is flushing
## queries; reparenting a CharacterBody2D there is not allowed.
## reactivate_player: false on death so the player stays frozen for the sequence.
func force_release(reactivate_player: bool = true) -> void:
	call_deferred("_detach_player", Vector2.ZERO, reactivate_player)

func _detach_player(release_momentum: Vector2, reactivate_player: bool = true) -> void:
	if _released or not is_instance_valid(self):
		return
	_released = true

	if _player == null:
		_player = Gamemanager.player
	if _player == null:
		queue_free()
		return

	# Return the player to the parent it had before attaching. This is commonly
	# a SubViewport; reparenting to current_scene would remove it from the
	# viewport's rendering and physics world.
	if is_instance_valid(_player_parent):
		_player.reparent(_player_parent)
	if reactivate_player:
		_player.set_active(true)
	else:
		_player.set_active(false)
	_player.momentum = release_momentum
	if _player.has_method("clear_grappling_hook"):
		_player.clear_grappling_hook(self)

	# The rope was reparented into the SubViewport, so it is no longer freed
	# automatically with this hook instance.
	if is_instance_valid(line_2d):
		line_2d.queue_free()
	queue_free()


func _process(_delta: float) -> void:
	if not is_instance_valid(line_2d):
		return

	# Assign a whole new PackedVector2Array; indexing `line_2d.points` alone
	# mutates a copy and won't update the rendered line.
	var player_position := player_anchor.global_position
	var anchor_position := anchor.global_position
	if is_instance_valid(_screen_camera):
		player_position = _screen_camera.to_local(player_anchor.global_position)
		anchor_position = _screen_camera.to_local(anchor.global_position)
	line_2d.points = PackedVector2Array([player_position, anchor_position])
