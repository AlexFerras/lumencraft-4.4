extends PixelUtilities

const PARTICLE_DIVISOR = 1

var game: Game
var editor: Node

var use_joypad: bool
var cursor_hidden: bool
var controls_timer: Timer
var confirm_toggle: bool
var disable_log: bool
var spiral_of_life: Node
var event_listener: Object

var handler = load("res://Scripts/System/Handler.gd").new()

signal exploded_terrain
signal joypad_updated
signal coop_toggled(enable)

const walls_mask = (1 << Const.Materials.WALL | 1 << Const.Materials.WALL1 | 1 << Const.Materials.WALL2| 1 << Const.Materials.WALL3)
const walls_and_gate_mask = (walls_mask | 1 << Const.Materials.GATE)
const monster_base_attack_mask = (1<<Const.Materials.STOP | 1<<Const.Materials.LOW_BUILDING | walls_and_gate_mask | 1<<Const.Materials.FOAM | 1<<Const.Materials.FOAM2 )
const item_placer_mask = ~(monster_base_attack_mask | 1 << Const.Materials.LAVA | 1 << Const.Materials.LUMEN | 1 << Const.Materials.DEAD_LUMEN| 1 << Const.Materials.TAR| 1 << Const.Materials.ROCK| 1 << Const.Materials.CONCRETE)
const monster_attack_mask = (monster_base_attack_mask | 1<<Const.Materials.DIRT)
const default_monster_path_mask = (monster_attack_mask | 1<<Const.Materials.TAR | 1<<Const.Materials.WATER | 1<<Const.Materials.LAVA)
const monster_sight_mask = (1<<Const.Materials.STOP | 1<<Const.Materials.LOW_BUILDING | walls_and_gate_mask  ) | 1<<Const.Materials.TAR | 1<<Const.Materials.LAVA | 1<<Const.Materials.WATER
const walkable_collision_mask = ~(1<<Const.Materials.LAVA | 1<<Const.Materials.TAR | 1<<Const.Materials.WATER)
const turret_bullet_collision_mask = ~(1<<Const.Materials.TAR | walls_and_gate_mask | 1<<Const.Materials.LOW_BUILDING)
const player_bullet_collision_mask = ~(1<<Const.Materials.TAR)
const fire_resistant_mask = (1<<Const.Materials.FOAM2 | 1<<Const.Materials.WALL2| 1<<Const.Materials.WALL3 | 1<<Const.Materials.LAVA)
#const walkable_mask= ~(1<<Const.Materials.LAVA | 1<<Const.Materials.TAR | 1<<Const.Materials.WATER)
#const turret_bullet_mask=  ~(1<<Const.Materials.TAR | walls_mask | 1 << Const.Materials.GATE)
#const player_bullet_mask=  ~(1<<Const.Materials.TAR)

var monster_path_mask = default_monster_path_mask

var nx

func _init():
	randomize()
	
	process_mode = Node.PROCESS_MODE_ALWAYS
#	if not OS.has_feature("editor"):
#		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	use_joypad = bool(Input.get_connected_joypads().size())
	set_hide_cursor(use_joypad)
	
	if ResourceLoader.exists("res://load_mods.gd"):
		var mod = load("res://load_mods.gd").new()
		mod.initialize()
	
	DirAccess.new().make_dir_recursive("user://Maps")
	
	spiral_of_life = preload("res://Nodes/Objects/Helper/SpiralOfLife.gd").new()
	add_child(spiral_of_life)
	add_child(handler)
#	get_tree().connect("node_added", self, "debug_inspect")

func debug_inspect(node):
	if node is AudioStreamPlayer2D:
		print(node.get_parent().name)
	
	if node is AudioStreamPlayer2D and node.get_parent().name.begins_with("EnemyPider"):
		print("inspect...")

func debug_map(map: String):
	Save.new_game()
	await get_tree().idle_frame
	Game.start_map("res://Maps/" + map + ".tscn")
	get_tree().current_scene.queue_free()
	if get_meta("override").has_method("on_map_loaded"):
		await get_tree().idle_frame
		Utils.game.connect("map_changed", Callable(get_meta("override"), "on_map_loaded"))

func print_node(node):
	if node is Node:
		if node.get_script():
			print(node.name)
			node.connect("ready", Callable(self, "print_node").bind({name = "ready " + node.name}))
	else:
		print(node.name)

