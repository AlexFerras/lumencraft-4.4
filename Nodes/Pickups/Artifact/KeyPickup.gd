extends Pickup

enum Type {Lumen, Azure, Silver, Amber}

@export var color: Type = 0

func _enter_tree() -> void:
	id = Constants.ItemIDs.KEY
	if data == null:
		data = color

func _ready() -> void:
	$Sprite2D.texture.region.position.x = data * $Sprite2D.texture.region.size.x
