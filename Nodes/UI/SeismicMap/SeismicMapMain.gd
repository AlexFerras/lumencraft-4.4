extends TextureRect

func _ready():
	texture = Utils.game.ui.get_node("%Minimap/SeismicMap").viewport_1.get_texture()

func add_indicator(position, radius):
	return
