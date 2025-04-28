@tool
extends EditorObject

var group := ButtonGroup.new()
var name_label: Label
var amount_box: SpinBox

var id: int = -1
var data

func _ready() -> void:
	if id > -1:
		icon.texture = Utils.get_item_icon(id, data)
		icon.scale = Pickup.get_texture_scale(icon.texture)

func _init_data():
	defaults.id = id
	defaults.data = data
	defaults.amount = 1

func _configure(editor):
	name_label = Label.new()
	name_label.text = Utils.get_item_name(object_data)
	editor.add_object_setting(name_label)
	
	var hbox := HBoxContainer.new()
	
	var label := Label.new()
	label.text = "Amount"
	hbox.add_child(label)
	
	amount_box = SpinBox.new()
	amount_box.min_value = 1
	amount_box.max_value = Utils.get_stack_size(object_data.id, object_data.data)
	amount_box.value = object_data.amount
	amount_box.connect("value_changed", Callable(self, "set_amount"))
	hbox.add_child(amount_box)
	
	editor.add_object_setting(hbox)

func set_item(i, d):
	id = i
	data = d
	emit_signal("data_changed")

func set_amount(v):
	object_data.amount = v
	emit_signal("data_changed")

func get_data() -> Dictionary:
	var ret := object_data.duplicate()
	ret.id = Const.ItemIDs.keys()[object_data.id]
	return ret

func set_data(dat: Dictionary):
	object_data = dat
	object_data.id = Const.ItemIDs.keys().find(dat.id)
	id = object_data.id
	data = object_data.data

func get_condition_list() -> Array:
	if object_data.id == Const.ItemIDs.METAL_SCRAP or object_data.id == Const.ItemIDs.LUMEN:
		return []
	
	return ["collected"]
