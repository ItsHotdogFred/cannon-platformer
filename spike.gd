extends Area2D


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Cancel an active grapple if any; never start a new one (the old
		# _use_grappling_hook call would fire when the ray hit something).
		Gamemanager.player.respawn()
