extends Node

@export var speed : float = 0
@export var ground_speed : float = 6000
@export var gravity : float = ProjectSettings.get_setting("physics/2d/default_gravity")

var characterbody2d : CharacterBody2D
var movementNode : Node

func bind(characterbody2d : CharacterBody2D, movementNode : Node):
	self.characterbody2d = characterbody2d
	self.movementNode = movementNode

func movement(delta : float) -> Vector2:
	
	var momentum : Vector2
	
	var active_speed := ground_speed if characterbody2d.is_on_floor() else speed
	
	if Input.is_action_pressed("left"):
		momentum.x += -active_speed * delta
		characterbody2d.sprite.play("run")
	elif Input.is_action_pressed("right"):
		momentum.x += active_speed * delta
		characterbody2d.sprite.play("run")
	else:
		characterbody2d.sprite.play("default")
		
		

	return momentum
