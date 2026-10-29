extends TransitionRect
## End screen: covers the screen, shows the thank-you text, then the
## subtitle after a delay. Stays up for good.

@onready var label: Label = $Label
@onready var label_2: Label = $Label2

@export var text_fade_time: float = 1.0
@export var subtitle_delay: float = 5.0

func _ready() -> void:
	var tween = create_tween()
	tween.tween_property(material, "shader_parameter/factor", 1.0, 1)
	await tween.finished
	await _fade_in(label)
	await get_tree().create_timer(subtitle_delay).timeout
	_fade_in(label_2)

func _fade_in(l: Label) -> void:
	l.modulate.a = 0.0
	l.show()
	var text_tween = create_tween()
	text_tween.tween_property(l, "modulate:a", 1.0, text_fade_time)
	await text_tween.finished
