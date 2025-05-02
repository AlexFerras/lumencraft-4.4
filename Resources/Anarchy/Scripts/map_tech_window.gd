@tool
extends Control

@export var editor_show: bool: set = set_editor_show

func set_editor_show(s: bool):
	if s:
		showme()

func showme():
	$AnimationPlayer.play("show")

func hideme():
	$AnimationPlayer.play_backwards("show")
