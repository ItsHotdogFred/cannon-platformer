extends AnimatableBody2D

var starting_pos: Vector2

var max_height = -70

var duration = 0.4

@export var launch_speed: float = 300.0

func _ready() -> void:
	starting_pos = global_position

var busy := false

## The player riding the platform up, while it's rising. Null otherwise.
var rider: CharacterBody2D
## Only launch on leaving once the rider has actually landed on us, so
## entering the area mid-air doesn't fire the launch straight away.
var rider_landed := false

func _on_area_2d_body_entered(body: Node2D) -> void:
	if busy or not body is CharacterBody2D:
		return
	busy = true
	rider = body
	rider_landed = false
	var tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "global_position:y", starting_pos.y + max_height, duration)
	tween.tween_callback(func():
		if rider and _is_standing_on_me(rider):
			_launch(rider)
		rider = null)
	tween.tween_property(self, "global_position:y", starting_pos.y, duration)
	await tween.finished
	busy = false


func _physics_process(_delta: float) -> void:
	if not rider:
		return
	if _is_standing_on_me(rider):
		rider_landed = true
	elif rider_landed:
		# Hopped off before the top: still give them the boost.
		_launch(rider)
		rider = null


## Uses min() so a jump off the platform keeps whichever is stronger,
## the jump or the launch, instead of the launch overwriting it.
func _launch(body: CharacterBody2D) -> void:
	body.movement.momentum.y = min(body.movement.momentum.y, -launch_speed)


func _is_standing_on_me(body: CharacterBody2D) -> bool:
	if not body.is_on_floor():
		return false
	for i in body.get_slide_collision_count():
		if body.get_slide_collision(i).get_collider() == self:
			return true
	return false
