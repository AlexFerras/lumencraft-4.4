@tool
extends Sprite2D

@export var show_rects =true: set = set_show_rects


func set_show_rects(new_show):
	show_rects=new_show
	for i in get_children():
		i.show_preview_rect(new_show)


