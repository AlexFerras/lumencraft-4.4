extends Control

@export var target_control:Control

func _ready() -> void:
	create_tween().set_loops().tween_callback(Callable(self, "update_visibility")).set_delay(0.25)

func update_visibility():
	if not visible or not target_control.visible:
		return
	
	for player in Utils.game.players:
		if get_rect().has_point(player.position_on_screen):
			target_control.modulate.a = 0.4
			return
	
	target_control.modulate.a = 1

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if not visible:
			target_control.modulate.a = 1
