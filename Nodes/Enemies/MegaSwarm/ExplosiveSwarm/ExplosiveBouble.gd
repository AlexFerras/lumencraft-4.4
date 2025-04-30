extends Area2D
class_name ExplosiveBouble

@export var patterns:Array[ImageTexture] # (Array, ImageTexture)

@onready var colision_shape := $CollisionShape2D


var player_speed = 600
var player_speed_on_bouble = 200

var can_dmg = true

var explosion_damage = 20
var explosion_radius = 20
var explosion_terrain_damage = 500

func _ready() -> void:
	$Sprite2D.rotation = randf() * TAU
	$Sprite2D.flip_h = randi() % 2
	$Sprite2D.flip_v = randi() % 2
	
	Utils.play_sample("res://SFX/Explosion/explosive_bouble.wav", position, false, 1.3, 1)

func set_explosion_params(dmg, terrain_dmg, radius):
	explosion_damage = dmg
	explosion_terrain_damage = terrain_dmg
	explosion_radius = radius

func do_explosive_dmg():
	Utils.explode_circle(position, explosion_radius, explosion_terrain_damage, 3, 9)
	var damager=preload("res://Nodes/Enemies/MegaSwarm/Damager.tscn").instantiate()
	damager.scale=Vector2.ONE*explosion_radius
	Utils.init_enemy_projectile(damager,damager, {damage=explosion_damage})
	add_child(damager)
	damager.global_position = position
	
	#Utils.init_enemy_projectile(hit_box, hit_box, {damage = 1, keep = true})

func disable_bouble():
	colision_shape.disabled = true
	can_dmg = false

func _on_boubles_area_entered(area):
	var area_parent = area.get_parent()
	if area_parent:
		if area_parent in Utils.game.players:
			area_parent.max_speed = player_speed_on_bouble


func _on_boubles_area_exited(area):
	var area_parent = area.get_parent()
	if area_parent:
		if area_parent in Utils.game.players:
			var is_overlapping_another_bouble = false
			for overlaping_area in area.get_overlapping_areas():
				if overlaping_area.is_class("ExplosiveBouble"):
					is_overlapping_another_bouble = true
					break
			if !is_overlapping_another_bouble:
				area_parent.max_speed = player_speed
