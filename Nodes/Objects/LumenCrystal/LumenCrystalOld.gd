
extends StaticBody2D

@export var type: int: set = set_type
@export var base_color :=Color.WHITE: set = set_color
var amount := 10.0
var max_hp := 10.0

var actual_hp := 10.0
var spawn_hp := 10.0
var break_player: Node

@onready var sprite := $Sprite2D as Sprite2D

var noise = FastNoiseLite.new()
var timer := 0.0

func _ready() -> void:
	timer=randf()
	noise.seed = randi()
	noise.fractal_octaves = 1
	noise.period = 10.0
	noise.persistence = 0.8
	
	actual_hp = max_hp
	spawn_hp=max_hp - (max_hp/amount)
#	sprite.modulate = base_color
	$LightSprite.modulate = base_color


func on_enter(area: Area2D) -> void:
	if is_queued_for_deletion():
		return
	
	if area.is_in_group("player_projectile"):
		Utils.on_hit(area)
		
		actual_hp -= 1
		
		while actual_hp <= spawn_hp:
			Utils.game.map.pickables.spawn_pickable_nice(global_position, Const.ItemIDs.LUMEN,  Vector2.RIGHT.rotated(randf() * TAU) * randf_range(70, 120))
			spawn_hp -= (max_hp/amount)
		sprite.material.set_shader_parameter("destruction", 1.0-(actual_hp / max_hp))
		
		if is_instance_valid(break_player):
			break_player.queue_free()
		
		if actual_hp <= 0.0:
			Utils.play_sample(Utils.random_sound("res://SFX/Crystal/Glass breaking"), self)
			queue_free()
		else:
			break_player = Utils.play_sample(Utils.random_sound("res://SFX/Crystal/Glass item Breaks"), self, false, 1.1)
			
func set_color(new_color: Color)->void:
	base_color = new_color
	if not is_inside_tree():
		await self.ready
	$LightSprite.modulate = base_color
	$Sprite2D.material.set_shader_parameter("base_color", new_color)
	
func set_type(t: int):
	type = t
	
	if not is_inside_tree():
		await self.ready
	
	type = clamp(type, 0, $Sprite2D.hframes - 1)
	$Sprite2D.frame = type
	$CollisionShape2D.shape.extents = [Vector2(32, 60), Vector2(32, 60), Vector2(23, 39), Vector2(15, 16)][type] * $Sprite2D.scale
	$CollisionShape2D.position = [Vector2(0, -52), Vector2(0, -52), Vector2(0, -30), Vector2(3, -10)][type] * $Sprite2D.scale
	$Detector/CollisionShape2D.position = $CollisionShape2D.position
	$LightSprite.position = $CollisionShape2D.position
	$LightSprite.scale = [Vector2(0.1, 0.2), Vector2(0.1, 0.2), Vector2(0.1, 0.15), Vector2(0.1, 0.1)][type] * $Sprite2D.scale
