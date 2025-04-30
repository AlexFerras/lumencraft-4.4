extends Area2D
class_name BaseBuilding

@onready var pickables: PixelMapPickables = Utils.game.map.pickables
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var socket: Node2D = get_node_or_null("Socket")

@export var owning_player_id: int = -1
@export var angle: float: set = set_angle
@export var radius := 30.0
@export var take_damage_from_player: bool
@export var disable_mask: bool
@export var needs_power := true

var disable_power: bool
var hack: bool
var building_data: Dictionary
@export var enemy_ignore: bool

var max_hp: int = 50
var max_upgrade: int
var cost: Dictionary
var building_name: String
var hp: int

var regenerate: float = 0.0
var regen_timer: float

var is_running := false
var first_check := true

var lava_check_random := 2.0
var next_lava_check := randf_range(0.5, lava_check_random)
var is_destroyed: bool
var in_construction: bool
var resource_ratio := 1.0
var just_damaged_by_lava: bool
var bulldozer_position=Vector2.ZERO
var bulldozer_start=0

signal hp_changed
signal destroyed

func init_range_extender(range_radius: float,  color_int: float = 0):
	init_range_extender_node(self, range_radius, color_int)

static func init_range_extender_node(node, range_radius: float,  color_int: float =0):
	if color_int != 0:
		node.set_meta("range_expander_color", color_int)
	
	node.add_to_group("range_expander")
	node.add_to_group("range_draw")
	node.set_meta("range_expander_radius", range_radius)
	
	if Engine.is_editor_hint():
		return
	
	if not Utils.game.map.post_process:
		await Utils.game.map.ready
	
	Utils.game.map.post_process.set_deferred("range_dirty", true)

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	
	set_physics_process_internal(true)
	
	if not building_data:
		initialize_data(false)

func initialize_data(ignore_missing: bool):
	var data: Dictionary = Const.get_entry_by_scene(Const.Buildings, scene_file_path)
	if not data:
		if ignore_missing:
			return
		
		data.name = "ERROR"
		push_error(str("Missing building data for ", scene_file_path, ". Add it to Buildings.cfg."))
	building_data = data
	
	building_name = data.name
	max_hp = data.get("max_hp", 1)
	if hp == 0:
		hp = max_hp
	else:
		refresh_hp_on_start()
	max_upgrade = data.get("max_upgrades", 0)
	cost = data.get("cost", {})

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	if needs_power:
		call_deferred("set_disabled", true, true)
	
	connect("area_entered", Callable(self, "area_enter").bind(), CONNECT_DEFERRED)
	connect("area_exited", Callable(self, "area_exit").bind(), CONNECT_DEFERRED)
	add_to_group("player_buildings")
	Utils.set_collisions(self, Const.BUILDING_COLLISION_LAYER, Utils.PASSIVE)
	
	var health_bar: Node2D = get_node_or_null("HealthBar")
	if not health_bar:
		health_bar = preload("res://Nodes/Buildings/Common/HealthBar.tscn").instantiate()
		add_child(health_bar)
	connect("hp_changed", Callable(health_bar.get_child(0), "update_value"))
	
	var lava_checks := get_node_or_null("LavaChecks")
	if lava_checks:
		lava_checks.connect("lava_touching", Callable(self, "damage").bind({damage = 10, is_lava = true}))
	
	if not hack and not is_queued_for_deletion():
		build()
	
	Utils.subscribe_tech(self, "building_regeneration")
	Utils.subscribe_tech(self, "building_regeneration2")
	Utils.subscribe_tech(self, "building_regeneration3")

func add_to_tracker():
	Utils.add_to_tracker(self, Utils.game.map.common_buildings_tracker, radius, 999999)

func build():
	in_construction = false
	if SteamAPI2.achievements.last_bulldozered == name:
		SteamAPI2.unlock_achievement("HOME_MAKEOVER")
	SteamAPI2.achievements.last_bulldozered = ""
	
	if not get_tree().paused: # Nie pokazuj podczas wczytywania mapy
		Utils.log_message("Building constructed: %s" % building_data.name)
		SteamAPI2.increment_stat("BuildingsBuilt")
	
	if enemy_ignore:
		max_hp = 99999
		hp = 99999
	else:
		add_to_tracker()
	
	if sprite:
		apply_mask(Const.Materials.STOP)

