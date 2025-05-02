@tool
extends ReferenceRect


@export var recalculate: bool: set = set_recalculate
# Declare member variables here. Examples:
# var a = 2
# var b = "text"

func set_recalculate(new_val):
	calculate_resources()
	
func calculate_resources():
	if Engine.is_editor_hint():
		var pixelmap: PixelMap=get_tree().edited_scene_root.find_child("PixelMap")
		if pixelmap:
			var global_rect = get_global_rect()
			var hist=pixelmap.get_materials_histogram_rect(Rect2(global_rect.position, global_rect.size), true)
			for i in Const.Materials:
				print(i ," ", hist[int(Const.Materials[i])], "   ")

func ingame_calculate_walls():
	var pixelmap: PixelMap=Utils.game.map.pixel_map
	if pixelmap:
		var global_rect = get_global_rect()
		var hist=pixelmap.get_materials_histogram_rect(Rect2(global_rect.position, global_rect.size), true)
#		for i in Const.Materials:
#			print(i ," ", hist[int(Const.Materials[i])], "   ")
		return hist[Const.Materials.WALL]+2*hist[Const.Materials.WALL1]+3*hist[Const.Materials.WALL2]+3*hist[Const.Materials.WALL3]
