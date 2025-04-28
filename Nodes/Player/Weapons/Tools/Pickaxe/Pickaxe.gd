extends Node2D

@onready var hit_pos := $Marker2D as Node2D

var data: PickaxeData

func set_data(pickaxe: String):
	data = load("res://Nodes/Player/Weapons/Tools/Pickaxe/PickaxeData/" + pickaxe + ".tres")
	$Sprite2D.texture = data.texture
	$AnimationPlayer.playback_speed = data.speed


func animation_finished(anim_name: String) -> void:
	queue_free()

func mine():
	var ray := Utils.game.map.pixel_map.rayCastQTFromTo(global_position, hit_pos.global_position, Utils.walkable_collision_mask)
	if ray:
		Utils.connect("exploded_terrain", Callable(self, "mine_success").bind(), CONNECT_ONE_SHOT)
		Utils.explode_circle(ray.hit_position, data.hit_range, data.hit_damage, data.hit_strength)

func mine_success():
	Utils.play_sample(Utils.random_sound("res://SFX/Player/Mining (Hitting Stone With Pickaxe)"), self, false, 1.1)