func area_enter(area):
	if not is_instance_valid(area):
		return # co
	
	if area is Pickup:
		pickup_input(area)
	elif area.is_in_group("enemy_projectile"):
		var data: Dictionary = area.get_meta("data")
		data.projectile= area
		damage(data)
		if data.has("owner"):
			if data.owner.has_method("area_has_collided"):
				data.owner.area_has_collided()
	
	elif area.is_in_group("player_projectile"):
		var data: Dictionary = area.get_meta("data")
		data.projectile= area
		if (take_damage_from_player and not "good" in data) or ("bulldozer" in data and "cost" in building_data):
			if not self in data.get("exceptions", []):
				damage(data)
		else:
			var ownr: Node2D = area.get_meta("data").owner
			if ownr.has_method("hit_building"):
				ownr.hit_building(self)

func area_exit(area: Area2D):
	pass

func pickup_input(pickup: Pickup):
	pass

func resource_input(pickable_id: int, type: int):
	pass

func resource_output(type: int):
	Utils.game.map.pickables.spawn_pickable_nice(global_position, type, Vector2.RIGHT.rotated(angle) * 100)

var output_offset: Vector2

func pickup_output(pickup: Pickup, dir := Vector2.RIGHT.rotated(angle)):
	pickup.global_position = global_position + output_offset
	pickup.velocity = dir * 200

func reject_pickable(pickable_id: int):
	var vel=pickables.get_pickable_velocity(pickable_id)
	var pos=pickables.get_pickable_position(pickable_id)
	if vel.dot(global_position-pos)>0.0:
		pickables.set_pickable_velocity(pickable_id, -vel.normalized() * 100)

func set_angle(a: float):
	angle = a
	
	if not is_inside_tree():
		await self.ready
	
	update_angle()

func update_angle():
	pass

func set_preview_enabled(enabled: bool):
	pass

func get_align_offset(relative: Vector2) -> Vector2:
	return relative
#	return Vector2.RIGHT.rotated(angle) * 40

func on_placed():
	pass

func destroy(explode := true):
	Utils.log_message("Building destroyed: %s " % building_data.name)
	if explode:
		var explosion := Const.EXPLOSION.instantiate() as Node2D
		explosion.type = explosion.NEUTRAL
		explosion.scale = Vector2.ONE * 0.25
		explosion.terrain_explosion_dmg=3000
		explosion.position = global_position
		Utils.game.map.add_child(explosion)
	
	apply_mask(-1)
	queue_free()

func damage(data: Dictionary):

	var damage: int = data.damage
	if "bulldozer" in data:
		
		
		
		if Utils.game.frame_from_start - bulldozer_start>65:
			bulldozer_start= Utils.game.frame_from_start
			bulldozer_position=data.projectile.global_position
	
		if Utils.game.frame_from_start - bulldozer_start>=50 and data.projectile.global_position.distance_to(bulldozer_position)<5:
			bulldozer_start=Utils.game.frame_from_start-50
			damage = ceil(max_hp * 0.1)
		else:
			damage = ceil(max_hp * 0.01)

	if "falloff" in data:
		var damager = data.get("owner")
		if damager:
			damage = damager.get_falloff_damage()
			if damager.get_meta("Rocket", false):
				if hp-damage<=0:
					SteamAPI2.unlock_achievement("UPS_1")
	if "fortified" in data:
		damage = damage * data.fortified
		if damage==0:
			return
		
	if not enemy_ignore and not "bulldozer" in data:
		Utils.game.start_battle()
	if data.get("is_lava"):
		just_damaged_by_lava = true
	hp -= damage
	
	if "bulldozer" in data:
		update_resource_ratio(0.8)
	else:
		update_resource_ratio()
	
	
	if  not "bulldozer" in data and Time.get_ticks_msec() - Utils.game.last_base_attack_notify_time > 10000 and not enemy_ignore:
		Utils.game.last_base_attack_notify_time = Time.get_ticks_msec()
		Utils.game.ui.evil_notify("Base under attack!")
		var marker := preload("res://Nodes/Map/MapMarker/MapMarker.tscn").instantiate()
		marker.max_radius = 10000
		marker.scale = Vector2.ONE * 4
		marker.texture = preload("res://Nodes/Map/MapMarker/BuildingAttackedMarker.png")
		marker.arrow = marker.texture
		marker.rotate_arrow = false
		marker.modulate=Color(2,2,2,1)
		Utils.game.map.add_child(marker)
		marker.global_position = global_position
		marker.add_to_group("dont_save")
		
		var migacz := preload("res://Nodes/Buildings/Common/Migacz.tscn").instantiate()
		marker.add_child(migacz)

	
	
	
	
	refresh_hp("bulldozer" in data)