func _ready():
#	get_tree().connect("node_added", self, "print_node")
	var sav = preload("res://Scripts/Data/SaveFile.gd").new()
	sav.fetch_properties()
	setup_store_node(sav)
	
	#debug
	if Const.get_override("DISABLE_LOG"):
		disable_log = true
	
	log_message("Running version: " + preload("res://Tools/version.gd").VERSION, false)
	Save.connect("tech_unlocked", Callable(self, "check_subscribers"))
	
	if OS.has_feature("early_access") or Music.is_demo_build():
		get_tree().root.call_deferred("add_child", load("res://Nodes/UI/PlaytestWatermark.tscn").instantiate())
	
	controls_timer = Timer.new()
	controls_timer.wait_time = 0.25
	controls_timer.one_shot = true
	controls_timer.connect("timeout", Callable(self, "toggle_joypad"))
	add_child(controls_timer)
	
	var audio: AudioManager
	
	audio = create_audio_manager("rock_audio")
	audio.set_sample("res://SFX/Explosion/Destroying Stone")
	audio.max_samples = 5
	audio.min_delay = 0.3
	audio.volume = -8.0
	
	audio = create_audio_manager("crystal_audio")
	audio.set_sample("res://SFX/Crystal/GLASS_Fragment_")
	audio.max_samples = 5
	audio.min_delay = 0.1
	
	audio = create_audio_manager("ivy_audio")
	audio.set_sample("res://SFX/Environmnent/IvyDestroy")
	audio.max_samples = 5
	audio.min_delay = 0.1
	
	audio = create_audio_manager("wood_audio")
	audio.set_sample("res://SFX/Objects/impactwood")
	audio.max_samples = 5
	audio.min_delay = 0.1
	
	audio = create_audio_manager("burn_audio")
	audio.set_sample("res://SFX/Lava/sizzling")
	audio.max_samples = 10
	audio.min_delay = 2.3
	audio.skip_outside_screen = true
	
	
	audio = create_audio_manager("fire_audio")
	audio.set_sample("res://SFX/Lava/fire_burn")
	audio.max_samples = 8
	audio.min_delay = 0.2
	audio.skip_outside_screen = true
	
	audio = create_audio_manager("flesh_hit")
	audio.set_sample("res://SFX/Weapons/BodyFlesh/StaffHitting")
	audio.max_samples = 10
	audio.min_delay = 0.1
	audio.skip_outside_screen = true
	
	
	audio = create_audio_manager("swarm_dead")
	audio.set_sample("res://SFX/Enemies/Small monster Death")
	audio.volume = -8.0
	audio.max_samples = 5
	audio.min_delay = 0.2
	
	audio = create_audio_manager("swarm_attack")
	audio.set_sample("res://SFX/Enemies/Medium monster attack")
	audio.volume = -8.0
	audio.max_samples = 15
	audio.min_delay = 0.03
	audio.random_pitch = 1.1
	audio.skip_outside_screen = true
	
	audio = create_audio_manager("swarm_walk")
	audio.set_sample("res://SFX/Enemies/spider_short_walk/walk")
	audio.max_samples = 5
	audio.volume = -5.0
	audio.min_delay = 0.2
	audio.random_pitch = 1.1
	audio.skip_outside_screen = true
	audio.max_distance = 200.0
	
	audio = create_audio_manager("flying_walk")
	audio.set_sample("res://SFX/Enemies/wings/Chicken flapping wings")
	audio.max_samples = 10
	audio.volume = -5.0
	audio.min_delay = 0.1
	audio.random_pitch = 1.3
	audio.skip_outside_screen = true
	audio.max_distance = 200.0
	
	audio = create_audio_manager("flying_attack")
	audio.set_sample("res://SFX/Enemies/wings_attack/wings_attack")
	audio.max_samples = 8
	audio.volume = 0.0
	audio.min_delay = 0.1
	audio.pitch_scale = 0.9
	audio.random_pitch = 1.1
	audio.skip_outside_screen = true
	audio.max_distance = 200.0
	
	
	audio = create_audio_manager("flying_dead")
	audio.set_sample("res://SFX/Enemies/wings_dead/wings_dead")
	audio.max_samples = 4
	audio.volume = 0.0
	audio.min_delay = 0.1
	audio.random_pitch = 1.1
	audio.skip_outside_screen = true
	audio.max_distance = 200.0
	
	audio = create_audio_manager("dragonfly_walk")
	audio.set_sample("res://SFX/Enemies/wings/dragonfly_walk")
	audio.max_samples = 10
	audio.volume = -5.0
	audio.min_delay = 0.1
	audio.random_pitch = 1.3
	audio.skip_outside_screen = true
	audio.max_distance = 200.0
	
	audio = create_audio_manager("worm_dead")
	audio.set_sample("res://SFX/Enemies/worm_dead/worm_dead")
	audio.max_samples = 15
	audio.volume = 10.0
	audio.min_delay = 0.02
	audio.random_pitch = 1.2
	
	audio = create_audio_manager("worm_attack")
	audio.set_sample("res://SFX/Enemies/worm_attack/worm_attack")
	audio.max_samples = 5
	audio.volume = -5.0
	audio.min_delay = 0.1
	audio.random_pitch = 1.2
	audio.skip_outside_screen = true
	
	audio = create_audio_manager("worm_walk")
	audio.set_sample("res://SFX/Enemies/worm_short_walk/worm_walk")
	audio.max_samples = 5
	audio.volume = -5.0
	audio.min_delay = 0.2
	audio.random_pitch = 1.2
	audio.skip_outside_screen = true
	
	audio = create_audio_manager("turtle_dead")
	audio.set_sample("res://SFX/Enemies/Turtle/monster3")
	audio.max_samples = 5
	audio.volume = -10.0
	audio.min_delay = 0.1
	audio.pitch_scale = 1.6
	audio.random_pitch = 1.2
	audio.skip_outside_screen = true
	
	audio = create_audio_manager("turtle_attack")
	audio.set_sample("res://SFX/Enemies/Turtle/monster1")
	audio.max_samples = 5
	audio.volume = -10.0
	audio.min_delay = 0.1
	audio.pitch_scale = 1.6
	audio.random_pitch = 1.2
	audio.skip_outside_screen = true
	
	audio = create_audio_manager("turtle_walk")
	audio.set_sample("res://SFX/Enemies/slow_swarm/step")
	audio.max_samples = 15
	audio.volume = -5.0
	audio.min_delay = 0.2
	audio.random_pitch = 1.2
	audio.skip_outside_screen = true
	audio.rnd_offset = true
	
	audio = create_audio_manager("rock_smash")
	audio.set_sample("res://SFX/Environmnent/rock_smashable_falling_debris_")
	audio.max_samples = 3
	audio.min_delay = 1.0
	audio.random_pitch = 1.1
	audio.skip_outside_screen = true
	
	audio = create_audio_manager("slime")
	audio.set_sample("res://SFX/Misc/slime")
	audio.max_samples = 6
	audio.min_delay = 0.1
	audio.volume = -3.0
	audio.pitch_scale = 0.9
	audio.random_pitch = 1.7

	
	audio = create_audio_manager("gore_hit")
	audio.set_sample("res://SFX/Bullets/bullet_impact_body_flesh")
	audio.max_samples = 6
	audio.min_delay = 0.1
	audio.random_pitch = 1.7
	audio.skip_outside_screen = true	
	
	audio = create_audio_manager("bullet_hit_dirt")
	audio.set_sample("res://SFX/Bullets/bullet_impact_dirt")
	audio.max_samples = 6
	audio.min_delay = 0.1
	audio.random_pitch = 1.3
	audio.skip_outside_screen = true
	
	audio=create_audio_manager("gore_audio")
	audio.set_sample("res://SFX/Misc/mushroom/gore")
	audio.max_samples = 6
	audio.min_delay = 0.1
	
	
#	add_child(preload("res://Tools/PreAlpha.tscn").instance())
	DirAccess.new().make_dir("user://Maps")

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN:
			AudioServer.set_bus_mute(0, false)
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			AudioServer.set_bus_mute(0, Save.config.mute_when_unfocused)
		NOTIFICATION_PREDELETE:
			if editor:
				editor.free()

func get_item_name(item: Dictionary) -> String:
	if item.id == -1:
		return "Empty"
	
	if item.id < Const.RESOURCE_COUNT:
		return Const.ResourceNames[item.id]
	
	if "default_name" in Const.Items[item.id]:
		return Const.Items[item.id].default_name
	
	match item.id:
		Const.ItemIDs.AMMO:
			match item.data:
				Const.Ammo.BULLETS:
					return "Bullets"
				Const.Ammo.LASERS:
					return "Lasers"
				Const.Ammo.ROCKETS:
					return "Rockets"
				_:
					return "Unknown Ammo"
		Const.ItemIDs.PLASMA_GUN:
			var upgrades := PackedStringArray()
			if "wave" in item.data:
				upgrades.append("Wave")
			if "size" in item.data:
				upgrades.append(str("Size +", item.data.size))
			if "dig" in item.data:
				upgrades.append(str("Dig +", item.data.dig / 10))
			if "bounce" in item.data:
				upgrades.append(str("Bounce +", item.data.bounce))
			if "explosion" in item.data:
				upgrades.append(str("Explosion +", item.data.explosion))
			if "multi" in item.data:
				upgrades.append(str("Multishot +", item.data.multi))
			
			if upgrades.is_empty():
				return "Plasma Gun"
			else:
				return "Plasma Gun (" + ", ".join(upgrades) + ")"
		Const.ItemIDs.PICKAXE:
			return item.data.capitalize()
		Const.ItemIDs.DIRT_GRENADE:
			return str("Reverse Grenade (", Const.ResourceNames[item.data], ")")
		Const.ItemIDs.TECHNOLOGY_ORB:
			if not "cached_tech" in item:
				var technology: String
				if "technology" in item.data:
					technology = tr(Const.Technology[item.data.technology].name)
				elif "weapon_upgrade" in item.data:
					technology = "%s: %s +%s" % [tr(get_item_name({id = Const.ItemIDs.keys().find(item.data.weapon_upgrade.get_slice("/", 0))})), tr(Const.UPGRADES[item.data.weapon_upgrade.get_slice("/", 1)].get_slice("|", 0)), item.data.upgrade_level]
				elif "player_upgrade" in item.data:
#					var stat = Const.game_data.get_stat_rename(item.data.player_upgrade)
#					technology = "%s +%s" % [tr(stat.capitalize()), item.data.level]
					technology = "%s +%s" % [tr(item.data.player_upgrade.capitalize()), item.data.level]
				item.cached_tech = technology
			
			return tr("Technology Orb (%s)") % item.cached_tech
		Const.ItemIDs.KEY:
			return tr("Key (%s)") % tr(Const.KEY_COLORS[item.data])
		Const.ItemIDs.ARTIFACT:
			return Const.ARTIFACT_NAMES[item.data]
		_:
			return "Unknown Item"

