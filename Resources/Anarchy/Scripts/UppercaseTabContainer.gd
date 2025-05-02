extends TabContainer

var originals: Array

func _ready() -> void:
	for i in get_tab_count():
		originals.append(get_tab_title(i))
	
	update_translation()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		update_translation()

func update_translation():
	for i in originals.size():
		set_tab_title(i, tr(originals[i]).to_upper())
