@tool
extends "res://Nodes/Editor/Buildings/EditorBuilding.gd"

var items: OptionButton
var item_amount: Range

func _init_data():
	super._init_data()
	defaults.stored_item = {}

func _configure(editor):
	super._configure(editor)
	
	items = create_items()
	editor.add_object_setting(items)
	
	item_amount = SpinBox.new()
	item_amount.min_value = 1
	editor.add_object_setting(item_amount)
	item_amount.hide()
	
	if not object_data.stored_item.is_empty():
		var amount = object_data.stored_item.amount
		items.set_selected_metadata(object_data.stored_item)
		on_item_selected(items.selected)
		item_amount.value = amount
	
	items.connect("item_selected", Callable(self, "on_item_selected"))
	item_amount.connect("value_changed", Callable(self, "amount_changed"))

func on_item_selected(index: int):
	if index == 0:
		object_data.stored_item = {}
		item_amount.hide()
		return
	
	object_data.stored_item = {}
	var item: Dictionary = items.get_item_metadata(index)
	object_data.stored_item.id = item.id
	if "data" in item:
		object_data.stored_item.data = item.data
	object_data.stored_item.amount = 1
	
	item_amount.show()
	item_amount.value = 1
	item_amount.max_value = Utils.get_stack_size(item.id, item.get("data")) * 3

func amount_changed(value: float):
	object_data.stored_item.amount = int(value)

func get_condition_list() -> Array:
	return super.get_condition_list() + ["item_stored", "item_retrieved*"]

func action_get_events() -> Array:
	return super.action_get_events() + ["drop_item", "drop_stack"]

func get_additional_config(editor, condition_action: String) -> Control:
	match condition_action:
		"item_stored":
			var items2 = create_items()
			items2.set_item_text(0, "Any")
			editor.register_data("item", Callable(items, "set_selected_metadata"), Callable(items, "get_selected_metadata"))
			return items2
	
	return null

func create_items() -> OptionButton:
	items = preload("res://Nodes/UI/MetadataOptionButton.gd").new()
	items.add_item("Empty")
	
	for item in Const.game_data.get_editor_pickup_list(false):
		items.add_item(Utils.get_item_name(item))
		items.set_item_metadata(items.get_item_count() - 1, item)
	
	return items