func get_item_icon(id: int, data = null, ground := false) -> Texture2D:
	if id == -1:
		return null
	
	if id < Const.RESOURCE_COUNT:
		return Const.resource_icons_textures[id]
	
	var item_data: Dictionary = Const.Items[id]
	if "icon" in item_data:
		if ground:
			return load(item_data.ground_icon) as Texture2D
		else:
			return load(item_data.icon) as Texture2D
	
	match id:
		Const.ItemIDs.AMMO:
			match data:
				Const.Ammo.BULLETS:
					if ground:
						return preload("res://Resources/Textures/inventory_item_96x96-assets_no_border/ammo_box_Icon_.png") as Texture2D
					else:
						return preload("res://Resources/Textures/inventory_item_96x96-assets/ammo_box_Icon_.png") as Texture2D
				Const.Ammo.LASERS:
					return load("res://Nodes/Pickups/Ammo/Lasers.png") as Texture2D
				Const.Ammo.ROCKETS:
					if ground:
						return preload("res://Resources/Textures/inventory_item_96x96-assets_no_border/rocket_ammo_n.png") as Texture2D
					else:
						return preload("res://Resources/Textures/inventory_item_96x96-assets/rocket_ammo_n.png") as Texture2D
		Const.ItemIDs.DRILL:
			if Save.data:
				if ground:
					return load("res://Resources/Textures/inventory_item_96x96-assets_no_border/drill_%s_icon.png" % (Save.get_unclocked_tech(str(Const.ItemIDs.DRILL, "drilling_power")) / 2 + 1)) as Texture2D
				else:
					return load("res://Resources/Textures/inventory_item_96x96-assets/drill_%s_icon.png" % (Save.get_unclocked_tech(str(Const.ItemIDs.DRILL, "drilling_power")) / 2 + 1)) as Texture2D
			else:
				if ground:
					return preload("res://Resources/Textures/inventory_item_96x96-assets_no_border/drill_1_icon.png") as Texture2D
				else:
					return preload("res://Resources/Textures/inventory_item_96x96-assets/drill_1_icon.png") as Texture2D
		Const.ItemIDs.PICKAXE:
			return load("res://Nodes/Player/Weapons/Tools/Pickaxe/PickaxeData/" + data + ".tres").texture
		Const.ItemIDs.KEY:
			if ground:
				return load("res://Resources/Textures/inventory_item_96x96-assets_no_border/Key%s.png" % data) as Texture2D
			else:
				return load("res://Resources/Textures/inventory_item_96x96-assets/Key%s.png" % data) as Texture2D
		Const.ItemIDs.ARTIFACT:
			return create_sub_texture(load("res://Nodes/Pickups/Artifact/Artifact.png"), Rect2(data, 0, -3, -1))
	
	return null

func get_item_held_icon(id: int, data = null) -> Texture2D:
	if id < Const.RESOURCE_COUNT:
		return Const.resource_pickup_textures[id]
	return get_item_icon(id, data, true)

func get_physics_world2d() -> PhysicsDirectSpaceState2D:
	return game.get_world_2d().direct_space_state

func set_hide_cursor(hide: bool):
	if hide == cursor_hidden:
		return
	cursor_hidden = hide
	
	Input.set_custom_mouse_cursor(preload("res://Resources/Textures/CursorHack.png") if cursor_hidden else null)


#print(Utils.get_all_nodes_count(Utils.game.map))
func get_all_nodes_count(n, i=0):
	var my_childs=0
	var other_childs=0
	for x in n.get_children():
		my_childs+=1
		other_childs+=get_all_nodes_count(x)
	return my_childs+other_childs
	


func get_item_cursor(item: int) -> Texture2D:
#	if item >= Const.RESOURCE_COUNT:
#		var data: Dictionary = Const.Items[item]
#		if "cursor" in data:
#			return load(data.cursor) as Texture
	
	return preload("res://Nodes/Player/Cursors/Default.png") as Texture2D

func get_pixel_material(pixel: Color) -> int:
	return int(pixel.g * 255)

func get_node_by_type(parent: Node, type) -> Node:
	for node in parent.get_children():
		if node is type:
			return node
		else:
			var ret := get_node_by_type(node, type)
			if ret:
				return ret
	
	return null

func get_node_by_scene(parent: Node, scene: String) -> Node:
	for node in parent.get_children():
		if node.filename  == scene:
			return node
		else:
			var ret := get_node_by_scene(node, scene)
			if ret:
				return ret
	
	return null

func get_environment() -> Environment:
	return preload("res://Resources/Misc/MapEnvironment.tres")
	
var exploded_list: Array
var spawn_amount_mul:float =1.0
var explosion_accum: = {}

var MIN_PARTICLE_EXPLOSION_RADIUS=18

func explode(position: Vector2, radius: float, dmg: int, penetration: float ,threshold: float, mask = player_bullet_collision_mask, no_repel := false, pickable_spawn_mul=1.0,seismic=false):
	call_deferred("true_explode", "update_damage_circle_penetrating_explosive", position, radius, dmg, penetration, threshold, mask, no_repel, pickable_spawn_mul,seismic)

func explode_circle(position: Vector2, radius: float, dmg: int, hardness: float, threshold := 255,  mask=player_bullet_collision_mask, no_repel := false, pickable_spawn_mul=1.0,seismic=false):
	call_deferred("true_explode", "update_damage_circle", position, radius, dmg, hardness, threshold,  mask, no_repel, pickable_spawn_mul,seismic)

func explode_circle_no_debris(position: Vector2, radius: float, dmg: int, hardness: float, threshold := 255, mask=player_bullet_collision_mask, no_repel := false, pickable_spawn_mul=1.0,seismic=false):
	call_deferred("true_explode", "update_damage_circle_nd", position, radius, dmg, hardness, threshold, mask, no_repel, pickable_spawn_mul,seismic)

func explode_mask(position: Vector2, mask: Image, mul: float):
	call_deferred("true_explode", "update_damage_mask", position, mul, 0, 0, null, mask)

func true_explode(method: String, position: Vector2, radius: float, dmg: int, hardness: float, threshold = null, mask = null, no_repel = null, pickable_spawn_mul=1.0, seismic=false) -> bool:
	if not is_instance_valid(game) or not is_instance_valid(game.map) or not is_instance_valid(game.map.pixel_map):
		return false
	
	var no_debris: bool
	if method.ends_with("nd"):
		no_debris = true
		method = method.trim_suffix("_nd")
	
	var pixel_map: PixelMap = game.map.pixel_map

	if seismic or (game.map.events and "is_fear" in game.map.events):
		game.ui.minimap.seismic.add_indicator(position, radius)
		game.ui.full_map.minimap.seismic.add_indicator(position, radius)

	spawn_amount_mul= 10000000 if is_zero_approx(pickable_spawn_mul) else 1.0/pickable_spawn_mul
	
	pixel_map.set_destruction_callback(PARTICLE_DIVISOR, self, "add_exploded_pixel")
	if dmg == 0 and method == "update_damage_mask":
		pixel_map.update_damage_mask(position, mask, radius)
	elif mask != null:
		pixel_map.call(method, position, radius, dmg, hardness, threshold, mask)
	elif threshold != null:
		pixel_map.call(method, position, radius, dmg, hardness, threshold)
	else:
		pixel_map.call(method, position, radius, dmg, hardness)
	
	spawn_amount_mul = 1.0
	var manager = game.map.pixel_map.particle_manager
	if exploded_list.is_empty():
		game.map.restore_pickable_callback()
		if radius > MIN_PARTICLE_EXPLOSION_RADIUS and not no_repel:
			manager.explosion_happened(position, radius, 400)
			#Do refaktoryzacji - grupa pewnie 
			game.map.pixel_map.flesh_manager.explosion_happened(position, radius, 400)
		return false
	
	emit_signal("exploded_terrain")
	
	var points := PackedVector2Array()
	points.resize(exploded_list.size())
	for i in exploded_list.size():
		points[i] = Vector2(exploded_list[i].x, exploded_list[i].y)
	
	var colors := PackedColorArray()
	colors.resize(exploded_list.size())
	var destroyed_mats: Dictionary
	var max_mat: int
	var max_count: int
	
	for i in exploded_list.size():
		var mat: int = exploded_list[i].z
		colors[i] = get_material_color(mat)
		
		var mat_count: int = destroyed_mats.get(mat, 0)
		destroyed_mats[mat] = mat_count + 1
		if mat_count + 1 > max_count:
			max_count = mat_count + 1
			max_mat = mat
	
	if not no_debris:
		manager.spawn_particles(points, colors)
		
		get_audio_manager(get_material_break_sound(max_mat)).play(position)

	if radius > MIN_PARTICLE_EXPLOSION_RADIUS and not no_repel:
		manager.explosion_happened(position, radius, 400)
		game.map.pixel_map.flesh_manager.explosion_happened(position, radius, 400)
	
	exploded_list.clear()
	game.map.restore_pickable_callback()
	return true

