@tool
extends Node
class_name Constants

@export var resource_pickup_textures:Array[Texture2D] # (Array, Texture2D)
@export var resource_icons_textures:Array[Texture2D] # (Array, Texture2D)

const GAME_DATA_SCRIPT = preload("res://Scripts/Data/GameData.gd")
var game_data: GAME_DATA_SCRIPT
var is_steam_deck: bool

static var FROG_MAPS = ["res://Maps/FlareSiege.tscn", "res://Maps/TutorialMap.tscn", "res://Maps/DemoMap.tscn", "res://Maps/map_challange_T001.tscn"]

#var RESOLUTION := Vector2(ProjectSettings.get("display/window/size/width"), ProjectSettings.get("display/window/size/height"))

var PLAYER_COLLISION_LAYER: int
var PICKUP_COLLISION_LAYER: int
var BUILDING_COLLISION_LAYER: int
var ENEMY_COLLISION_LAYER: int

var CAMERA_ZOOM := 8.0
var PLAYER_LIMIT := 2

static var EXPLOSION = preload("res://Nodes/Effects/Explosion/Explosion.tscn")
#const DAMAGE_NUMBER = preload("res://Nodes/UI/DamageNumber.tscn")
static var TITLE_SCENE = "res://Resources/Anarchy/Scenes/anarchy_main_menu.tscn"

static var MapNames = {DemoMap = "Blast from the Past", TrueBeginningMap = "Underground Survival", map_challange_T001 = "First Encounter", FlareSiege = "Flare Siege", TutorialMap = "Tutorial", FearMap = "Fear the Darkness"}
static var WinConditions = {waves = "Defeat All Waves", item = "Defeat All Waves", finish = "Reach Finish", time = "Survive Time", building = "Place Building", technology = "Research Tech", enemy = "Kill Enemy", genocide = "Kill All Enemies", score = "Reach Score", custom = "Custom"}

enum Difficulty { CASUAL, EASY, NORMAL, DIFFICULT }
static var DIFFICULTY_SCORE_MULTIPLIERS = [0.5, 0.85, 1, 1.3]
static var DIFFICULTY_RESOURCE_MULTIPLIERS = [2.0, 1.1, 1.0, 0.7]
static var DIFFICULTY_STARTING_RESOURCES = [1000, 300, 0, 0]

static var BASE_DEFENSE_MAPS = ["DemoMap", "TrueBeginningMap", "map_challange_T001"]
static var BOSS_ENEMIES = ["Crystal GRUBAS", "Turtle", "King"]

var UI_MAIN_COLOR: Color
var UI_ORIGINAL_MAIN_COLOR: Color
var UI_SECONDARY_COLOR: Color
var BLOOD_COLOR: Color

enum ControlID { SINGLE_PLAYER = 1, KEYBOARD_MOUSE, JOYPAD1, JOYPAD2, JOYPAD3, JOYPAD4 }

enum ItemIDs {
	METAL_SCRAP,
	LUMEN,
	
	AMMO,
	NAPALM,
	SPEAR,
	HAMMER,
	SICKLE,
	LANCE,
	BAT,
	KATANA,
	PLASMA_GUN,
	ONE_SHOT,
	MAGNUM,
	SHOTGUN,
	MACHINE_GUN,
	ROCKET_LAUNCHER,
	FLAMETHROWER,
	LASER,
	LIGHTNING_GUN,
	MINE,
	GRENADE,
	DYNAMITE,
	DIRT_GRENADE,
	SUPER_GRENADE,
	FLARE,
	REPAIR_KIT,
	DRILL,
	HOOK,
	FOAM_GUN,
	PICKAXE,
	
	MEDPACK,
	ARMORED_BOX,
	LUMEN_CLUMP,
	METAL_NUGGET,
	TECHNOLOGY_ORB,
	KEY,
	ARTIFACT,
}
const RESOURCE_COUNT = ItemIDs.AMMO

enum Ammo {
	BULLETS,
	ROCKETS,
	LASERS,
}

const KEY_COLORS = ["Lumen", "Azure", "Silver", "Amber"]
const ARTIFACT_NAMES = ["Stone Tablet", "AI Chip", "Monster Heart"]

