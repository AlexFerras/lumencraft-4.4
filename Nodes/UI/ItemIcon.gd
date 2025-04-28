extends TextureRect

@export var item: String
@export var data: Dictionary

func _ready() -> void:
	var actual_data = data.get("data")
	texture = Utils.get_item_icon(Const.ItemIDs.keys().find(item), actual_data)
