@tool
extends Line2D

var max_range=200.0
var current_dist=0.0


func setup(center,target_center,detection_range,mob_radius, scal,points_array, select=true):
	width=mob_radius
	add_to_group("path_minimap")
	add_to_group("dont_save")
	material =material.duplicate()
	material.set_shader_parameter("center",center)
	material.set_shader_parameter("target_center",target_center)
	max_range=detection_range
	current_dist=0.0
	material.set_shader_parameter("dist", current_dist)
	scale=scal
	points = points_array
	if select:
		select()
	else:
		$AnimationPlayer2.play("selected")

func select():
	$AnimationPlayer.play("selected")
	$AnimationPlayer2.stop()
	$AnimationPlayer2.play("selected")
	z_index=1


func deselect():
	$AnimationPlayer.stop()
	$AnimationPlayer.play("deselected")
	$AnimationPlayer2.playback_speed=20.0
	z_index=0

func _process(delta):
	current_dist=min(current_dist+3.0,max_range)
	material.set_shader_parameter("global_transform", global_transform)
	material.set_shader_parameter("dist", current_dist)