enum Materials {
	DIRT = 0,
	CLAY = 1, # swappable
	ROCK = 2,
	WEAK_SCRAP = 3,
	STRONG_SCRAP = 4,
	ULTRA_SCRAP = 5,
	SANDSTONE = 6, # swappable
	GRANITE = 7, # swappable
	FOAM = 8,
	STEEL = 9, # swappable
	FOAM2 = 10,
	ASHES = 11,
	CONCRETE = 12, # swappable
	ICE = 13, # swappable
	WALL3 = 19,
	LOW_BUILDING = 20,
	WALL = 21,
	WALL1 = 22,
	WALL2 = 23,
	TAR = 24,
	EMPTY = 25,
	DEAD_LUMEN = 26,
	LUMEN = 27,
	GATE = 28,
	WATER = 29,
	LAVA = 30,
	STOP = 32,
}

const SwappableMaterials = [
	Materials.CLAY,
	Materials.STEEL,
	Materials.CONCRETE,
	Materials.ICE,
	Materials.SANDSTONE,
	Materials.GRANITE,
]

const MaterialTextures = {
	Materials.DIRT: preload("res://Resources/Terrain/Images/WallDirt.png"),
	# 2 swappable
	Materials.ROCK: preload("res://Resources/Terrain/Images/WallBedrock.png"),
	Materials.WEAK_SCRAP: preload("res://Resources/Terrain/Images/WallMetalOre.png"),
	Materials.STRONG_SCRAP: preload("res://Resources/Terrain/Images/WallBetterMetalOre.png"),
	Materials.ULTRA_SCRAP: preload("res://Resources/Terrain/Images/WallUltraMetalOre.png"),
	# 6 swappable
	# 7 swappable
	Materials.FOAM: preload("res://Resources/Terrain/Images/WallFoam.png"),
	# 9 swappable
	Materials.FOAM2: preload("res://Resources/Terrain/Images/WallFireproofFoam.png"),
	Materials.ASHES: preload("res://Resources/Terrain/Images/WallAshes.png"),
	# 12 swappable
	# 13 swappable
	# 14
	# 15
}

const DefaultMaterials = {
	Materials.CLAY: preload("res://Resources/Terrain/TerrainTextures/Rock.tres"),
	Materials.STEEL: preload("res://Resources/Terrain/TerrainTextures/Steel.tres"),
	Materials.CONCRETE: preload("res://Resources/Terrain/TerrainTextures/Concrete.tres"),
	Materials.ICE: preload("res://Resources/Terrain/TerrainTextures/Ice.tres"),
	Materials.SANDSTONE: preload("res://Resources/Terrain/TerrainTextures/Sandstone.tres"),
	Materials.GRANITE: preload("res://Resources/Terrain/TerrainTextures/Granite.tres"),
}

const ResourceNames = {
	ItemIDs.METAL_SCRAP: "Metal",
	ItemIDs.LUMEN: "Lumen",
}

const ResourceSpawnRate = {
	Materials.LUMEN: 100,
	Materials.WEAK_SCRAP: 100,
	Materials.STRONG_SCRAP: 40,
	Materials.ULTRA_SCRAP: 12,
}

const MaterialResources = {
#	Materials.DIRT: ItemIDs.DIRT,
#	Materials.CLAY: ItemIDs.CLAY,
#	Materials.ROCK: ItemIDs.STONE,
	Materials.WEAK_SCRAP: ItemIDs.METAL_SCRAP,
	Materials.STRONG_SCRAP: ItemIDs.METAL_SCRAP,
	Materials.ULTRA_SCRAP: ItemIDs.METAL_SCRAP,
#	Materials.RICH_COAL: ItemIDs.RICH_COAL,
#	Materials.RICH_METAL_ORE: ItemIDs.RICH_METAL_ORE,
#	Materials.STEEL: ItemIDs.METAL_ORE,
#	Materials.BRICK: ItemIDs.BRICK, 
	Materials.LUMEN: ItemIDs.LUMEN, 
}

static var CraftedRects = {}

func get_resource_color(material_type: int) -> Color:
	var color_range_start = get_resource_color_range_start(material_type)
	var color_range_end = get_resource_color_range_end(material_type)
	return  Color(randf_range(color_range_start.r, color_range_end.r),  randf_range(color_range_start.g, color_range_end.g),  randf_range(color_range_start.b, color_range_end.b), randf_range(color_range_start.a, color_range_end.a))

func get_resource_color_range_start(material_type: int) -> Color:
	return Color(0.8, 0.8, 0.8, 1.0)

func get_resource_color_range_end(material_type: int) -> Color:
	return Color(1.2, 1.2, 1.2, 1.0)

