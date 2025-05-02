extends TextureButton

func _ready() -> void:
	set_process_unhandled_input(is_visible_in_tree())

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process_unhandled_input(is_visible_in_tree())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("ui_cancel") and event.is_pressed():
		emit_signal("pressed")
		accept_event()
