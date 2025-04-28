extends PixelMapRigidBody

enum {IDLE, ATTACK, FOLLOW_PLAYER, SHOOTING}

@export var player_id: int

var player: Player
var state: int = IDLE
var cost: int = 50
var is_dead :bool = false
var is_pushed :bool = false
@export var hp := 100

@onready var collider := Utils.get_node_by_type(self, Area2D) as Area2D
@onready var on_hit_audio := $OnHitAudio

func _ready() -> void:
	player = Utils.game.players[player_id]
	add_to_tracker()
	collider.collision_layer = Const.PLAYER_COLLISION_LAYER
	collider.collision_mask = 0

func _physics_process(delta: float) -> void:
	match state:
		IDLE:
			_idle(delta)
		ATTACK:
			_attack(delta)
		FOLLOW_PLAYER:
			_follow_player(delta)
		SHOOTING:
			_shoot(delta)

func _idle(delta: float):
	pass

func _attack(delta: float):
	pass
	
func _follow_player(delta: float):
	pass

func _shoot(delta: float):
	pass

func _die():
	is_dead = true
	Utils.play_sample(Utils.random_sound("res://SFX/Explosion/Explosion Gas_"), self, false, 1.0, 0.9)
	for i in cost:
		Pickup.launch({id = 0, amount = 1}, global_position, Vector2.RIGHT * 50)
	queue_free()

func add_to_tracker():
	Utils.add_to_tracker(self, Utils.game.map.pet_tracker, radius, 999999)

func area_collided(area) -> void:
	if area.is_in_group("enemy_projectile"):
		area.set_meta("last_attacked", self)
		Utils.on_hit(area)
		if handle_damage(area.get_meta("data")):
			check_hp()
			
func on_body_entered(body):
	if body is Player:
		on_pushed()

func on_pushed():
	pass

func handle_damage(data: Dictionary) -> bool:
	if is_dead:
		return false
	
	var damager = data.get("owner")
	
	var dmg: int
	if damager is Node2D:
		if damager.is_in_group("enemies"):
			dmg = damager.damage
		elif "falloff" in data:
			dmg = damager.get_falloff_damage()
		else:
			dmg = damager.get_meta("data").damage
		linear_velocity += ((global_position - damager.global_position).normalized() * dmg * 15).limit_length(1000.0)
		
	elif damager is int:
		dmg = 5
	else:
		dmg = data.damage
	
	if dmg == 0:
		return false
	
#	if not on_hit_audio.playing:
	Utils.play_sample(Utils.random_sound("res://SFX/Bullets/bullet_impact_metal_light_"), on_hit_audio, true, 1.1)
	if Save.config.show_damage_numbers:
		Utils.game.map.add_dmg_number().setup(self, dmg, Color.YELLOW)
	hp = max(hp - dmg, 0)
	return true

func check_hp():
	if is_dead:
		return
	
	if hp <= 0:
		_die()