#allow glow of particles debris 
const halfColor= Color(0.1, 0.1, 0.1, 1.0)
const oldColorFix= Color(0.5, 0.5, 0.5, 1.0)

const MaterialColors = {
	Materials.DIRT: Color("433623") * halfColor,
	Materials.CLAY: Color("5a575c") * halfColor, # Rock.tres
	Materials.ROCK: Color("24242e") * halfColor,
	Materials.WEAK_SCRAP: Color("622e19") * halfColor,
	Materials.STRONG_SCRAP: Color(0.8,0.6,0.05)* halfColor,
	Materials.ULTRA_SCRAP: Color(0.9,0.9,0.0)  * halfColor,
	Materials.ASHES: Color("1e1e1f") * halfColor,
	Materials.STEEL: Color.LIGHT_SLATE_GRAY * halfColor*oldColorFix, # Steel.tres
	Materials.FOAM: Color.LIGHT_YELLOW * halfColor*oldColorFix,
	Materials.FOAM2: Color.LIGHT_CORAL* halfColor*oldColorFix,
	Materials.WALL: Color("4b352c") * halfColor,
	Materials.WALL1: Color("231f1f") * halfColor,
	Materials.WALL2: Color("372a28") * halfColor,
	Materials.WALL3: Color("3f211e") * halfColor,
	Materials.WATER: Color(0.6,1.0,2.0,0.1) * halfColor*oldColorFix,
	Materials.LAVA: Color(5.0,2.5,0.8) * halfColor,
	Materials.LUMEN: Color(3.0,1.5,3.0,0.1) * halfColor,
	Materials.DEAD_LUMEN: Color(0.0,0.0,1.0,0.5) * halfColor,
	Materials.TAR: Color(0.0,0.0,0.0,0.0),
}

#Color("00372a")
const PLAYER_HSV_OFFSETS = [0.5,0.9,0.4,0.8,0.2,0.1,0.65]

#Color("cb7b41") old cursor color
const PLAYER_COLORS = [Color("ffb800"), Color("00edff"), Color("d30008"), Color("2c00d3"), Color("d3009c")]
const PLAYER_GLOW_COLORS = [PLAYER_COLORS[0]*1.5, PLAYER_COLORS[1]*1.5, PLAYER_COLORS[2]*1.8, PLAYER_COLORS[3]*3.0, PLAYER_COLORS[4]*1.8]

var material_colors_texture = null

enum Aspects {WEAK, HEAVY}

const UPGRADES = {
	reload = "Max Bullets|Increases the amount of shots before reload.",
	reload_time = "Reload Speed|Shortens reloading time.",
	reload_speed = "Reload Speed|Reduces time between shots.|res://Nodes/Buildings/Lab/tech_icons/fire_rate.png",
	damage = "Damage|Increases damage dealt.|res://Nodes/Buildings/Lab/tech_icons/damage.png",
	delay = "Fire Rate|Increases rate of fire.|res://Nodes/Buildings/Lab/tech_icons/fire_rate.png",
	fire_rate = "Fire Rate|Increases rate of fire.|res://Nodes/Buildings/Lab/tech_icons/fire_rate.png",
	recoil = "Recoil Reduction|Reduces the recoil while shooting.",
	custom_explosion_power = "Explosion Power|Increases explosion size.|res://Nodes/Buildings/Lab/tech_icons/damage.png", ## TODO: inna ikona
	flame_amount = "Flame Power|Increases amount of flames.",
	sticky_flame = "Sticky Flame|Flames will linger on ground.",
	missile_count = "Missile Count|Increases the number of missiles shot in a volley.",
	range = "Range|Increases shooting and detection range.",
	weapon_range = "Range|Increases the range of projectiles.",
	pierce = "Pierce|Bullets will pierce through enemies.",
	antiair = "Anti-Air|Double damage against flying enemies.",
	critical = "Critical Hit|25% chance to deal 4x damage.",
	cluster = "Cluster Explosion|2 more smaller bombs spawn after explosion.",
	drilling_power = "Drilling Power|Allows to drill harder materials and also faster.|res://Nodes/Buildings/Lab/tech_icons/drill_speed.png",
	stamina_cost = "Stamina Usage|Reduces the stamina required for attacking.|res://Nodes/Buildings/Lab/tech_icons/spear_stamina.png",
	custom_stab_charge_speed = "Charge Speed|Reduces the time required to charge a stab.|res://Nodes/Buildings/Lab/tech_icons/spear3.png",
	ammo_per_shot = "Bullet Count|Increases number of bullets shot at once.|res://Nodes/Buildings/Lab/tech_icons/many_bullets.png",
	ammo_reduction = "Ammo Efficiency|Reduces the ammo used per shot.|res://Nodes/Buildings/Lab/tech_icons/ammo_reduction.png",
	explosion_damage = "Explosion Damage|Increases damage of the explosion.|res://Nodes/Buildings/Lab/tech_icons/damage.png", ## TODO: inna ikona
}

