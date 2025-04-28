extends Node2D
class_name BaseEnemy

@export var is_ignoring_weapons: bool
@export var tracking_enabled := true
@export var override_stats: Dictionary
@export var base_scene: String

@onready var collider := Utils.get_node_by_type(self, Area2D) as Area2D

var pixelmap: PixelMap
var physics: PixelMapPhysics
#var player: Node2D

var is_dead: bool
var is_triggered: bool
var is_invincible: bool
var velocity_killed: Vector2 = Vector2(0,0)

var initialized: bool
@export var max_hp: int
var hp: int
@export var damage: int
var threat: int
var terrain_speed_multiplier = 1.0

var radius: float
var enemy_data: Dictionary

var probability_spawn_resource=20
var loot: Array

var doing_something_important_timer = 0.0
var cancel_tracking: bool
var need_reset: bool
var loaded: bool

signal hp_changed
signal died
signal resource_spawned

func _enter_tree() -> void:
	if initialized:
		return
	
	if base_scene.is_empty():
		base_scene = filename
	
	if enemy_data.is_empty():
		for enemy in Const.Enemies.values():
			if enemy.scene == base_scene:
				enemy_data = enemy
				break
	
	if enemy_data.is_empty():
		enemy_data = {hp = 1, damage = 1, threat = 0}
		push_error(str("Missing enemy data for ", base_scene, ". Add it to res://Resources/Data/Enemies.cfg."))
	
	max_hp = override_stats.get("hp", enemy_data.hp)
	if loaded:
		call_deferred("emit_signal", "hp_changed")
	else:
		hp = max_hp
	damage = override_stats.get("damage", enemy_data.damage)
	threat = enemy_data.threat
	initialized = true
	
	var sprite := get_node_or_null(@"Sprite2D") as Sprite2D
	if sprite:
		sprite.modulate = override_stats.get("color", Color.WHITE)

func get_enemy_radius():
	var rad=0.0
	var are=collider if collider else Utils.get_node_by_type(self, Area2D)
	if !are:
		return rad
	var collider_shape := Utils.get_node_by_type(are, CollisionShape2D) as CollisionShape2D
	if collider_shape:
		if collider_shape.shape is CircleShape2D:
			rad = collider_shape.shape.radius
		elif collider_shape.shape is RectangleShape2D:
			rad = max(collider_shape.shape.extents.x, collider_shape.shape.extents.y)
		rad *= Utils.get_global_transform_until_null(collider_shape).get_scale().x
	return rad

func _ready() -> void:
	assert(collider, "BaseEnemy requires at least one Area2D child.")
	collider.set_meta("parent_enemy", self)
	collider.connect("area_entered", Callable(self, "enter_the_area"))
	
	pixelmap = Utils.game.map.pixel_map as PixelMap
	physics =  Utils.game.map.physics as PixelMapPhysics
	
	add_to_group("enemies")

	if collider:
		collider.set_meta("enemy_hitbox", true)
		Utils.set_collisions(collider, Const.ENEMY_COLLISION_LAYER, Utils.PASSIVE)
		
		radius=get_enemy_radius()
	
	call_deferred("set_tracking")

	var health_bar: Node2D = preload("res://Nodes/Enemies/Common/HealthBar.tscn").instantiate()
	health_bar.get_child(0).max_value = enemy_data.hp
	connect("hp_changed", Callable(health_bar.get_child(0), "update_value"))
	add_child(health_bar)
	
	for child in get_children():
		if child.name.begins_with("Loot"):
			loot.append(child)

func _physics_process(delta):
	if tracking_enabled and not is_dead:
		if doing_something_important_timer > 0 :
			doing_something_important_timer -= delta
		elif need_reset:
			reset_tracking(0)
			need_reset = false
		
	var material_at = Utils.game.map.pixel_map.get_pixel_at(global_position).g8
	if material_at == Const.Materials.EMPTY:
		terrain_speed_multiplier = 1.0
	elif material_at == Const.Materials.LAVA:
		take_damage_raw({damage=1})
	elif material_at == Const.Materials.TAR and Save.is_tech_unlocked("sticky_napalm"):
		terrain_speed_multiplier = 0.5


