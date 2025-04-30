@tool
extends PixelMapRigidBody
class_name Pickup
@export var item: String # (String, "METAL_SCRAP", "LUMEN", "AMMO", "NAPALM", "SPEAR", "HAMMER", "SICKLE", "LANCE", "BAT", "KATANA", "PLASMA_GUN", "ONE_SHOT", "MAGNUM", "SHOTGUN", "MACHINE_GUN", "ROCKET_LAUNCHER", "FLAMETHROWER", "LASER", "LIGHTNING_GUN", "MINE", "GRENADE", "DYNAMITE", "DIRT_GRENADE", "SUPER_GRENADE", "FLARE", "REPAIR_KIT", "DRILL", "HOOK", "FOAM_GUN", "PICKAXE", "MEDPACK", "ARMORED_BOX", "LUMEN_CLUMP", "METAL_NUGGET", "TECHNOLOGY_ORB", "KEY", "ARTIFACT")

@export var amount: int = 1
@export var buried: bool = false

var id: int = 0 ## TODO: dać tu -1 i naprawić wszystkie mapy
var data

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	add_to_group("repair_kit_pickable")
	set_meta("object_type", "Pickup")
	
	if item.length() > 1:
		id = Const.ItemIDs.keys().find(item)
	assert(id >= 0)
	
	if get_parent().has_meta("pickup_container"):
		return
	
	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	if sprite and not sprite.texture:
		sprite.texture = get_sprite_texture()
		if not sprite.texture:
			push_error("Invalid pickup.")
		
		sprite.material = preload("res://Resources/Materials/PickableShine.tres")
		sprite.scale = get_sprite_scale()
	Utils.add_to_tracker(self, Utils.game.map.pickup_tracker, radius)
	collision_layer= Const.PICKUP_COLLISION_LAYER
	collision_mask =  Const.PICKUP_COLLISION_LAYER | Const.PLAYER_COLLISION_LAYER

func collect():
	if not visible:
		return
	hide()
	match id:
		Const.ItemIDs.MAGNUM:
			if Save.check_tech_max_level(Const.ItemIDs.MAGNUM):
				SteamAPI.unlock_achievement("UPGRADE_PISTOL_MAX")
		Const.ItemIDs.SPEAR:
			if Save.check_tech_max_level(Const.ItemIDs.SPEAR):
				SteamAPI.unlock_achievement("UPGRADE_SPEAR_MAX")
		Const.ItemIDs.MACHINE_GUN:
			if Save.check_tech_max_level(Const.ItemIDs.MACHINE_GUN):
				SteamAPI.unlock_achievement("UPGRADE_MACHINEGUN_MAX")
		Const.ItemIDs.SHOTGUN:
			if Save.check_tech_max_level(Const.ItemIDs.SHOTGUN):
				SteamAPI.unlock_achievement("UPGRADE_SHOTGUN_MAX")
		Const.ItemIDs.FLAMETHROWER:
			if Save.check_tech_max_level(Const.ItemIDs.FLAMETHROWER):
				SteamAPI.unlock_achievement("UPGRADE_FLAMER_MAX")
#			SteamAPI.unlock_achievement("GET_FLAMER")
		Const.ItemIDs.DRILL:
			if Utils.game.main_player.get_item_count(Const.ItemIDs.DRILL) > 1:
				SteamAPI.unlock_achievement("DONT_NEED_2_DRILLS")
	Utils.game.delete_pickable(self)

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if Utils.is_pixel_buried(global_position):
		state.linear_velocity=Vector2.ZERO
		buried=true
	else:
		pixel_map_physics(state,Utils.walkable_collision_mask)
		buried=false

func get_sprite_texture() -> Texture2D:
	return Utils.get_item_icon(id, data, true)

func get_sprite_scale() -> Vector2:
	return get_texture_scale(get_sprite_texture())

static func get_texture_scale(texture: Texture2D):
	return Vector2.ONE * min(10.0 / max(texture.get_width(), texture.get_height()), 1)

func throwing_disable():
	$CollisionShape2D.disabled=true
	var timer := Timer.new() as Timer
	add_child(timer)
	timer.wait_time=0.1
	timer.autostart=true
	timer.connect("timeout", Callable(self, "collision_on"))

func collision_on():
	$CollisionShape2D.disabled = false

func get_data() -> Dictionary:
	return {id = id, data = data, amount = amount}

func _get_save_data() -> Dictionary:
	return {id = id, data = data}

func _set_save_data(sdata: Dictionary):
	id = sdata.id
	data = sdata.data

static func instance(pickup_id: int) -> Pickup:
	var pickup: Pickup
	
	if pickup_id == Const.ItemIDs.ARMORED_BOX:
		pickup = load("res://Nodes/Pickups/ArmoredBox/ArmoredBoxPickup.tscn").instantiate()
	elif pickup_id == Const.ItemIDs.LUMEN_CLUMP:
		pickup = load("res://Nodes/Pickups/LumenClumpPickup.tscn").instantiate()
	elif pickup_id == Const.ItemIDs.METAL_NUGGET:
		pickup = load("res://Nodes/Pickups/MetalNuggetPickup.tscn").instantiate()
	elif pickup_id == Const.ItemIDs.TECHNOLOGY_ORB:
		pickup = load("res://Nodes/Pickups/Orb/TechnologyOrb.tscn").instantiate()
	elif pickup_id == Const.ItemIDs.KEY:
		pickup = load("res://Nodes/Pickups/Artifact/KeyPickup.tscn").instantiate()
	else:
		pickup = load("res://Nodes/Pickups/SimplePickup.tscn").instantiate()
	
	pickup.id = pickup_id
	return pickup

static func launch(pickup_data: Dictionary, from: Vector2, velocity: Vector2, random_dir: bool = true, pointed := false) -> Pickup:
	if pickup_data.id < Const.RESOURCE_COUNT:
		for i in pickup_data.amount:
			var real_velocity = velocity
			if random_dir:
				real_velocity = Utils.random_point_in_circle(1.0, 0.1) * velocity.length()
			if pointed:
				Utils.game.map.pickables.spawn_premium_pickable_nice(from, pickup_data.id, real_velocity)
			else:
				Utils.game.map.pickables.spawn_pickable_nice(from, pickup_data.id, real_velocity)
		return null
	else:
		var pickup := instance(pickup_data.id)
		pickup.data = pickup_data.get("data")
		pickup.amount = pickup_data.amount
		pickup.position = from
		pickup.linear_velocity = velocity
		Utils.game.map.call_deferred("add_child", pickup)
		return pickup
