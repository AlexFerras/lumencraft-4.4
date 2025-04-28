extends OptionButton

@export var max_length: int

func _ready() -> void:
	var longest: String
	for i in get_item_count():
		if get_popup().is_item_separator(i):
			continue
		
		if get_item_text(i).length() > longest.length():
			if max_length > 0:
				longest = tr(get_item_text(i)).substr(0, max_length)
			else:
				longest = tr(get_item_text(i))
	
	custom_minimum_size.x = get_font("font").get_string_size(longest).x
	custom_minimum_size.x += get_stylebox("normal").get_minimum_size().x
	custom_minimum_size.x += get_icon("arrow").get_width()
	
	if expand_icon:
		custom_minimum_size.x += size.y
	
	if max_length > 0:
		connect("item_selected", Callable(self, "on_selected"))
		on_selected(selected)

func on_selected(index: int) -> void:
	text = Utils.trim_string(tr(text), max_length)