func is_pixel_buried(pos):
	return (1<<game.map.pixel_map.get_pixel_at(pos).g8) & (Utils.walkable_collision_mask  & (~( 1<<Const.Materials.EMPTY |1<<Const.Materials.STOP )))

func add_exploded_pixel(pos: Vector2, mat: int, value: int):
	exploded_list.append(Vector3(pos.x, pos.y, mat))

	var spawn_rate: int = Const.ResourceSpawnRate.get(mat, 100) / game.map.ResourceSpawnRateModifier.get(mat, 1)
#	var spawn_rate: int = Const.ResourceSpawnRate.get(mat, 100) / game.map.ResourceSpawnRateModifier.get(mat, 1)
	if not explosion_accum.has(mat):
		explosion_accum[mat] = 0
	
	explosion_accum[mat] += value
	spawn_rate*=spawn_amount_mul
	while explosion_accum[mat] >= spawn_rate:
		game.map.pixels_destroyed(pos, mat, spawn_rate)
		explosion_accum[mat] -= spawn_rate
	if mat == Const.Materials.LUMEN:
		if game.map.remainig_lumen <= Utils.explosion_accum[mat]:
			SteamAPI.unlock_achievement("OCD") 

func temp_instance(scene: PackedScene) -> Node:
	var node := scene.instantiate()
	node.queue_free()
	return node

var mask_cache: Dictionary

func create_mask_from_sprite(from: Sprite2D) -> Image:
	var rect_list: Array
	var sprite_list: Array
	fetch_sprites(from, sprite_list)
	
	for sprite in sprite_list:
		rect_list.append(sprite.global_transform * (sprite.get_rect()))
	
	var minv := Vector2(INF, INF)
	var maxv := Vector2(-INF, -INF)
	
	for rect in rect_list:
		minv.x = min(minv.x, rect.position.x)
		minv.y = min(minv.y, rect.position.y)
		maxv.x = max(maxv.x, rect.end.x)
		maxv.y = max(maxv.y, rect.end.y)
	
	var final_rect := Rect2(Vector2(), maxv - minv)
	var image := Image.new()
	image.create(final_rect.size.x, final_rect.size.y, false, Image.FORMAT_RGBA8)
	
	for sprite in sprite_list:
		var image2 := create_mask_from_solid_pixels(sprite.texture.get_data())
		var dst_rect: Rect2 = sprite.global_transform * (sprite.get_rect())
		image2.resize(dst_rect.size.x, dst_rect.size.y, 0)
		image.blend_rect(image2, Rect2(Vector2(), image2.get_size()), dst_rect.position - minv)
	
	return image

func fetch_sprites(from: Sprite2D, to: Array):
	to.append(from)
	for sprite in from.get_children():
		if sprite is Sprite2D:
			fetch_sprites(sprite, to)

func create_mask_from_texture(from: Image) -> Image:
	if not from in mask_cache:
		var data: PackedByteArray = from.get_data()
		for x in from.get_width():
			for y in from.get_height():
				data[x * 4 + y * from.get_width() * 4] = 255
		
		var image := Image.new()
		image.create_from_data(from.get_width(), from.get_height(), false, Image.FORMAT_RGBA8, data)
		mask_cache[from] = image
	
	return mask_cache[from]

func create_mask_from_solid_pixels(from: Image) -> Image:
	if not from in mask_cache:
		var w: int = from.get_width()
		var data := PackedByteArray()
		data.resize(from.get_width() * from.get_height() * 4)
		var original := from.get_data()
		
		for x in from.get_width():
			for y in from.get_height():
				var idx: int = x * 4 + y * w * 4
				if original[idx + 3] > 128:
					data[idx] = 255
					data[idx + 1] = Const.Materials.STOP
					data[idx + 2] = 0
					data[idx + 3] = 255
				else:
					data[idx] = 0
					data[idx + 1] = 0
					data[idx + 2] = 0
					data[idx + 3] = 0
		
		var image := Image.new()
		image.create_from_data(from.get_width(), from.get_height(), false, Image.FORMAT_RGBA8, data)
		mask_cache[from] = image
	
	return mask_cache[from]

var atlas_cache: Dictionary

func create_sub_texture(texture: Texture2D, rect: Rect2) -> AtlasTexture:
	if rect.size.x < 0:
		rect.size = texture.get_size() / -rect.size
		rect.position *= rect.size
	
	var key := [texture, rect]
	if not key in atlas_cache:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = rect
		atlas_cache[key] = atlas
	
	return atlas_cache[key] as AtlasTexture

func create_atlas_frame(texture: Texture2D, frames: Vector2, frame: int) -> AtlasTexture:
	var frame_size := texture.get_size() / frames
	var frame_coord := frame / int(frames.y) * int(frames.x) + frame % int(frames.y)
	return create_sub_texture(texture, Rect2(frame_coord * frame_size, frame_size))

func create_resized_texture(texture: Texture2D, target_size: Vector2) -> Texture2D:
	var key := [texture, target_size]
	if not key in atlas_cache:
		var image := texture.get_data()
		image.resize(target_size.x, target_size.y, Image.INTERPOLATE_CUBIC)
		var resized := ImageTexture.new()
		resized.create_from_image(image)
		atlas_cache[key] = resized
	return atlas_cache[key]

func change_scene_with_loading(to_scene: String):
	var loading := preload("res://Scenes/Loading.tscn").instantiate() as Node
	get_tree().current_scene.queue_free()
	get_tree().root.add_child(loading)
	get_tree().current_scene = loading
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file(to_scene)

func log_message(text: String, include_timestamp := true):
	if disable_log:
		return
	
	if include_timestamp:
		print("[%02d:%02d:%02d] %s" % [Save.game_time / 3600 % 60, Save.game_time / 60 % 60, Save.game_time % 60, text])
	else:
		print("> ", text)

func get_stack_size(id: int, data) -> int:
	if id < Const.RESOURCE_COUNT:
		if id == Const.ItemIDs.LUMEN and Save.is_tech_unlocked("lumen_stacking"):
			return 150
		elif id == Const.ItemIDs.METAL_SCRAP and Save.is_tech_unlocked("mineral_stacking"):
			return 150
		else:
			return 100
	
	if id == Const.ItemIDs.AMMO:
		var maxa: int
		match data:
			Const.Ammo.BULLETS:
				maxa = 300
			Const.Ammo.ROCKETS:
				maxa = 50
			Const.Ammo.LASERS:
				maxa = 30
		
		if Save.is_tech_unlocked("ammo_stacking"):
			maxa = int(maxa * 1.5)
		if Save.is_tech_unlocked("ammo_stacking2"):
			maxa = int(maxa * 1.5)
		if Save.is_tech_unlocked("ammo_stacking3"):
			maxa = int(maxa * 1.5)
		return maxa
	
	return Const.Items[id].stack_size

