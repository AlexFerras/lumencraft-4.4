extends Area2D

@onready var particles := $GPUParticles2D as GPUParticles2D
@onready var cracks=$ExplosionCracks
@onready var light=$LightSprite
enum {PLAYER, ENEMY, NEUTRAL, ALL, ALL_NOT_PLAYER}
var type: int = ALL_NOT_PLAYER
var dmg :int = -1
var durability_threshold :int = 20
var terrain_explosion_radius :int = -1
var terrain_explosion_dmg :int = -1
var pitch :float = 1.0
var drops_shadow :bool = true
@onready var collider= $CollisionShape2D
const c= (1.0/0.6)
var fortified=1.0
var no_smoke=false

func get_falloff_damage():
	
	return max((1.0-collider.scale.x)*c*dmg+1,1)
	

func _ready() -> void:
	Utils.play_sample(Utils.random_sound("res://SFX/Explosion/explosion_small"), self, false, 1.0, pitch)
	if dmg==-1:
		dmg = 120 * scale.x
	light.drop_shadow=drops_shadow
	light.scale = scale * 4
	create_tween().tween_property(light, "modulate:a", 0.0, 0.5).set_delay(0.5)
	
	if type == PLAYER:
		Utils.init_player_projectile(self, self, {damage = dmg, keep = true, damage_timeout=2000, falloff=2,fortified=fortified})
	if type == ENEMY:
		Utils.init_enemy_projectile(self, self, {damage = dmg, keep = true, damage_timeout=2000, falloff=2,fortified=fortified})
	if type == ALL_NOT_PLAYER:
		Utils.init_player_projectile(self, self, {damage = dmg, keep = true, damage_timeout=2000, falloff=2,fortified=fortified})
		Utils.init_enemy_projectile(self, self, {damage = dmg, keep = true, damage_timeout=2000, falloff=2,fortified=fortified})
		Utils.set_collisions(self, Const.ENEMY_COLLISION_LAYER | Const.BUILDING_COLLISION_LAYER, Utils.ACTIVE)
	if type == ALL:
		Utils.init_player_projectile(self, self, {damage = dmg, keep = true, damage_timeout=2000, falloff=2,fortified=fortified})
		Utils.init_enemy_projectile(self, self, {damage = dmg, keep = true, damage_timeout=2000, falloff=2,fortified=fortified})
		Utils.set_collisions(self, Const.PLAYER_COLLISION_LAYER | Const.ENEMY_COLLISION_LAYER | Const.BUILDING_COLLISION_LAYER, Utils.ACTIVE)
	Utils.game.map.post_process.add_shockwave(global_position, 400 * scale.x)
	cracks.frame=randi()%4
	cracks.rotation=TAU*randf()
	var tmp_trans=cracks.global_transform
	remove_child(cracks)
	Utils.game.map.add_child(cracks)
	cracks.global_transform=tmp_trans
	if no_smoke:
		particles.emitting = true
	if terrain_explosion_radius<0:
		terrain_explosion_radius = 135 * scale.x	
	if terrain_explosion_dmg<0:
		terrain_explosion_dmg =  terrain_explosion_radius * 1800
	Utils.game.shake_in_position(global_position, 20 * scale.x)
	Utils.explode(global_position, terrain_explosion_radius, terrain_explosion_dmg, 0.4, durability_threshold,-1,false,0.6,true)
	get_tree().create_timer(particles.lifetime / particles.speed_scale).connect("timeout", Callable(self, "queue_free"))
