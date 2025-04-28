extends Node2D

@onready var shoot_point := $Sprite2D/ShootPoint as Node2D
@onready var muzzle_flash := get_node_or_null("Sprite2D/ShootPoint/MuzzleFlash")

@export var autofire := false

var player: Player

#func _ready() -> void:
#	var laser := get_node_or_null(@"%LaserSight")
#	if laser:
#		laser.global_rotation = player.get_shoot_rotation()

func shoot(bullet: Node2D):
	if muzzle_flash:
		muzzle_flash.shoot(not autofire)

func deshoot():
	if muzzle_flash:
		muzzle_flash.stop()
