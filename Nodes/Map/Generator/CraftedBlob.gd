@tool
extends "res://Nodes/Map/Generator/WhiteBlob.gd"

func set_rect(rect: String):
	texture = ImageTexture.new()
	texture.create_from_image(Constants.get_crafted_rect(rect).image)