func enter_the_area(area: Area2D) -> void:
	if is_dead or is_invincible or area.owner == self:
		return
	take_damage(area)

func launch_attack(target: Node2D):
	pass

func take_damage(source: Node2D):
	if is_dead or not source.has_meta("data"):
		return
	var data=source.get_meta("data")
	if "falloff" in data:
		velocity_killed = (global_position-source.global_position).normalized()*source.get_falloff_damage()*20.0
	take_damage_raw(data)

func take_damage_raw(data: Dictionary):
	var dmg := handle_damage(self, enemy_data, data)
	
	if dmg != 0:
		hp -= dmg
		emit_signal("hp_changed")
	if data.has("velocity"):
		velocity_killed = data.get("velocity", Vector2())
	if hp <= 0:
		if data.has("owner") and data.owner.has_meta("isFlare"):
			SteamAPI.unlock_achievement("KILL_FLARE")
		SteamAPI.increment_stat("KilledBugs")
		if data.has("monster"):
			SteamAPI.unlock_achievement("MONSTER_ON_NOMSTER")
		_killed()
	else:
		Utils.game.start_battle()
		on_hit(data)

func _killed():
	if is_dead:
		return
	is_dead = true

	Utils.remove_from_tracker(self)

	Save.count_score("enemies_slain")
	get_tree().call_group("kill_observers", "enemy_killed", enemy_data.name)
	
	if false and randf() > max(sqrt(float(Utils.game.main_player.hp) / Utils.game.main_player.max_hp), 0.4): ## można ewentualnie przerobić
		var medkit := load("res://Nodes/Pickups/HealthKit/Medkit.tscn").instantiate() as Node2D
		medkit.velocity = velocity_killed * 0.1
		Utils.game.map.call_deferred("add_child", medkit)
		medkit.global_position = global_position

	emit_signal("died")
	

	
	if probability_spawn_resource > 0:
		if not loot.is_empty():
			for drop in loot:
				drop.spawn_items()
			emit_signal("resource_spawned")
		var what_to_spawn: int = randi() % probability_spawn_resource
		if what_to_spawn == 0:
			Utils.game.map.pickables.spawn_premium_pickable_nice(global_position, Const.ItemIDs.METAL_SCRAP)
			emit_signal("resource_spawned")
		elif what_to_spawn == 1:
			Utils.game.map.pickables.spawn_premium_pickable_nice(global_position, Const.ItemIDs.LUMEN)
			emit_signal("resource_spawned")
	
	on_dead()

func on_dead():
	spawn_flaki()
	queue_free()

func is_kill_damage(dmg: int) -> bool:
	return dmg >= hp

func is_overkill() -> bool:
	return -hp > max_hp * 0.2

func on_hit(data: Dictionary): # Kiedy ktoś go uderzy.
#	var seq := weenSequence.new(get_tree())
#	seq.append(self, "modulate", Color(1.0, 0.5, 0.5), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
#	seq.append(self, "modulate", Color.white, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	pass

func spawn_flaki():
	Utils.game.map.blood_spawner.add_splat(position, velocity_killed, radius)
	Utils.game.map.pixel_map.flesh_manager.spawn_in_position(global_position, radius*4.0, velocity_killed * 0.2)



