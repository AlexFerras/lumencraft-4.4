@tool
extends Node
class_name ZIndexer

enum Indexes {
	FOG_OF_WAR = 3000,
	LIGHTS = 2000,
	DRONES = 1000,
	SMOKE = 900,
	BOSS = 800,
	BIG_DECOR = 700,
	BUILDING_HIGH = 600,
	PIX_MAP = 500,
	BIG_MONSTER = 400,
	MEDIUM_MONSTER = 300,
	PLAYER = 200,
	OBJECTS = 150,
	SMALL_DECOR = 140,
	SWARM = 100,
	PICKUPS = 50,
	FLAKI = -50,
	BUILDING_LOW = -200,
	FLOOR_DECOR = -500,
	SHADOWS = -900,
	FLOOR = -1000,
}

@export var z_index: Indexes: set = set_preset
@export var offset: int: set = set_offset

func set_preset(new_z):
	z_index=new_z
	if get_parent():
		_ready()
func set_offset(new_off):
	offset=new_off
	if get_parent():
		_ready()


func _ready() -> void:
	assert(get_parent() is Node2D)
	
	get_parent().z_index = z_index + offset
	get_parent().z_as_relative = false
	
	if not Engine.is_editor_hint():
		queue_free()