func get_item_cost(data: Dictionary) -> Array:
	var cost: Array

	if data.id < Const.RESOURCE_COUNT:
		cost.append(data)
	elif data.id == Const.ItemIDs.ARMORED_BOX:
		for item in data.data:
			item.durability = 10
		cost.append_array(data.data)
	elif data.id == Const.ItemIDs.LUMEN_CLUMP:
		var efficiency := int(Save.is_tech_unlocked("extract_efficiency"))
		var total: int
		for i in data.amount:
			total += int(randf_range(10 + efficiency * 10, 40 + efficiency * 20))
		cost.append({id = Const.ItemIDs.LUMEN, amount = total, pointed = true})
	elif data.id == Const.ItemIDs.METAL_NUGGET:
		var efficiency := int(Save.is_tech_unlocked("extract_efficiency"))
		var total: int
		for i in data.amount:
			total += int(randf_range(10 + efficiency * 10, 40 + efficiency * 20))
		cost.append({id = Const.ItemIDs.METAL_SCRAP, amount = total, pointed = true})
	elif data.id == Const.ItemIDs.TECHNOLOGY_ORB:
		if "technology" in data.data:
			return [{id = Const.ItemIDs.LUMEN, amount = Const.Technology[data.data.technology].cost}]
		elif "weapon_upgrade" in data.data:
			var id := Const.ItemIDs.keys().find(data.data.weapon_upgrade.get_slice("/", 0))
			var upgrade: String = data.data.weapon_upgrade.get_slice("/", 1)
			var upgrade_data: Dictionary = Utils.get_weapon_upgrade_data(id, upgrade)
			return upgrade_data.costs[0]
		else:
			return [{id = Const.ItemIDs.LUMEN, amount = 100}]
	else:
		var item_data: Dictionary = Const.Items[data.id]
		var item_cost = item_data.get("cost", 10)
		
		if data.id == Const.ItemIDs.AMMO:
			match data.data:
				Const.Ammo.BULLETS:
					item_cost = 0.0625
				Const.Ammo.ROCKETS:
					item_cost = 5
		
		if item_cost is int or item_cost is float:
			item_cost = [{id = Const.ItemIDs.METAL_SCRAP, amount = item_cost}]
		elif item_cost is Array:
			item_cost = item_cost.duplicate(true)
		
		for item in item_cost:
			item.amount = item.amount * data.amount
		cost = item_cost
	
	return cost