static func handle_damage(target: Node2D, target_data: Dictionary, damage_data: Dictionary) -> int:
	if damage_data.get("destroyed", false):
		return 0
	
	var attacker: Node2D = damage_data.get("owner")
	var attacker_collider: Area2D = damage_data.get("collider")
	var dmg: int = damage_data.damage
	
	var luck = 0
	if is_instance_valid(attacker) and attacker.get("player") and attacker.player.has_method("get_luck"):
		luck = attacker.player.get_luck() + 1
		
	var is_crit = damage_data.get("critical", false)
	var crit_roll = damage_data.get("crit_rate", 0) * luck
	if randi()%100 < crit_roll:
		dmg = ceil(dmg*2.0)
		is_crit = true
		if target.has_method("slow_on_crit"):
			target.slow_on_crit()
	if target_data.get("evade_heavy") and damage_data.get("aspect", -1) == Const.Aspects.HEAVY and randi() % 100 < target_data.get("miss_chance", 75):
		if Save.config.show_damage_numbers:
			var number = Utils.game.map.add_dmg_number()
			number.miss(target)
			
			if target.has_method("on_damage_number"):
				target.on_damage_number(number)
		return 0
	var was_antiair=false
	var antiair=damage_data.get("antiair")
	if antiair and target_data.get("flying"):
		dmg*=antiair
		was_antiair=true
	
	var resisted: bool
	if attacker:
		if attacker.is_in_group("player_projectile") or (attacker_collider and attacker_collider.is_in_group("player_projectile")):
			if target_data.get("ignore_weapons"):
				return 0
			
			if "falloff" in damage_data:
				dmg = attacker.get_falloff_damage()
				if target_data.get("flying"):
					dmg*=0.5
					resisted=true
			
			if attacker.has_signal("attacked"):
				attacker.emit_signal("attacked")
			
			attacker.set_meta("last_attacked", target)
			Utils.on_hit(attacker, target_data)
	
	if target_data.get("resist_weak") and damage_data.get("aspect", -1) == Const.Aspects.WEAK:
		dmg = max(0.33 * dmg,1.0)
		resisted = true
	
			
	if Save.config.show_damage_numbers:
		var damage_color := Color.ORANGE_RED
		if was_antiair:
			damage_color = Color.GREEN_YELLOW
		if resisted:
			damage_color = Color.LIGHT_PINK
		if target.is_kill_damage(dmg):
			damage_color = Color.RED
		if is_crit:
			damage_color = Color(3,1,1,1.0)
		
		var number = Utils.game.map.add_dmg_number()
		if dmg == 0:
			number.immune(target)
		elif is_crit:
			number.crit(target, dmg, damage_color)
		else:
			number.setup(target, dmg, damage_color)
	
		if target.has_method("on_damage_number"):
			target.on_damage_number(number)
	
	return dmg

func override_custom_stat(stat: String, target_object: Object, target_property: String):
	if stat in override_stats:
		target_object.set(target_property, override_stats[stat])

func set_tracking():
	if cancel_tracking:
		return
	
	Utils.add_to_tracker(self, Utils.game.map.enemy_tracker, radius, int(not tracking_enabled) * 99999)

func reset_tracking( additional_radius:float = 99999 ):
	if cancel_tracking:
		return
	
	Utils.remove_from_tracker(self)
	Utils.add_to_tracker(self, Utils.game.map.enemy_tracker, radius, additional_radius)

func set_focused_tracking():
	if doing_something_important_timer <= 0:
		need_reset = true
		reset_tracking()
	doing_something_important_timer = 6

func reset_loot():
	for drop in loot:
		drop.queue_free()
	loot.clear()

func set_rotation(rot: float):
	assert(false, "Zaimplementuj mnie ;_;")

func _should_save() -> bool:
	return not is_dead

func _get_save_data() -> Dictionary:
	return Save.get_properties(self, ["hp", "stat_overrides", "probability_spawn_resource", "cancel_tracking"])

func _set_save_data(data: Dictionary):
	Save.set_properties(self, data)
	loaded = true

func is_condition_met(condition: String, data: Dictionary) -> bool:
	match condition:
		"killed":
			return is_dead
	
	return false

func execute_action(action: String, data: Dictionary):
	match action:
		"die":
			hp = 0
			_killed()

func add_rage( value ):
	pass

func add_light_tolerance( value ):
	pass
