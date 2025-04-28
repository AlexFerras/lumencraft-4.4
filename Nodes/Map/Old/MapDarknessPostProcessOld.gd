@tool
extends Sprite2D

func _ready() -> void:
	add_to_group("dont_save")

func get_canvas_transform() -> Transform2D:
	if Engine.is_editor_hint():
		return get_viewport().global_canvas_transform
	else:
		return get_viewport().canvas_transform

func _process(delta):
	var trans := get_canvas_transform()
	var camera_scale := trans.get_scale()
	var scale_inv = Vector2.ONE / camera_scale
	
	var aspect_scale := 1.0
	
	if not Engine.is_editor_hint():
		var aspect_change := Vector2(get_window().size.x / Utils.game.resolution_of_visible_rect.x, get_window().size.y / Utils.game.resolution_of_visible_rect.y)
		# Czemu to tak jest ;_; Czemu to działaaa ;_____;
		if aspect_change.x < 1:
			aspect_scale = 1.0 / aspect_change.x
		elif aspect_change.y < 1:
			aspect_scale = 1.0 / aspect_change.y
		elif aspect_change.x > 1 and aspect_change.y > 1:
			aspect_scale = 1.0 / min(aspect_change.x, aspect_change.y)
	
	scale = (get_viewport().size * scale_inv * aspect_scale).ceil()
	global_position = -trans.origin * scale_inv
	
	material.set_shader_parameter("real_time", Time.get_ticks_msec()*0.001)
	material.set_shader_parameter("global_transform", get_global_transform())
	material.set_shader_parameter("camera_zoom", get_viewport_transform().get_scale())
