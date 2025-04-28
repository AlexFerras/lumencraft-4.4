@tool
extends EditorObject

var hovered: EditorObject

@export var no_item_text := "No items added. Drop a Pickup object on the chest to add."
@export var empty_text := "Empty"
@export var true_chest: bool

func _init() -> void:
	can_rotate = true

func _init_data():
	defaults.items = []
	defaults.double_in_coop = false

func _get_tooltip() -> Control:
	var container := PanelContainer.new()
	var vbox := VBoxContainer.new()
	container.add_child(vbox)
	
	if not "items" in object_data: # compat
		object_data.items = []
	
	if object_data.items.is_empty():
		var no_items := Label.new()
		no_items.text = empty_text
		vbox.add_child(no_items)
	else:
		var no_items := Label.new()
		no_items.text = "Contents:"
		vbox.add_child(no_items)
		
		var grid := GridContainer.new() ## czemu HFlowContainer tu nie działa?
		grid.columns = 16
		
		for item in object_data.items:
			var tex := TextureRect.new()
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.expand = true
			tex.custom_minimum_size = Vector2(40, 40)
			tex.texture = Utils.get_item_icon(item.id, item.get("data"))
			grid.add_child(tex)
		
		vbox.add_child(grid)
		vbox.size = Vector2()
	
	if is_instance_valid(hovered) and (hovered.object_name == "Pickup" or hovered.object_name == "Armored Box" or hovered.object_name == "Technology Orb"):
		var help := Label.new()
		help.text = "Hold Ctrl to add"
		vbox.add_child(help)
	
	return container

func _hover_object(object: EditorObject):
	if object != hovered:
		hovered = object
		tooltip_dirty = true

func _unhover_object():
	hovered = null
	tooltip_dirty = true

func _unhover():
	hovered = null

func _push_object(object: EditorObject) -> bool:
	if object.object_name == "Pickup":
		object_data.items.append({id = object.object_data.id, data = object.object_data.data, amount = object.object_data.amount})
		emit_signal("data_changed")
		tooltip_dirty = true
	elif object.object_name == "Armored Box":
		object_data.items.append({id = Const.ItemIDs.ARMORED_BOX, data = object.object_data.items.duplicate(), amount = 1})
		emit_signal("data_changed")
		tooltip_dirty = true
	elif object.object_name == "Technology Orb":
		object_data.items.append({id = Const.ItemIDs.TECHNOLOGY_ORB, data = object.object_data.duplicate(), amount = 1})
		emit_signal("data_changed")
		tooltip_dirty = true
	return tooltip_dirty

func _configure(editor):
	if object_data.items.is_empty():
		var label := Label.new()
		label.text = no_item_text
		label.autowrap = true
		editor.add_object_setting(label)
	else:
		var vbox := VBoxContainer.new()
		vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		var label := Label.new()
		label.text = "Contents:"
		label.autowrap = true
		editor.add_object_setting(label)
		
		for item in object_data.items:
			var hbox := HBoxContainer.new()
			
			var tex := TextureRect.new()
			tex.expand = true
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.custom_minimum_size = Vector2(60, 60)
			tex.texture = Utils.get_item_icon(item.id, item.get("data"))
			hbox.add_child(tex)
			
			label = Label.new()
			label.text = str(tr(Utils.get_item_name(item)), " x", item.amount)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.autowrap = true
			hbox.add_child(label)
			
			if item.id == Const.ItemIDs.ARMORED_BOX:
				var button := preload("res://Nodes/Editor/GUI/ContainerTooltipButton.gd").new()
				button.items = item.data
				button.icon = preload("res://Nodes/Editor/Icons/Search.svg")
				button.tooltip_text = "?"
				hbox.add_child(button)
			
			var button := Button.new()
			button.icon = preload("res://Nodes/Editor/Icons/Remove.svg")
			button.connect("pressed", Callable(self, "delete_item").bind(item))
			hbox.add_child(button)
			
			vbox.add_child(hbox)
			
		editor.add_object_setting(vbox)

func delete_item(item):
	object_data.items.erase(item)
	emit_signal("data_changed")
	config_dirty = true

func get_data() -> Dictionary:
	var ret := object_data.duplicate(true)
	for item in ret.items:
		item.id = Const.ItemIDs.keys()[item.id]
	return ret

func set_data(data: Dictionary):
	object_data = data
	if not "items" in data: # compat
		object_data.items = []
	else:
		for item in object_data.items:
			item.id = Const.ItemIDs.keys().find(item.id)

func get_condition_list() -> Array:
	if true_chest:
		return ["chest_opened"]
	else:
		return custom_condition_list

func action_get_events() -> Array:
	if true_chest:
		return ["open"]
	else:
		return custom_action_list
