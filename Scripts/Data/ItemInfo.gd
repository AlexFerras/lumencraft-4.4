@tool
extends Resource
class_name ItemInfo

@export var item: String: set = set_item
var data
@export var amount: int = 1

func set_item(i: String):
	item = i
	notify_property_list_changed()

func _get_property_list() -> Array:
	match item:
		"AMMO":
			var options: PackedStringArray
			for option in Const.Ammo:
				options.append(option)
			
			return [{name = "data", usage = PROPERTY_USAGE_DEFAULT, type = TYPE_INT, hint = PROPERTY_HINT_ENUM, hint_string = ",".join(options)}]
		"KEY":
			var options: PackedStringArray
			for option in load("res://Nodes/Pickups/Artifact/KeyPickup.gd").Type:
				options.append(option)
			
			return [{name = "data", usage = PROPERTY_USAGE_DEFAULT, type = TYPE_INT, hint = PROPERTY_HINT_ENUM, hint_string = ",".join(options)}]

	return []

func _set(property: String, value) -> bool:
	if property == "data":
		data = value
		return true
	
	return false

func _get(property: String):
	if property == "data":
		return data

func get_data():
	return {id = Const.ItemIDs.keys().find(item), data = data, amount = amount}

static func create_from_data(d: Dictionary) -> ItemInfo:
	var info = load("res://Scripts/ItemInfo.gd").new()
	info.item = d.item
	info.data = d.data
	info.amount = d.amount
	return info
