extends Control

signal go

func _ready() -> void:
	set_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER:
		set_process(true)
	elif what == NOTIFICATION_FOCUS_EXIT:
		set_process(false)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_left"):
		emit_signal("go", Vector2.LEFT)
	elif Input.is_action_just_pressed("ui_up"):
		emit_signal("go", Vector2.UP)
	elif Input.is_action_just_pressed("ui_down"):
		emit_signal("go", Vector2.DOWN)
	elif Input.is_action_just_pressed("ui_right"):
		emit_signal("go", Vector2.RIGHT)
	elif Input.is_action_just_pressed("ui_cancel"):
		emit_signal("go", Vector2.ZERO)
