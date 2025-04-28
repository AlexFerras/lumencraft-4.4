extends Node2D

@onready var flame_core := $Flame_core
@onready var flame_smoke := $Flame_smoke
var base_smoke_direction = Vector3.ZERO
var base_smoke_velocity = 0.0
var base_core_velocity = 0.0

var global_gun_dir := Vector2.RIGHT
var smoke_speed := 0.0
var core_speed := 0.0
var player_speed := 0.0
var resultant := Vector2.ZERO

func _ready() -> void:
	flame_core.global_scale  /= flame_core.global_scale
	flame_smoke.global_scale /= flame_smoke.global_scale
		
	flame_smoke.process_material.set_shader_parameter("map_texture",Utils.game.map.pixel_map.get_texture())
	flame_core.process_material.set_shader_parameter("map_texture", Utils.game.map.pixel_map.get_texture() )


#	show()

func set_flame_power(power: int):
	match power:
		2:
			flame_core.amount = 300
			flame_core.process_material.set_shader_parameter("spread", 15)
			flame_smoke.amount = 150
			flame_smoke.process_material.set_shader_parameter("spread", 15)
		3:
			flame_core.amount = 400
			flame_core.process_material.set_shader_parameter("spread", 25)
			flame_smoke.amount = 200
			flame_smoke.process_material.set_shader_parameter("spread", 25)

func set_flame_range(rang: int):
	match rang:
		0:
			smoke_speed = 60
			core_speed  = 72.0
		1:
			smoke_speed = 80
			core_speed  = 96.0
		2:
			smoke_speed = 100
			core_speed  = 120.0

func shoot(player:Player):
	flame_core.emitting  = true
	flame_smoke.emitting = true
	
	global_gun_dir = Vector2.RIGHT.rotated(global_rotation)
	resultant = (global_gun_dir * smoke_speed ).rotated(-global_rotation)
	
	flame_smoke.process_material.set_shader_parameter("direction",Vector3(resultant.x, resultant.y, 0.0).normalized())
	flame_smoke.process_material.set_shader_parameter("initial_linear_velocity",resultant.length())

	resultant = (global_gun_dir * core_speed).rotated(-global_rotation)

	flame_core.process_material.set_shader_parameter("direction", Vector3(resultant.x, resultant.y, 0.0).normalized() )
	flame_core.process_material.set_shader_parameter("initial_linear_velocity", resultant.length() )
	
func stop():
	flame_core.emitting = false
	flame_smoke.emitting = false
#	hide()

func kill():
	stop()
	get_tree().create_timer(max(flame_core.lifetime, flame_smoke.lifetime) * 2, false).connect("timeout", Callable(self, "queue_free"))

#func _physics_process(delta):
#	update()

#func _draw():
#	var size := Vector2(20,20)
#	for p in range($Smoketrail2.get_point_count()):
#		draw_rect(Rect2($Smoketrail2.points[p], size), Color.white, true)
