@tool
extends "res://Nodes/Map/Generator/rect_generator.gd"

var resources=[Const.Materials.WEAK_SCRAP,Const.Materials.STRONG_SCRAP,Const.Materials.ULTRA_SCRAP]

func rect_placed_randomizer():
	
	var generator = $"%GeneratedMapBase"
	var metal_type= get_suggested_metal_material(position+size*0.5)
	for sprite in $preview.get_children():
		sprite.material_type=metal_type

