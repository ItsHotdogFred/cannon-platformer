@tool
extends Node2D

@export var travel := Vector2(96, 0):
	set(value):
		travel = value
		queue_redraw()
@export var dash_speed := 300.0
@export var return_speed := 40.0
@export var windup := 0.15
@export var point_pause := 0.25
@export var return_delay := 0.6

@onready var body: AnimatableBody2D = $Body
@onready var start := body.global_position

var busy := false
var tween: Tween
var dash_velocity := Vector2.ZERO

var rider: CharacterBody2D

var rider_landed := false
## Whoever touched us, so _reset can give back their platform_on_leave.
var toucher: CharacterBody2D
var toucher_on_leave := CharacterBody2D.PLATFORM_ON_LEAVE_ADD_VELOCITY


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	$Body/Touch.body_entered.connect(_on_touched)
	_hook_player.call_deferred()


## Editor only: outlines where a `travel` dash will stop. Markers show
## their own stops, so this is skipped when there are any.
func _draw() -> void:
	if not Engine.is_editor_hint() or get_children().any(func(c): return c is Marker2D):
		return
	var shape: CollisionShape2D = $Body/CollisionShape2D
	var size: Vector2 = shape.shape.size
	draw_rect(Rect2(body.position + travel + shape.position - size / 2, size), Color(1, 0.3, 0.3), false, 1.0)


func _hook_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.just_died.connect(_reset)
		player.movement.fired.connect(_on_fired)

func _on_fired() -> void:
	if not rider or not rider_landed or dash_velocity == Vector2.ZERO:
		return

	if dash_velocity.y < 0.0 and rider.movement.momentum.y > 0.0:
		return
	var player := rider
	rider = null
	_launch(player)


func _on_touched(other: Node2D) -> void:
	if busy or not other.is_in_group("player"):
		return
	busy = true
	rider = other
	rider_landed = false

	toucher = rider
	toucher_on_leave = rider.platform_on_leave
	rider.platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING

	var path: Array[Vector2] = [start]
	var markers := get_children().filter(func(c): return c is Marker2D)
	markers.sort_custom(func(a, b): return a.name.to_int() < b.name.to_int())
	for m in markers:
		path.append(m.global_position)
	if markers.is_empty():
		path.append(start + travel)

	tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(windup)
	for i in range(1, path.size()):
		if i > 1:
			tween.tween_callback(func(): dash_velocity = Vector2.ZERO)
			tween.tween_interval(point_pause)
		_leg(path[i - 1], path[i], dash_speed)
	tween.tween_callback(func():
		if rider and rider_landed and rider.is_on_floor() and $Body/Touch.overlaps_body(rider):
			_launch(rider)
		rider = null)
	tween.tween_interval(return_delay)
	for i in range(path.size() - 1, 0, -1):
		_leg(path[i], path[i - 1], return_speed)
	tween.tween_callback(_reset)


func _leg(from: Vector2, to: Vector2, speed: float) -> void:
	tween.tween_callback(func(): dash_velocity = (to - from).normalized() * speed)
	tween.tween_property(body, "global_position", to, from.distance_to(to) / speed)


func _physics_process(_delta: float) -> void:
	if not rider:
		return
	if _is_standing_on_me(rider):
		rider_landed = true

	elif rider_landed and not $Body/Touch.overlaps_body(rider):

		if rider.velocity.y < 0.0:
			_launch(rider)
		rider = null

func _launch(player: CharacterBody2D) -> void:
	var m: Vector2 = player.movement.momentum
	if signf(m.x) != -signf(dash_velocity.x):
		m.x += dash_velocity.x
	if dash_velocity.y < 0.0 and m.y <= 0.0:
		m.y += dash_velocity.y
	player.movement.momentum = m
	player.movement.launched = true


func _reset() -> void:
	if tween:
		tween.kill()
	if is_instance_valid(toucher):
		toucher.platform_on_leave = toucher_on_leave
	toucher = null
	rider = null
	body.global_position = start
	busy = false


func _is_standing_on_me(player: CharacterBody2D) -> bool:
	if not player.is_on_floor():
		return false
	for i in player.get_slide_collision_count():
		if player.get_slide_collision(i).get_collider() == body:
			return true

	return $Body/Touch.overlaps_body(player) and player.global_position.y < body.global_position.y
