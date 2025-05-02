extends Button

var small_text: String: set = set_small_text

func _ready() -> void:
	small_text = text
	update_text()
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("focus_entered", Callable(self, "_on_mouse_entered"))

func _notification(what: int) -> void:
	if small_text.is_empty():
		return
	
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		update_text()

func set_small_text(s: String):
	small_text = s
	update_text()

func update_text():
	text = tr(small_text).to_upper()

func _on_mouse_entered():
	Utils.play_ui_sample(Utils.UI_SELECT)

func _pressed() -> void:
	Utils.play_ui_sample(Utils.UI_SELECT)
