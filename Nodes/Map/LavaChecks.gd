extends Node2D

signal lava_touching

@export var lava_check_random= 2.0
var next_lava_check=randf_range(0.5,lava_check_random)
var is_in_lava=false
@export var inv_smoke_size=0.1
@export var smoke_color=Color(0.7,0.7,0.7)
@export var smoke_rand=0.0

func _physics_process(delta):
	next_lava_check-=delta
	if next_lava_check<0:
		next_lava_check=randf_range(0.5,lava_check_random)
		if is_lava_touching():
			emit_signal("lava_touching")
	if is_in_lava:
		var children=get_children()
		var where=lerp(children[randi()%children.size()].global_position,children[randi()%children.size()].global_position, randf())
		var col=Color(smoke_color.r,smoke_color.g,smoke_color.b)*randf_range(smoke_rand,1.0)
		
		col.a=randf_range(inv_smoke_size,1.0)

		Utils.game.map.pixel_map.smoke_manager.spawn_in_position(where, 1,Vector2(0,0), col)
		


func is_lava_touching():
	var children=get_children()
	for i in children:
		if Utils.game.map.pixel_map.get_pixel_at(i.global_position).g8 == Const.Materials.LAVA:
			is_in_lava=true
			return true
	is_in_lava=false
	return false

