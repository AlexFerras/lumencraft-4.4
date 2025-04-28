extends Node

var tick_delay=0
func _physics_process(delta):
	tick_delay+=1
	if tick_delay==5:
		for i in get_tree().get_nodes_in_group("wave_spawners"):
			i.set_random_marker(true)
			i.marker.visible=true
			set_physics_process(false)
