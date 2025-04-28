extends "res://Nodes/Player/Weapons/Throwable/ThrowableWeapon.gd"

@onready var sprite := $Sprite2D as Sprite2D

@export var power: float = 0.35

func _physics_process(delta: float) -> void:
	sprite.rotation += linear_velocity.x * 0.1 * delta

func _on_Timer_timeout() -> void:
	var explosion := Const.EXPLOSION.instantiate() as Node2D
	explosion.durability_threshold=5
	explosion.scale = Vector2.ONE * power
	explosion.position = position
	get_parent().add_child(explosion)
	queue_free()
