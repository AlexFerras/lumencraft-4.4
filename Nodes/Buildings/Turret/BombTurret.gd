extends "res://Nodes/Buildings/Turret/GunTurret.gd"

var explosion_power: float
var explosion_damage: int
var min_range: float
var cluster_lvl=0
#
#func _target_found():
#	shoot_timer = base_shoot_delay

func _ready() -> void:
	shoot_delay = base_shoot_delay
	shoot_timer = base_shoot_delay

func _shoot():
	animator.play("shoot")
	Utils.play_sample(Utils.random_sound("res://SFX/Weapons/gun_grenade_launcher_shot"), self,1.1)
	var bullet := preload("res://Nodes/Buildings/Turret/BombBullet.tscn").instantiate() as Node2D
	bullet.rotation = angle_to_target
	bullet.position = shoot_point.global_position
	var forward_vec=Vector2.RIGHT.rotated(shoot_point.global_rotation)
	Utils.game.map.pixel_map.smoke_manager.spawn_in_position(shoot_point.global_position, 10,forward_vec*5.0,Color(0.7,0.7,0.7,0.5))
	Utils.game.map.pixel_map.fire_manager.spawn_in_position(shoot_point.global_position, 20,forward_vec*20.0,Color(0.2,0.2,0.2,1.0))
	var distance = distance_to_target
	if distance <= min_range:
		bullet.target_distance = min_range - global_position.distance_to(shoot_point.global_position)
	else:
		bullet.target_distance = distance - global_position.distance_to(shoot_point.global_position)
	bullet.power = explosion_power
	bullet.damage = explosion_damage
	bullet.cluster=cluster_lvl*2
	Utils.game.map.add_child(bullet)

func _refresh_upgrades(upgrades: Dictionary):
	explosion_power = 0.15 + log( upgrades.custom_explosion_power + 1 ) * 0.1
	min_range = explosion_power * 150 + radius
	# explosion_power lvl 0 = 0.15       exp radius 20.25
	# explosion_power lvl 1 = 0.219315   exp radius 29.6075
	# explosion_power lvl 2 = 0.259861   exp radius 35.0812
	explosion_damage = 20 + upgrades.explosion_damage * 10
	cluster_lvl = upgrades.cluster


func set_mask_power_ON():
	pass
	
func set_mask_power_OFF():
	pass
