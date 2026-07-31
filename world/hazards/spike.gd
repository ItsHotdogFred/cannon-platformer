extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Arcade death sequence (burst + soft checkpoint return).
		# die() is re-entry guarded while the sequence plays.
		if Gamemanager.player != null and Gamemanager.player.has_method("die"):
			Gamemanager.player.die()
		else:
			Gamemanager.player.respawn()