func get_upgrade_name(upgrade_id: String) -> String:
	return UPGRADES[upgrade_id].get_slice("|", 0)

func get_upgrade_description(upgrade_id: String) -> String:
	return UPGRADES[upgrade_id].get_slice("|", 1)

func get_upgrade_icon(upgrade_id: String) -> Texture2D:
	var upgrade_path: String = UPGRADES[upgrade_id].get_slice("|", 2)
	if upgrade_path.is_empty():
		return preload("res://Nodes/Buildings/Common/upgrade_icon.png")
	else:
		return load(upgrade_path) as Texture2D

const SCOUT_ICONS = {health = preload("res://Nodes/Buildings/HeroCenter/hp_icon.png"), stamina = preload("res://Nodes/Buildings/HeroCenter/stamina_icon.png"), speed = preload("res://Nodes/Buildings/HeroCenter/speed_icon.png"), evasion = preload("res://Nodes/Buildings/HeroCenter/EvadeCrappy.png"), backpack = preload("res://Nodes/Buildings/Lab/tech_icons/backpack.png")}

var Technology: Dictionary
var Items: Dictionary
var Enemies: Dictionary
var Buildings: Dictionary
var CampaignLevels: Dictionary

var HINTS := []

var techs_in_lab: int

static var _CACHE = []
var  cached_images = {}
var technology_by_tag: Dictionary

func get_cached_image(path):
	var ret=cached_images.get(path)
	if ret:
		return ret
	else:
		ret = ResourceLoader.load(path).get_data()
		cached_images[path]=ret
		return ret
		

