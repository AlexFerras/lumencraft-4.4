extends GenericInteractable

func _ready() -> void:
	set_meta("computer_interactable", true)
	connect("interacted", Callable(get_parent(), "interact"))
	connect("area_entered", Callable(get_parent(), "player_enter"))
	connect("area_exited", Callable(get_parent(), "player_exit"))

func _set_highlight(player: Player) -> bool:
	return get_parent().set_highlight(player != null)
