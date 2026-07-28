extends Area2D

var follow : bool = false
var player : CharacterBody2D

func _on_body_entered(body: Node2D) -> void:
	#Gamemanager.stars += 1
	#call_deferred("queue_free")
	#Gamemanager.starLabel.text = str(Gamemanager.stars)
	if body is CharacterBody2D:
		follow = true
		player = body
		print("Collided")
		if player.is_on_floor():
				Gamemanager.stars += 1
				call_deferred("queue_free")
				Gamemanager.starLabel.text = str(Gamemanager.stars)
		
func _physics_process(delta: float) -> void:
	if follow:
		global_position = lerp(global_position, player.global_position, 0.1)
