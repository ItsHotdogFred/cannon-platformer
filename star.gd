extends Area2D


func _on_body_entered(body: Node2D) -> void:
	Gamemanager.stars += 1
	call_deferred("queue_free")
	Gamemanager.starLabel.text = str(Gamemanager.stars)
