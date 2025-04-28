extends Node

var was_paused: bool

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if not was_paused:
			get_tree().paused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		was_paused = get_tree().paused
		get_tree().paused = true