func _input(event: InputEvent) -> void:
	if Save.config.single_player_controls != Config.CONTROL_JOYPAD and Save.config.single_player_controls != Config.CONTROL_ALL and (event is InputEventMouse or event is InputEventKey):
		if use_joypad:
			if controls_timer.is_stopped():
				controls_timer.start()
			else:
				confirm_toggle = true
		else:
			controls_timer.stop()
			confirm_toggle = false
	
	if Save.config.single_player_controls != Config.CONTROL_KEYBOARD and Save.config.single_player_controls != Config.CONTROL_ALL and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		if event is InputEventJoypadMotion and event.axis_value == 0:
			return
		
		if use_joypad:
			controls_timer.stop()
			confirm_toggle = false
		else:
			if controls_timer.is_stopped():
				controls_timer.start()
			else:
				confirm_toggle = true
	
	if Utils.editor:
		set_hide_cursor(false)
	elif is_instance_valid(game):
		set_hide_cursor(not get_tree().paused)
	else:
		set_hide_cursor(use_joypad)
	
	if event is InputEventKey:
		if event.keycode == KEY_ENTER and event.pressed and event.alt:
			if not (is_instance_valid(game) and is_instance_valid(game.map) and not game.map.started):
				if Save.config.screenmode > Save.config.WINDOWED:
					Save.config.screenmode = Save.config.WINDOWED
					OS.center_window()
				else:
					Save.config.screenmode = Save.config.BORDERLESS_FULLSCREEN
				Save.config.request_refresh_display()
				Save.config.apply()
				get_viewport().set_input_as_handled()
	
	##debug
	if OS.has_feature("editor"):
		if event is InputEventKey and event.keycode == KEY_HOME and event.pressed:
			get_window().always_on_top = (not get_window().always_on_top

func vibrate(weak_magnitude: float, strong_magnitude: float, duration: float, player: Player = null):
	if player:
		if player.using_joypad():
			var device_id := 0
			if player.control_id > 3:
				device_id = player.control_id - 3
			Input.start_joy_vibration(device_id, weak_magnitude * Save.config.joypad_vibrations, strong_magnitude * Save.config.joypad_vibrations, duration)
	else:
		for p in Utils.game.players:
			vibrate(weak_magnitude, strong_magnitude, duration, p)

func trim_string(string: String, max_len: int) -> String:
	if string.length() > max_len:
		return string.substr(0, max_len - 3) + "..."
	else:
		return string

func get_weapon_upgrade_data(weapon: int, upgrade := ""):
	if upgrade.is_empty():
		return Const.Items[weapon].upgrades
	else:
		var upgrades: Array = Const.Items[weapon].upgrades
		for u in upgrades:
			if u.name == upgrade:
				return u

func toggle_joypad():
	if not confirm_toggle:
		return
	
	confirm_toggle = false
	use_joypad = not use_joypad
	emit_signal("joypad_updated")

func play_sample(sample, source = null, follow := false, random_pitch := 1.0, pitch_scale:=1.0, rnd_offset:=false) -> Node:
	var kill_source: bool
	if source is Vector2:
		var node := Node2D.new()
		add_child(node)
		node.global_position = source
		source = node
		kill_source = true
	
	if not is_instance_valid(source): ##coś tu może być popsute
		source = null
	
	if sample is String:
		sample = load(sample)
	elif sample is Array:
		for s in sample:
			await play_sample(s, source, follow, random_pitch).finished
		return
	
	assert(sample is AudioStream)
	
	if not is_equal_approx(random_pitch, 1.0):
		var stream := AudioStreamRandomizer.new()
		stream.audio_stream = sample
		stream.random_pitch = random_pitch
		sample = stream
	
	var player
	if source is AudioStreamPlayer2D:
		if OS.has_feature("debug"):
			if not source.has_meta("ignore_warning") and (source.max_distance != 500 or source.attenuation != 2) or source.bus != "SFX":
				push_warning("Niepoprawny audio player")
		
		player = source
		player.stream = sample
		player.play()
	elif source is AudioStreamPlayer:
		player = source
		player.stream = sample
		player.play()
	elif source and is_instance_valid(game):
		player = preload("res://Nodes/Effects/Audio/PointSample.gd").new(sample, source, follow)
		if rnd_offset:
			player.seek(player.stream.get_length() * randf_range(0.0, 0.6))
		game.add_child(player)
	else:
		player = preload("res://Nodes/Effects/Audio/GlobalSample.gd").new(sample)
		add_child(player)
	assert(player is AudioStreamPlayer or player is AudioStreamPlayer2D)
	player.pitch_scale=pitch_scale
	if kill_source:
		player.connect("tree_exited", Callable(source, "queue_free"))
	
	return player

func get_sound(collection: int) -> AudioStream:
	var sounds: Array = Const.SOUND_COLLECTIONS[collection]
	return sounds[randi() % sounds.size()] as AudioStream

func get_material_break_sound(material: int):
	var custom_material := get_custom_material(material)
	if custom_material and not custom_material.break_sound.is_empty():
		return custom_material.break_sound
	
	if material == Const.Materials.LUMEN:
		return "crystal_audio"
	else:
		return "rock_audio"

func get_material_hit_sound(at: Vector2):
	var material: int = get_pixel_material(game.map.pixel_map.get_pixel_at(at))
	
	var custom_material := get_custom_material(material)
	if custom_material and not custom_material.hit_sound.is_empty():
		return random_sound("res://SFX/" + custom_material.hit_sound)
	
	match material:
		Const.Materials.DIRT:
			return random_sound("res://SFX/Bullets/bullet_impact_dirt")
		Const.Materials.STEEL, Const.Materials.WEAK_SCRAP, Const.Materials.STRONG_SCRAP, Const.Materials.ULTRA_SCRAP:
			return random_sound("res://SFX/Bullets/bullet_impact_metal_light")
		Const.Materials.ROCK:
			return random_sound("res://SFX/Bullets/pick_axe_stone_small_hit_mine_impact")
		Const.Materials.STOP:
			return random_sound("res://SFX/Bullets/bullet_impact_metal_light")
		Const.Materials.LUMEN:
			return random_sound("res://SFX/Crystal/Glass item Breaks")
		_:
			return random_sound("res://SFX/Bullets/bullet_impact_concrete_brick")

func get_material_color(mat: int) -> Color:
	var custom_material := get_custom_material(mat)
	
	if custom_material:
		return custom_material.debris_color * Const.halfColor
	elif Const.MaterialColors.has(mat):
		return Const.MaterialColors[mat]
	else:
		return Color(50.0, 0.0, 50.0, 1.0)

func get_custom_material(idx: int) -> TerrainMaterial:
	var custom_material: TerrainMaterial = game.map.pixel_map.get_custom_material(idx)
	if not custom_material:
		custom_material = Const.DefaultMaterials.get(idx)
	
	return custom_material

func connect_to_lazy(node: Node, function := "_lazy_process"):
	assert(node.has_method(function), "Najpierw dodaj metodę %s()" % function)
	spiral_of_life.connect("lazy_process", Callable(node, function))

func get_lazy_delta() -> float:
	return spiral_of_life.timer

func init_player_projectile(projectile_owner: Node2D, area_collider: Area2D, data: Dictionary):
	data.owner = projectile_owner
	data.collider = area_collider

	area_collider.add_to_group("player_projectile")
	area_collider.set_meta("data", data)

	projectile_owner.set_meta("data", data)
	projectile_owner.add_to_group("dont_save")
	Utils.set_collisions(area_collider, Const.ENEMY_COLLISION_LAYER, Utils.ACTIVE)

func init_enemy_projectile(projectile_owner: Node2D, area_collider: Area2D, data: Dictionary):
	data.owner = projectile_owner
	data.collider = area_collider

	area_collider.add_to_group("enemy_projectile")
	area_collider.set_meta("data", data)

	projectile_owner.set_meta("data", data)
	projectile_owner.add_to_group("dont_save")
	Utils.set_collisions(area_collider, Const.PLAYER_COLLISION_LAYER | Const.BUILDING_COLLISION_LAYER, Utils.ACTIVE)


func init_universal_projectile(projectile_owner: Node2D, area_collider: Area2D, data: Dictionary):
	data.owner = projectile_owner
	data.collider = area_collider
	
	area_collider.add_to_group("player_projectile")
	area_collider.add_to_group("enemy_projectile")
	area_collider.set_meta("data", data)
	
	projectile_owner.set_meta("data", data)
	projectile_owner.add_to_group("dont_save")

	Utils.set_collisions(area_collider, Const.PLAYER_COLLISION_LAYER | Const.BUILDING_COLLISION_LAYER, Utils.ACTIVE)
	Utils.set_collisions(area_collider, Const.ENEMY_COLLISION_LAYER, Utils.ACTIVE)
	
#	$Sprite/AttackBox.collision_mask = Const.ENEMY_COLLISION_LAYER | Const.PLAYER_COLLISION_LAYER | Const.BUILDING_COLLISION_LAYER
	

func random_sound(base_path: String):
	if not base_path in Const.sound_collection_cache:
		var sounds := []
		var open_path := base_path if base_path.ends_with("/") else base_path.get_base_dir()
		
		var base_file := base_path.get_file()
		var dir := DirAccess.new()
		dir.open(open_path)
		dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
		
		var file := dir.get_next()
		while file:
			if file.ends_with("wav.import") and file.begins_with(base_file):
				sounds.append(load(str(open_path, "/", file.trim_suffix(".import"))))
			
			file = dir.get_next()
		
		assert(not sounds.is_empty())
		Const.sound_collection_cache[base_path] = sounds
	
	var sounds: Array = Const.sound_collection_cache[base_path]
	return sounds[randi() % sounds.size()]

func on_hit(from: Node, to:Dictionary = {}):
	var ownr: Node2D = from.get_meta("data").owner
	if ownr.has_method("on_hit_combo"):
		if to.has("id"):
			ownr.on_hit_combo(to.id)
	if ownr.has_method("on_hit"):
		ownr.on_hit()
	elif not from.get_meta("data").get("keep"):
		ownr.queue_free()

func merge_dicts(base: Dictionary, merger: Dictionary) -> Dictionary:
	## TODO: wywalić to (Dictionary.merge istnieje)
	for key in merger:
		if not key in base:
			base[key] = merger[key]
	return base

func add_to_tracker(node: Node2D, tracker: Nodes2DTrackerMultiLvl, radius: float, extra_focus: float = 0):
	# prints(node.name, node.get_parent().name)
#	prints(node.global_position, node.name )
	if node.global_position == Vector2():
		print(node)
	tracker.add(node, radius, extra_focus)
	node.set_meta("_tracker_", tracker)
#	node.connect("tree_exited", self, "tracker_bug")
	
	if not node.has_meta("_has_killer_"):
		node.set_meta("_has_killer_", true)
		
		var killer: Node = preload("res://Scripts/ObjectKiller.gd").new()
		killer.target = tracker
		killer.another = node
		node.add_child(killer)

func remove_from_tracker(node: Node2D, safe := true):
	if not node.has_meta("_tracker_"):
		if safe:
			assert(false, "Nie jest w trackerze")
		return
	node.get_meta("_tracker_").remove(node)
	node.remove_meta("_tracker_")
#	node.disconnect("tree_exited", self, "tracker_bug")

func tracker_bug():
	push_error("Wezeł w trackerze usuniety recznie. Prosze, przestan!")

var audio_managers: Dictionary

func create_audio_manager(manager: String) -> AudioManager:
	if not manager in audio_managers:
		var man := AudioManager.new()
		audio_managers[manager ] = man
		return man
	return null

func get_audio_manager(manager: String) -> AudioManager:
	return audio_managers[manager]

enum {ACTIVE, PASSIVE, BOTH}

func set_collisions(area: Area2D, layer: int, type: int):
	if type == ACTIVE:
		area.collision_layer = 0
		area.collision_mask = layer
	elif type == PASSIVE:
		area.collision_layer = layer
		area.collision_mask = 0
	else:
		area.collision_layer = layer
		area.collision_mask = layer

var tech_subscribers: Dictionary

func subscribe_tech(node: Node, tech: String):
	assert(node.has_method("_tech_unlocked"), "Dodaj _tech_unlocked(tech) jak chcesz subskrybować")
	
	if Save.is_tech_unlocked(tech):
		node._tech_unlocked(tech)
	else:
		if not tech in tech_subscribers:
			tech_subscribers[tech] = []
		tech_subscribers[tech].append(node)

func check_subscribers(tech: String):
	if tech in tech_subscribers:
		for subscriber in tech_subscribers[tech]:
			if is_instance_valid(subscriber):
				subscriber._tech_unlocked(tech)
	tech_subscribers.erase(tech)

func clamp_to_pixel_map(position: Vector2, pixelmap: PixelMap) -> Vector2:
	position.x = clamp(position.x, 0, pixelmap.get_texture().get_width() - 1)
	position.y = clamp(position.y, 0, pixelmap.get_texture().get_height() - 1)
	return position

func is_position_in_pixel_map(position: Vector2, pixelmap: PixelMap) -> bool:
	if position.x > pixelmap.get_texture().get_width() - 1 or position.x < 0 or position.y > pixelmap.get_texture().get_height() - 1 or position.y < 0:
		return false
	return true

static func pick_random_with_chances(chances: Dictionary, complement := 0, rng: RandomNumberGenerator = null):
	chances = chances.duplicate()
	
	var sum := 0
	for p in chances:
		sum += chances[p]
	
	if complement > 0:
		chances[null] = complement - sum
		sum = complement
	
	var keys := chances.keys()
	
	var random: int
	if rng:
		random = rng.randi() % (sum + 1)
	else:
		random = randi() % (sum + 1)
	
	var partial: int = chances[keys[0]]
	var i := 0
	
	while partial < random:
		i += 1
		partial += chances[keys[i]]
	
	return keys[i]

enum {UI_SELECT, UI_FAIL}

func play_ui_sample(sample: int):
	match sample:
		UI_SELECT:
			play_sample(preload("res://SFX/UI/CountPoint.wav"), null,false, 1.02,0.7).volume_db = -8
		UI_FAIL:
			play_sample(preload("res://SFX/UI/OptionsFail.wav"), null,false, 1.02,0.7)

class AudioManager:
	var max_samples := 2
	var min_delay: float
	var pitch_scale := 1.0
	var random_pitch := 1.0
	var volume := 1.0
	var skip_outside_screen: bool
	var max_distance= -1.0
	var rnd_offset := false
	
	var _sample_list: Dictionary
	var _playing: int
	var _queue: Array
	var _last_play_time: int
	
	func set_sample(sample, min_plays: int = 1):
		_sample_list[min_plays] = sample
	
	func overplayed():
		return _playing>=max_samples
	
	func play(source, override_volume := -1):
		if _playing == max_samples or Time.get_ticks_msec() - _last_play_time < min_delay * 1000:
			return
		
		if skip_outside_screen:
			var position = source
			if source is Node2D:
				position = source.position
			if is_nan(Utils.game.camera.get_camera_screen_center().y):
				return
			if Utils.game.camera.get_camera_screen_center().distance_squared_to(position) >= 3686400:
				return
		
		_playing += 1
		
		_queue.append(source)
		call_deferred("_play", override_volume)
	
	func _play(override_volume):
		if _queue.is_empty():
			return
		_last_play_time = Time.get_ticks_msec()
		var k := _queue.size()
		
		while k > 0:
			for i in k:
				var j: int = k - i
				
				if j in _sample_list:
					k -= j
					var sample = _sample_list[j]
					
					var sound: AudioStream
					if sample is AudioStream:
						sound = sample
					elif sample is String:
						sound = Utils.random_sound(sample)
					
					var aud = Utils.play_sample(sound, _queue[k], true, random_pitch, pitch_scale, rnd_offset)
					if override_volume >= 0:
						aud.volume_db = override_volume
					else:
						aud.volume_db = volume
					if max_distance>0:
						aud.max_distance=max_distance
						
					aud.connect("tree_exited", Callable(self, "_audio_finished").bind(j))
					
					break
		
		_queue.clear()
	
	func _audio_finished(count: int):
		_playing -= count

func generate_scorecard(map_name: String, score: int, scoreboard: Dictionary, map_uid: String, completed: bool):
	var generator = preload("res://Nodes/Map/ScorecardGenerator.tscn").instantiate()
	generator.map_name = map_name
	generator.score = score
	generator.scoreboard = scoreboard
	generator.uid = map_uid
	generator.completed = completed
	
	var viewport := SubViewport.new()
	viewport.size = generator.size
	viewport.usage = SubViewport.USAGE_2D
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.render_target_v_flip = true
	viewport.add_child(generator)
	add_child(viewport)
	
	await generator.finished
	
	DirAccess.new().make_dir_recursive("user://scorecards")
	viewport.get_texture().get_data().save_png("user://scorecards/%s.png" % map_uid)
	viewport.queue_free()

func get_map_uid(map: String) -> String:
	if map.get_extension() == "lcmap":
		var map_file := MapFile.new()
		map_file.load_from_file(map)
#		map_file.load_metadata(map) ## TODO: to później
		return map_file.uid
	else:
		var uid = map.get_file().substr(0, 9)
		if uid.length() < 9:
			uid += "123456789".substr(0, 9 - uid.length())
		return uid

func debug_replace_waves(file):
	Utils.game.map.wave_manager.current_wave = 0
	Utils.game.map.wave_manager.current_repeat = 0
	Utils.game.map.wave_manager.current_wave_multiplier = 1.0
	Utils.game.map.wave_manager.current_wave_number = 0
	Utils.game.map.wave_manager.wave_to_launch = {}
	Utils.game.map.wave_manager.wave_countdown = 0
	Utils.game.map.wave_manager.spawn_queue = []
	Utils.game.map.wave_manager.is_spawning = false
	Utils.game.map.wave_manager.started_spawning = false
	Utils.game.map.wave_manager.prev_living = 0
	Utils.game.map.wave_manager.wave_started_time = 0
	Utils.game.map.wave_manager.set_data_from_file(file)

func call_super_deferred(object: Object, method: String, binds := [], time := 0.1):
	get_tree().create_timer(time).connect("timeout", Callable(object, method).bind(binds))

var node_dict: Dictionary
var prev_node_dict: Dictionary

func debug_count_nodes(from = null):
	if from == null:
		debug_count_nodes(game)
		if prev_node_dict:
			for path in node_dict:
				var p = str(path)
				if not p in prev_node_dict:
					prints("NEW", path, node_dict[p])
				elif node_dict[p] > prev_node_dict[p]:
					prints(path, prev_node_dict[p], "+", node_dict[p] - prev_node_dict[p])
		
		prev_node_dict = node_dict
		node_dict = {}
		return
	
	var child_count = 0
	for node in from.get_children():
		child_count += 1
		child_count += debug_count_nodes(node)
	
	var p = str(game.get_path_to(from))
	if not "@" in p:
		node_dict[p] = child_count
	
	return child_count

func array_map(array: Array, f: FuncRef) -> Array:
	var ret: Array
	ret.resize(array.size())
	
	for i in array.size():
		ret[i] = f.call_func(array[i])
	
	return ret

func get_prev_sibling(node: Node) -> Node:
	if node.get_index() == 0:
		return null
	return node.get_parent().get_child(node.get_index() - 1)

func get_next_sibling(node: Node) -> Node:
	if node.get_index() == node.get_parent().get_child_count() - 1:
		return null
	return node.get_parent().get_child(node.get_index() + 1)

func is_using_joypad() -> bool:
	if OS.has_feature("mobile"):
		return true
	
	match Save.config.single_player_controls:
		Config.CONTROL_AUTO, Config.CONTROL_ALL:
			return use_joypad
		Config.CONTROL_JOYPAD:
			return true
	
	return false

func notify_event(event: String, data = null):
	if event_listener:
		event_listener.notify_event(event, data)

func notify_object_event(object: Object, event: String):
	var meta_name := "EV_" + event
	if not object.has_meta(meta_name):
		object.set_meta(meta_name, true)
		get_tree().connect("physics_frame", Callable(object, "remove_meta").bind(meta_name), CONNECT_ONE_SHOT | CONNECT_DEFERRED)

class HexPoints:
	const _sqrt3 = sqrt(3.0)

	static func get_hex_arranged_points_in_rectangle(rect: Rect2, spacing: float) -> Array:
		var diagonal_sq := pow(rect.size.length() / 2, 2)
		var available: Array
		var marker_index: int
		
		var coord: Vector2
		while coord.length_squared() < diagonal_sq:
			var real_coord := coord + rect.get_center()
			if rect.has_point(real_coord):
				available.append(real_coord)
			
			marker_index += 1
			coord = _getMarkerPosition(marker_index, spacing)
		
		return available
	
	static func _getMarkerPosition(_index: int, _markerSpacing: float) -> Vector2:
		# mathfs
		var ring:float = _getRing(_index)
		
		if ring==0:
			return Vector2.ZERO
		
		var radius:float = _markerSpacing / 2.0
		var horizontalStep:float = _sqrt3 * radius
		var verticalStep:float = _markerSpacing * 0.75
		
		var angle_deg:float = (60.0 / ring) * _index
		var angle_rad:float = PI / 180.0 * angle_deg
		
		return Vector2(_markerSpacing * cos(angle_rad) * ring,
			_markerSpacing * sin(angle_rad) * ring)
	
	static func _getRing(_index: int) -> float:
		var ringX: float = sqrt( _index/3.0 + 0.25 ) - 0.5
		return ceil(snapped( ringX, 0.001 ))

func get_internal_tag_name(tag: String) -> String:
	if tag.begins_with("objective"):
		return tr("Objective: %s") % tr(Const.WinConditions[tag.get_slice(":", 1)])
	else:
		match tag:
			"validated":
				return "Is Validated"
			"events":
				return "Has Custom Events"
			"waves":
				return "Has Waves"
	
	return ""

func print_material_mask(mask: int):
	var mats: PackedStringArray
	for i in Const.Materials.keys().size():
		if mask & (1 << i):
			mats.append(Const.Materials.keys()[i])
	", ".join(print(mats))
	
	
func get_global_transform_until_null(node:CanvasItem) -> Transform2D:
	var xform = Transform3D();
	var pi = node.get_parent()
	if pi and pi.has_method("get_transform"):
		xform = get_global_transform_until_null(pi) * node.get_transform();
	else:
		xform = node.get_transform();
	return xform;

func recolor_theme(new_main_color: Color, new_secondary_color: Color):
	if new_main_color == Const.UI_MAIN_COLOR and new_secondary_color == Const.UI_SECONDARY_COLOR:
		return
	
	var theme = preload("res://Resources/Anarchy/Themes/theme_anarchy.tres")
	for i in Theme.DATA_TYPE_MAX:
		for type in theme.get_theme_item_type_list(i):
			for color in theme.get_color_list(type):
				if theme.get_color(color, type) == Const.UI_MAIN_COLOR:
					theme.set_color(color, type, new_main_color)
				elif theme.get_color(color, type) == Const.UI_SECONDARY_COLOR:
					theme.set_color(color, type, new_secondary_color)
			
			for stylebox in theme.get_stylebox_list(type):
				var style = theme.get_stylebox(stylebox, type)
				if style is StyleBoxFlat:
					if round(style.bg_color.r*255) == round(Const.UI_MAIN_COLOR.r*255) and round(style.bg_color.g*255) == round(Const.UI_MAIN_COLOR.g*255) and round(style.bg_color.b*255) == round(Const.UI_MAIN_COLOR.b*255):
						style.bg_color.r = new_main_color.r
						style.bg_color.g = new_main_color.g
						style.bg_color.b = new_main_color.b
					elif style.bg_color == Const.UI_SECONDARY_COLOR:
						style.bg_color = new_secondary_color
						
					if style.border_color == Const.UI_MAIN_COLOR:
						style.border_color = new_main_color
					elif style.border_color == Const.UI_SECONDARY_COLOR:
						style.border_color = new_secondary_color
				elif style is StyleBoxLine:
					if style.color == Const.UI_MAIN_COLOR:
						style.color = new_main_color
					elif style.color == Const.UI_SECONDARY_COLOR:
						style.color = new_secondary_color
	
	Const.UI_MAIN_COLOR = new_main_color
	Const.UI_SECONDARY_COLOR = new_secondary_color
	get_tree().current_scene.propagate_notification(Control.NOTIFICATION_THEME_CHANGED)

func fix_broken_script(file: String, fixed_script: String, line := 2):
	var f := File.new()
	f.open(file, File.READ)
	var lines := f.get_as_text().split("\n")
	lines[line] = fixed_script
	f.close()
	
	f.open(file, File.WRITE)
	f."\n".join(store_string(lines))
	f.close()

func start_time_tracking(variable: String):
	set_meta("tt0_" + variable, Time.get_ticks_usec())
	set_meta("tt_" + variable, Time.get_ticks_usec())
	print("Time tracking for '", variable, "' started")

func print_time_tracking_checkpoint(variable: String, checkpoint: String):
	if not has_meta("tt0_" + variable):
		push_error("Może zacznij najpierw, co?")
		return
	
	var current := Time.get_ticks_usec()
	print("Time for '", variable, "' at '", checkpoint, "': ", current - get_meta("tt0_" + variable), " (delta: ", current - get_meta("tt_" + variable), ")")
	set_meta("tt_" + variable, current)

func push_time_tracking_checkpoint(variable: String):
	if not has_meta("tt0_" + variable):
		push_error("Może zacznij najpierw, co?")
		return
	set_meta("tt_" + variable, Time.get_ticks_usec())

func random_point_in_circle(outer_radius: float, inner_radius := 0.0):
	assert(outer_radius >= inner_radius)
	if is_zero_approx(inner_radius):
		return Vector2.RIGHT.rotated(randf() * TAU) * sqrt(randf()) * outer_radius # szybciej
	else:
		return Vector2.RIGHT.rotated(randf() * TAU) * sqrt(randf_range(pow(1 - (outer_radius - inner_radius) / outer_radius, 2), 1)) * outer_radius

func sorty_by_category(building1: Dictionary, building2: Dictionary):
	return building1.get("category", "") < building2.get("category", "")

func make_me_rect(vec1: Vector2, vec2: Vector2) -> Rect2:
	var rect: Rect2
	
	rect.position.x = min(vec1.x, vec2.x)
	rect.position.y = min(vec1.y, vec2.y)
	rect.size.x = abs(vec1.x - vec2.x)
	rect.size.y = abs(vec1.y - vec2.y)
	
	return rect

func open_folder(folder: String):
	if OS.has_feature("OSX"):
		OS.execute("open", [folder])
	else:
		OS.shell_open(folder)

var async_resource_loader: RefCounted
var internal_res_cache: Dictionary

func load_resource(path: String, interactive: bool):
	assert(not async_resource_loader or async_resource_loader.is_finished)
	if path in internal_res_cache:
		interactive = false
	
	async_resource_loader = preload("res://Scripts/SceneLoader.gd").new()
	if interactive:
		async_resource_loader.interactive_load(path)
		await async_resource_loader.finished
		internal_res_cache[path] = async_resource_loader.resource
	else:
		if path in internal_res_cache:
			async_resource_loader.resource = internal_res_cache[path]
		else:
			async_resource_loader.resource = load(path)
		
		await get_tree().idle_frame
		async_resource_loader.is_finished = true

func clear_async():
	async_resource_loader = null
	internal_res_cache.clear()

func get_version_suffix() -> String:
	if OS.has_feature("steam"):
		return "Steam"
	elif OS.has_feature("gog"):
		return "GOG"
	elif OS.has_feature("epic"):
		return "Epic Games"
	elif OS.has_feature("appstore"):
		return "App Store"
	else:
		return ""

func safe_open(opener, path: String, mode := -1) -> bool:
	if opener is File:
		return opener.open(path, mode) == OK
	elif opener is DirAccess:
		return opener.open(path) == OK
	return false

func button_event(idx: int) -> InputEventJoypadButton:
	var b := InputEventJoypadButton.new()
	b.button_index = idx
	return b