func _ready():
	var theme = preload("res://Resources/Anarchy/Themes/theme_anarchy.tres")
	UI_MAIN_COLOR = theme.get_color("font_color", "main_menu_button")
	UI_ORIGINAL_MAIN_COLOR = UI_MAIN_COLOR
	UI_SECONDARY_COLOR = theme.get_color("font_color", "button_cyan")

	var material_colors_vector := PackedColorArray()
	for i in range(255):
		material_colors_vector.push_back(Const.MaterialColors.get(i,Color.TRANSPARENT))
	material_colors_texture = Utils.create_emission_mask_from_colors(material_colors_vector)
	
	var skip_preload := false
	if get_override("FAST_LOAD"):
		skip_preload = true
	
	if not skip_preload:
		cache_directory("res://Nodes/Player/Weapons")
		cache_directory("res://Nodes/Buildings")
		cache_directory("res://Scenes")
		cache_directory("res://SFX")
		
		for set in ["res://SFX/Building/Spark", "res://SFX/Weapons/gun_grenade_launcher_shot", "res://SFX/Bullets/bullet_shell_bounce_concrete1", "res://SFX/Weapons/gun_rifle_sniper_shot", "res://SFX/Explosion/explosion_small", "res://SFX/Bullets/bullet_flyby_fast_", "res://Nodes/Effects/Zap/zap", "res://SFX/Enemies/Arthoma/artoma-attack", "res://SFX/Enemies/Arthoma/artoma-footstep", "res://SFX/Enemies/Small monster Death", "res://SFX/Enemies/Small monster Growls", "res://SFX/Enemies/Medium monster attack", "res://SFX/Enemies/GRUBAS/HeadExploding", "res://SFX/Enemies/GRUBAS/Attack_", "res://SFX/Environmnent/rock_smashable_hit_impact_", "res://SFX/Environmnent/rock_smashable_hit_impact_large_", "res://SFX/Enemies/GRUBAS/Grunt", "res://SFX/Enemies/GRUBAS/Footsteps", "res://SFX/Enemies/GRUBAS/Attack", "res://SFX/Misc/slime", "res://SFX/Enemies/Turtle/monster", "res://SFX/Enemies/Turtle/monsterFoot", "res://SFX/Bullets/bullet_impact_body_flesh", "res://SFX/Enemies/spawn", "res://SFX/Objects/ChestOpen", "res://SFX/Objects/impactwood", "res://SFX/Misc/mushroom/squeezing", "res://SFX/Misc/mushroom/air-release.wav", "res://SFX/Bullets/bullet_impact_metal_light", "res://SFX/Flare/SPRAY_CAN_Spray_Loop_0", "res://SFX/Building/Construction/", "res://SFX/Crystal/Glass breaking", "res://SFX/Crystal/Glass item Breaks", "res://SFX/Bullets/pick_axe_stone_small_hit_mine_impact", "res://SFX/Player/Mining (Hitting Stone With Pickaxe) 1.wav", "res://SFX/Weapons/gun_revolver_pistol_dry_fire", "res://SFX/Weapons/gun_shotgun_shot", "res://SFX/Weapons/gun_shotgun_cock", "res://SFX/Player/Male taking damage", "res://SFX/Player/Dirt footsteps", "res://SFX/Weapons/gun_revolver_pistol_cylinder_open", "res://SFX/Weapons/gun_revolver_pistol_load_bullet", "res://SFX/Weapons/gun_revolver_pistol_cylinder_close", "res://SFX/Weapons/gun_revolver_pistol_cock", "res://SFX/Pets/PetNotice", "res://SFX/Explosion/Explosion Gas_", "res://SFX/Bullets/bullet_impact_metal_light_", "res://SFX/Pickups/metal_small_movement_", "res://SFX/Pickups/Collect star ", "res://SFX/Player/Dash/Dash Heavy Armor 1_", "res://SFX/Weapons/BodyFlesh/Body Flesh ", "res://SFX/Weapons/Spear/whoosh_swish_high_fast_", "res://SFX/Weapons/Spear/whoosh_swish_small_harsh_", "res://SFX/Weapons/Spear/whoosh_weapon_spin_", "res://SFX/Weapons/gun_revolver_pistol_shot", "res://SFX/Weapons/gun_pistol_shot_silenced", "res://SFX/Player/Mining (Hitting Stone With Pickaxe)", "res://SFX/Bullets/bullet_impact_dirt", "res://SFX/Bullets/bullet_impact_concrete_brick"]:
			Utils.random_sound(set)
	
	for i in 32:
		var layer: String = ProjectSettings.get(str("layer_names/2d_physics/layer_", i + 1))
		if layer == "Player Layer":
			PLAYER_COLLISION_LAYER = pow(2, i)
		elif layer == "Building Layer":
			BUILDING_COLLISION_LAYER = pow(2, i)
		elif layer == "Enemy Layer":
			ENEMY_COLLISION_LAYER = pow(2, i)
		elif layer == "Pickup Layer":
			PICKUP_COLLISION_LAYER = pow(2, i)
		
		if PLAYER_COLLISION_LAYER and BUILDING_COLLISION_LAYER and ENEMY_COLLISION_LAYER and PICKUP_COLLISION_LAYER:
			break
	
	assert(PLAYER_COLLISION_LAYER and BUILDING_COLLISION_LAYER and ENEMY_COLLISION_LAYER and PICKUP_COLLISION_LAYER)

func cache_directory(path: String):
	var dir = DirAccess.open(path)
	dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
	
	var file := dir.get_next()
	while file:
		if file.get_extension() == "tscn":
			if file.get_file() == "TrailerPlayer.tscn": ## :/
				file = dir.get_next()
				continue
			print("Caching file: ", file.get_file())
			_CACHE.append(load(path + "/" + file))
		elif dir.dir_exists(file):
			cache_directory(path + "/" + file)
		
		file = dir.get_next()

