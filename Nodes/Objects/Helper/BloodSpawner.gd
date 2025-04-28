extends Node2D

var splatters = []
var splatters_max_count := 100
var idx := 0

@onready var splat = preload("res://Nodes/Objects/Deco/Splat.tscn")
func _ready():
	splatters.resize(splatters_max_count)

func add_splat(pos:Vector2,vel:Vector2, size:int = 4):
	size = max(size/1.5, 4.0)
	var intensity = 0.05 * pow(size/4.0, 4)
	Utils.game.map.floor_surface2.update_data_raw(pos / 8.0, size, Color(0.0, 0.0, 0.0, intensity), 1.0, PixelMap.ADD)
	if is_instance_valid(splatters[idx]):
		splatters[idx].fade()
	var splat_inst = splat.instantiate()
	splat_inst.position = pos
	splat_inst.rotation = vel.angle()
	add_child(splat_inst)
	splatters[idx] = splat_inst
	idx = (idx+1) % splatters_max_count

