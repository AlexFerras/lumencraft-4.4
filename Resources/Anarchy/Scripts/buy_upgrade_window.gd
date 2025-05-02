@tool
extends PanelContainer

@export var editor_show: bool: set = set_editor_show

@onready var animator: AnimationPlayer = $AnimationPlayer

signal disappeared

func set_editor_show(s: bool):
	if s:
		showme()

func showme() -> bool:
	if visible:
		return false
	else:
		animator.play("show")
		return true

func hideme():
	if visible and not animator.is_playing():
		animator.play_backwards("show")
		animator.connect("animation_finished", Callable(self, "hide2").bind(), CONNECT_ONE_SHOT)
		return true
	else:
		return false

func hide2(dupa = null):
	hide()
	emit_signal("disappeared")

func is_animating() -> bool:
	return animator.is_playing()