func _enter_tree() -> void:
	if not Engine.is_editor_hint() and (OS.has_feature("editor") or (OS.has_feature("nx") and OS.is_debug_build())) and ResourceLoader.exists("res://override.gd"):
		var over = load("res://override.gd")
		if not "DISABLED" in over:
			set_meta("override", load("res://override.gd"))
	
	#if SteamAPI.singleton and SteamAPI.singleton.isSteamRunningOnSteamDeck():
	#	is_steam_deck = true
	elif OS.has_feature("X11") and DisplayServer.screen_get_size() == Vector2i(1280, 800):
		is_steam_deck = true
	elif get_override("TEST_STEAM_DECK"):
		is_steam_deck = true
	
	var storage: TextDatabase
	
	storage = TextDatabase.new()
	storage.entry_name = "tech"
	storage.add_mandatory_property("name", TYPE_STRING)
	storage.add_mandatory_property("description", TYPE_STRING)
	storage.add_mandatory_property("cost", TYPE_INT)
	storage.add_mandatory_property("duration", TYPE_FLOAT)
	storage.add_mandatory_property("icon", TYPE_STRING)
	storage.add_valid_property("depend", TYPE_ARRAY)
	storage.add_valid_property("hide_in_lab", TYPE_BOOL)
	storage.add_valid_property("tag", TYPE_STRING)
	storage.load_from_path("res://Resources/Data/Technology.cfg")
	Technology = storage.get_dictionary()
	
	for tech in Technology.values():
		if "tag" in tech:
			if not tech.tag in technology_by_tag:
				technology_by_tag[tech.tag] = []
			
			technology_by_tag[tech.tag].append(tech.tech)
		
		if not "hide_in_lab" in tech:
			techs_in_lab += 1
	
	storage = preload("res://Resources/Data/EnemyStorage.gd").new()
	storage.load_from_path("res://Resources/Data/Enemies.cfg")
	Enemies = storage.get_dictionary()
	
	storage = load("res://Resources/Data/BuildingStorage.gd").new()
	storage.ids = ItemIDs.keys()
	storage.load_from_path("res://Resources/Data/Buildings.cfg")
	Buildings = storage.get_dictionary()
	
	for building in storage.need_extra_check:
		assert(building in Const.Buildings, "Nieprawidłowy budynek: " + building)
	
	storage = load("res://Resources/Data/ItemStorage.gd").new()
	storage.ids = ItemIDs.keys()
	storage.ammos = Ammo.keys()
	storage.aspects = Aspects.keys()
	storage.load_from_path("res://Resources/Data/Items.cfg")
	Items = storage.get_dictionary()
	
	for building in storage.need_extra_check:
		assert(building in Const.Buildings, "Nieprawidłowy budynek: " + building)
	
	storage = load("res://Resources/Data/CampaignStorage.gd").new()
	storage.load_from_path("res://Resources/Data/Campaign.cfg")
	CampaignLevels = storage.get_dictionary()
	
	var f = FileAccess.open("res://Resources/Data/Hints.txt", FileAccess.READ)
	HINTS = f.get_as_text().split("\n")
	
	if not OS.has_feature("editor"):
		if not OS.has_feature("steam"):
			HINTS.erase(0)
		
		if OS.has_feature("mobile"):
			HINTS.erase(0)
			HINTS.erase(0)
	
	game_data = GAME_DATA_SCRIPT.new()
	
	var dir = DirAccess.open("res://Nodes/Map/Generator/RectGenerators/CraftedRects/")
	dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
	
	var file := dir.get_next()
	while not file.is_empty():
		if file.ends_with("_pixels.bin"):
			var source_name := file.trim_suffix("_pixels.bin")
			var data = {}
			
			f = FileAccess.open("res://Nodes/Map/Generator/RectGenerators/CraftedRects/" + source_name + "_nodes.bin", FileAccess.READ)
			data.scene = f.get_var(true)
			
			f = FileAccess.open("res://Nodes/Map/Generator/RectGenerators/CraftedRects/" + file, FileAccess.READ)
			data.image = f.get_var(true)
			
			CraftedRects[source_name] = data
		
		file = dir.get_next()

var sound_collection_cache: Dictionary

func get_entry_by_scene(set: Dictionary, scene: String) -> Dictionary:
	for entry in set.values():
		if entry.scene == scene:
			return entry
	
	return {}

func get_override(override_name: String):
	var override = get_meta("override", false)
	if override:
		return override.get(override_name)

static func is_resource_built_in(resource: Resource) -> bool:
	return resource.resource_path.is_empty() or resource.resource_path.find("::") > -1

static func get_crafted_rect(rect: String) -> Dictionary:
	if Engine.is_editor_hint():
		var data = {}
		
		var f = FileAccess.open("res://Nodes/Map/Generator/RectGenerators/CraftedRects/" + rect + "_nodes.bin", FileAccess.READ)
		data.scene = f.get_var(true)
		
		f = FileAccess.open("res://Nodes/Map/Generator/RectGenerators/CraftedRects/" + rect + "_pixels.bin", FileAccess.READ)
		data.image = f.get_var(true)
		
		return data
	else:
		return CraftedRects[rect]

const static_texture_container := [null]
