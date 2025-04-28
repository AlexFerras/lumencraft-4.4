@tool
extends "res://Nodes/Editor/Buildings/EditorBuilding.gd"

func _init_data():
	super._init_data()
	defaults.lumen = 0
	defaults.scrap = 0

func _configure(editor):
	super._configure(editor)
	create_numeric_input(editor, "Stored Lumen", "lumen", 0, 500)
	create_numeric_input(editor, "Stored Metal", "scrap", 0, 500)

func _get_tooltip() -> Control:
	if object_data.lumen == 0 and object_data.scrap == 0:
		return null
	
	var panel := PanelContainer.new()
	var hbox := HBoxContainer.new()
	panel.add_child(hbox)
	
	if object_data.lumen > 0:
		var texture := TextureRect.new()
		texture.texture = Utils.get_item_icon(Const.ItemIDs.LUMEN)
		texture.expand = true
		texture.custom_minimum_size = Vector2(32, 32)
		hbox.add_child(texture)
		
		var label := Label.new()
		label.text = str(object_data.lumen)
		hbox.add_child(label)
	
	if object_data.scrap > 0:
		var texture := TextureRect.new()
		texture.texture = Utils.get_item_icon(Const.ItemIDs.METAL_SCRAP)
		texture.expand = true
		texture.custom_minimum_size = Vector2(32, 32)
		hbox.add_child(texture)
		
		var label := Label.new()
		label.text = str(object_data.scrap)
		hbox.add_child(label)
	
	return panel
