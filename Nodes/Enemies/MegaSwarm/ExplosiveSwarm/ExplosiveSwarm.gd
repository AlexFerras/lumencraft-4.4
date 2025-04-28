@tool
extends SwarmSpider
@export var explosion_damage := 20.0
@export var explosion_terrain_damage = 500
@export var explosion_radius := 20.0

var explosive_bouble_scene = preload("res://Nodes/Enemies/MegaSwarm/ExplosiveSwarm/ExplosiveBouble.tscn")

func setup_attacks():
	addNewAttack(attack_range, attack_delay, self, "explosive_attack", 192.0, false, true, true, 0.99, 2*PI)
	addNewAttack(attack_range, attack_delay, self, "terrain_attack", 192.0, true, false, false, 0.5)

func spawn_explosive_bouble(position: Vector2):
	var explosive_bouble = explosive_bouble_scene.instantiate()
	explosive_bouble.set_explosion_params(explosion_damage, explosion_terrain_damage, explosion_radius)
	explosive_bouble.position = position
	Utils.game.map.add_child(explosive_bouble)

func explosive_attack(attack_id: int, position: Vector2, heading: Vector2, target: Node, attacker_unit_id: int, in_distance_from_focus_check: bool):
	damageUnit(attacker_unit_id, max_hp)
	spawn_explosive_bouble(position)

func on_damage_callback(position: Vector2, damager: Node, unit_id: int, in_distance_from_focus_check: bool):
	var computed_id := (get_index() << 32) | unit_id
	
	var data: Dictionary = damager.get_meta("data")
	if data.get("destroyed", false):
		return
	
	if not "ids" in data:
		data.ids = {}
	
	var damage_timeout: float = data.get("damage_timeout", 20.0)
	if data.ids.get(computed_id, -1000000) >= Utils.game.frame_from_start - damage_timeout:
		return
	
	current_damaged_position = position
	current_damaged_hp = getUnitHP(unit_id)
	
	var damage := BaseEnemy.handle_damage(self, {evade_heavy = true, miss_chance = 98}, data)
	var hp_left := damageUnit(unit_id, damage)
	Utils.get_audio_manager("gore_hit").play(position)
	data.ids[computed_id] = Utils.game.frame_from_start
	
	if hp_left <= 0:
		_killed += 1
		emit_signal("died")
		Save.count_score("enemies_slain")
		get_tree().call_group("kill_observers", "enemy_killed", swarm_data.name)
		
		var velocity_killed = data.get("velocity", Vector2())
		Utils.game.map.pixel_map.flesh_manager.spawn_in_position(position, 4,velocity_killed*0.2)
		if in_distance_from_focus_check:
			Utils.get_audio_manager(dead_sound_manager).play(position)

		if probability_spawn_resource > 0:
			var what_to_spawn=randi()% probability_spawn_resource
			if what_to_spawn==0:
				Utils.game.map.pickables.spawn_premium_pickable_nice(position, Const.ItemIDs.LUMEN)
				emit_signal("spawned_resource")
			elif what_to_spawn==1:
				Utils.game.map.pickables.spawn_premium_pickable_nice(position, Const.ItemIDs.METAL_SCRAP)
				emit_signal("spawned_resource")
		
		enemies_killed += 1
		if auto_remove and enemies_killed == enemies_spawned:
			get_tree().create_timer(16).connect("timeout", Callable(self, "queue_free"))
			
		spawn_explosive_bouble(position)
	else:
		Utils.game.start_battle()
