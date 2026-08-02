extends Area2D

var follow : bool = false
var player : CharacterBody2D
var bob_time : float = 0.0
var starting_pos : Vector2
var returning : bool = false

func _ready() -> void:
	starting_pos = global_position

func _on_body_entered(body: Node2D) -> void:
	if body is RigidBody2D:
		for i in body.get_children():
			if i is CharacterBody2D:
				player = i

	if body is CharacterBody2D:
		player = body

	if player:
		follow = true
		if not player.just_died.is_connected(on_player_death):
			player.just_died.connect(on_player_death)

func _physics_process(delta: float) -> void:
	if follow:
		bob_time += delta
		var distance = global_position.distance_to(player.global_position)
		if distance >= 20 or player.is_on_floor():
			global_position = lerp(global_position, player.global_position, 0.1)
		if distance <= 4 and player.is_on_floor():
			Gamemanager.stars += 1
			call_deferred("queue_free")
			Gamemanager.starLabel.text = str(Gamemanager.stars)
			return
		global_position.y += sin(bob_time * 5.0) * 10.0 * delta
		
	if returning:
		global_position = lerp(global_position, starting_pos, 0.1)
		if floor(global_position) == floor(starting_pos):
			returning = false

func on_player_death():
	follow = false
	#global_position = starting_pos
	returning = true