func repair(amount: int):
	hp = min(hp + amount, max_hp)
	update_resource_ratio()
	refresh_hp()

func refresh_hp(bulldozer := false):
	if is_destroyed:
		return
	
	emit_signal("hp_changed")
	
	if hp <= 0:
		if bulldozer:
			#SteamAPI2.achievements.last_bulldozered = name
			Utils.game.ui.notify("Building demolished")
		else:
			Utils.game.ui.evil_notify("Building destroyed")
		is_destroyed = true
		destroy()
		emit_signal("destroyed")
		SteamAPI2.try_achievement("LOSE_BUILDINGS")
		if just_damaged_by_lava:
			SteamAPI2.unlock_achievement("LOSE_LAVA")
		
		if Utils.game.sandbox_options.get("salvage_buildings", true):
			var drop_multiplier = clamp(resource_ratio, 0.5, 0.8)
			
			for id in cost:
				Pickup.launch({id = id, amount = round(cost[id] * drop_multiplier)}, global_position, Vector2.RIGHT * 150)
	else:
		if hp < max_hp and sprite:
			if not sprite.material:
				sprite.material = preload("res://Resources/Materials/BuildingDestruction.tres").duplicate()
				sprite.material.set_shader_parameter("frames", Vector2(sprite.hframes,sprite.vframes))
				if sprite.texture:
					sprite.material.set_shader_parameter("scale", sprite.global_scale*sprite.texture.get_size()*0.01)
			sprite.material.set_shader_parameter("destruction", 1 - float(hp) / max_hp)
	just_damaged_by_lava = false

func get_power_point() -> Vector2:
	return position

func apply_mask(mat: int):
	if disable_mask:
		return
	
	var mask_sprite: Sprite2D = get_node_or_null("TerrainMask")
	if not mask_sprite:
		mask_sprite = sprite
	assert(mask_sprite)
	
	var mask_position := mask_sprite.global_position#.round()
	var mask_rotation := mask_sprite.global_rotation#deg_to_rad(round(rad_to_deg(mask_sprite.global_rotation)))
	Utils.game.map.pixel_map.update_material_mask_rotated(mask_position, mask_sprite.texture.get_data(), mat, Vector3(mask_sprite.scale.x, mask_sprite.scale.y, mask_rotation), 0xFFFFFFFF, 255)

func set_disabled(disabled: bool, force := false):
	is_running = not disabled
	if disabled:
		connected_to = null
	else:
		Utils.notify_object_event(self, "power_received")
		try_to_connect()

var connected_to: BaseBuilding
var next_check: float =0.0
var lightning: Node2D

func can_connect() -> bool:
	return not disable_power

func try_to_connect():
	if not needs_power or is_instance_valid(connected_to) and connected_to.is_running or not is_inside_tree() or not can_connect():
		return
	
	var prev_connected := connected_to
	connected_to = null
	
	var closest := INF
	for building in get_tree().get_nodes_in_group("range_expander"):
		if building == self or building.connected_to == self or not building.is_running or not building.has_meta("range_expander_radius"):
			continue
		
		var rad: float = building.get_meta("range_expander_radius")
		var distance := get_power_position().distance_to(building.get_power_position())
		if distance - 1 <= rad and distance < closest:
			closest = distance
			connected_to = building
	
	if connected_to:
		connect_to_pylon(connected_to)
	else:
		disconnect_from_pylon(prev_connected)

func disconnect_from_pylon(prev_connection = connected_to):
	if is_instance_valid(prev_connection):
		prev_connection.disconnect("destroyed", Callable(self, "disconnect_from_pylon"))
		prev_connection.disconnect("lost_power", Callable(self, "disconnect_from_pylon"))
	
	if lightning:
		lightning.queue_free()
		lightning = null
	
	connected_to = null
	if is_running:
		set_disabled(true, first_check)
	first_check = false

func connect_to_pylon(to_pylon: BaseBuilding):
	if to_pylon.is_connected("destroyed", Callable(self, "disconnect_from_pylon")):
		return
	
	to_pylon.connect("destroyed", Callable(self, "disconnect_from_pylon"))
	to_pylon.connect("lost_power", Callable(self, "disconnect_from_pylon"))
	
	lightning = preload("res://Nodes/Buildings/Common/ConnectorLightning.tscn").instantiate()
	add_child(lightning)
	lightning.set_as_top_level(true)
	lightning.setup(get_power_position(), to_pylon.get_power_position())
	
	if not is_running:
		set_disabled(false, first_check)
	first_check = false

