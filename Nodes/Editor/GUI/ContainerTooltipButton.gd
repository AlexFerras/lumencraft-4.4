extends Button

var items: Array

func _init() -> void:
	flat = true

func _make_custom_tooltip(for_text: String) -> Control:
	var container := PanelContainer.new()
	var vbox := VBoxContainer.new()
	container.add_child(vbox)
	
	if items.is_empty():
		pass
	else:
		var no_items := Label.new()
		no_items.text = "Contents:"
		vbox.add_child(no_items)
		
		var grid := GridContainer.new()
		grid.columns = 16
		
		for item in items:
			var tex := TextureRect.new()
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.expand = true
			tex.custom_minimum_size = Vector2(40, 40)
			tex.texture = Utils.get_item_icon(item.id, item.get("data"))
			grid.add_child(tex)
		
		vbox.add_child(grid)
		vbox.size = Vector2()
	
	return container
