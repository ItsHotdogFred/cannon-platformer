extends Button

const SOUND_ON = preload("uid://bibuw7f70ifba")
const SOUND_OFF = preload("uid://dq1yst02klqce")

@onready var audio_stream_player_2d: AudioStreamPlayer2D = $"../AudioStreamPlayer2D"
@onready var sprite_2d: Sprite2D = $Sprite2D

@export var sound : bool = true


func _on_pressed() -> void:
	sound = !sound
	if sound:
		audio_stream_player_2d.stream_paused = false
		icon = SOUND_ON
	else:
		audio_stream_player_2d.stream_paused = true
		icon = SOUND_OFF

		
		
