extends Button

const SOUND_ON = preload("uid://bibuw7f70ifba")
const SOUND_OFF = preload("uid://dq1yst02klqce")

@onready var audio_stream_player_2d: AudioStreamPlayer2D = $"../AudioStreamPlayer2D"

@export var sound : bool = true

func _ready() -> void:
	toggle_sound()

func _on_pressed() -> void:
	sound = !sound
	toggle_sound()

		
		
func toggle_sound():
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), not sound)
	if sound:
		audio_stream_player_2d.stream_paused = false
		icon = SOUND_ON
	else:
		audio_stream_player_2d.stream_paused = true
		icon = SOUND_OFF

		