func get_power_position() -> Vector2:
	return socket.global_position if socket else global_position

func get_owning_player() -> Node2D:
	if owning_player_id > -1 and owning_player_id < Utils.game.players.size():
		return Utils.game.players[owning_player_id]
	else:
		return null

func _tech_unlocked(tech: String):
	if tech == "building_regeneration":
		regenerate = 1.0
	if tech == "building_regeneration2":
		regenerate = 2.0
	if tech == "building_regeneration3":
		regenerate = 3.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		initialize_data(true)
	
	if what == NOTIFICATION_INTERNAL_PHYSICS_PROCESS:
		if Engine.is_editor_hint():
			return
		
		next_check -= get_physics_process_delta_time()
		if next_check <= 0.0:
			try_to_connect()
			next_check = randf_range(1.1, 2.0)
		
		if regenerate>0.0 and hp < max_hp:
			regen_timer -= get_physics_process_delta_time()
			if regen_timer <= 0:
				regen_timer = 5.0/regenerate
				hp += 1
				refresh_hp()

func _should_save() -> bool:
	return not in_construction

func _get_save_data() -> Dictionary:
	return Save.get_properties(self, ["hp"])

func _set_save_data(data: Dictionary):
	hp = data.hp
	refresh_hp_on_start()

func update_resource_ratio(min_ratio := 0.0):
	resource_ratio = max(float(hp) / max_hp, min_ratio)

static func show_no_power(target: Node2D):
	Utils.game.map.add_dmg_number().custom(target, "No power!", Color.YELLOW)

static func init_structure(structure: Node2D, building: String):
	structure.set_meta("cost", Const.Buildings[building].cost)
	structure.set_meta("building_name", Const.Buildings[building].name)

func execute_action(action: String, data: Dictionary):
	if action == "destroy":
		destroy()

static func is_requirement_met(requirement: String) -> bool:
	var type: String = requirement.get_slice(":", 0)
	var data: String = requirement.get_slice(":", 1)
	
	match type:
		"technology":
			return Save.is_tech_unlocked(data)
		"building":
			for building in Utils.get_tree().get_nodes_in_group("player_buildings"):
				if building.is_running and building.building_name == data:
					return true
			return false
		"reactor_lvl":
			if not Utils.game.core:
				return false
			return Utils.game.core.level >= int(data)
		"turret":
			if not Utils.game.core:
				return true
			
			return get_turret_count() < get_max_turrets()
	
	return true

static func get_requirement_text(requirement: String) -> String:
	var type: String = requirement.get_slice(":", 0)
	var data: String = requirement.get_slice(":", 1)
	
	match type:
		"technology":
			return Utils.tr("Technology: %s") % Utils.tr(Const.Technology[data].name)
		"building":
			return Utils.tr("Constructed: %s") % Utils.tr(data)
		"reactor_lvl":
			return Utils.tr("Reactor Level: %s") % int(data)
		"turret":
			var text = Utils.tr("Turret Count: %s/%s") % [get_turret_count(), get_max_turrets()]
			if get_turret_count() >= get_max_turrets():
				text += "\n  " + Utils.tr("Turret limit reached. Upgrade the reactor.")
			
			return text
	
	return "error"

static func get_turret_count() -> int:
	var turret_count: int
#	for turret in Utils.get_tree().get_nodes_in_group("defense_tower"):
#		turret_count += int(turret.is_running or turret.in_construction)
	turret_count += Utils.get_tree().get_nodes_in_group("defense_tower").size()
	
	for blueprint in Utils.get_tree().get_nodes_in_group("blueprints"):
		if blueprint.target_building and blueprint.target_building.is_inside_tree():
			continue
		
		if blueprint.building_data.get("requirements", []).find("turret:") > -1:
			turret_count += 1
	
	return turret_count

static func get_max_turrets(for_level := -1):
	if for_level == -1:
		if Utils.game.core:
			for_level = Utils.game.core.level
		else:
			for_level = 1
	return for_level * 3 + Utils.game.extra_turrets

func is_condition_met(condition: String, data) -> bool:
	return false

func refresh_hp_on_start():
	if not is_connected("ready", Callable(self, "refresh_hp")):
		connect("ready", Callable(self, "refresh_hp").bind(), CONNECT_ONE_SHOT | CONNECT_DEFERRED)
