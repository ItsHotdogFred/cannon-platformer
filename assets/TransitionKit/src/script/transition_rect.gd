@tool
extends ColorRect
class_name TransitionRect

@export var base_color : Color:
	set(value):
		base_color = value
		material.set_shader_parameter("base_color", base_color)
@export_range(0.0,1.0,0.01) var factor : float = 0.5:
	set(value):
		factor = value
		material.set_shader_parameter("factor", factor)
@export var width : float = 0.3:
	set(value):
		width = value
		material.set_shader_parameter("width", width)

@export_group("Gradient")
@export var gradient_texture : Texture2D:
	set(value):
		gradient_texture = value
		material.set_shader_parameter("gradient_texture", gradient_texture)
@export var gradient_fixed : bool:
	set(value):
		gradient_fixed = value
		material.set_shader_parameter("gradient_fixed", gradient_fixed)

@export_group("Shape")
@export var shape_texture : Texture2D:
	set(value):
		shape_texture = value
		material.set_shader_parameter("shape_texture", shape_texture)
@export var shape_tiling : float = 32.0:
	set(value):
		shape_tiling = value
		material.set_shader_parameter("shape_tiling", shape_tiling)
@export var shape_rotation : float = 0.0:
	set(value):
		shape_rotation = value
		material.set_shader_parameter("shape_rotation", shape_rotation)
@export var shape_scroll : Vector2 = Vector2():
	set(value):
		shape_scroll = value
		material.set_shader_parameter("shape_scroll", shape_scroll)
@export var shape_treshold : float = 1.0:
	set(value):
		shape_treshold = value
		material.set_shader_parameter("shape_treshold", shape_treshold)

func _enter_tree() -> void:
	set_shader_resolution()
	connect("resized", self.rect_resized)

func rect_resized():
	set_shader_resolution()

func set_shader_resolution():
	material.set_shader_parameter("node_resolution", size)
