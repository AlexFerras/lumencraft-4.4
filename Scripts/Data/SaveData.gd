extends Resource
class_name SaveData

@export var timestamp: int
@export var game_time: int
@export var ranked: bool
@export var achievements_enabled: bool
@export var slot_name: String

@export var events: Array
@export var unlocked_tech: Dictionary
@export var unlocked_tech_number: Dictionary

@export var current_map: String
@export var player_data: Array
@export var has_coop: bool

@export var game_version: int
@export var campaign: bool
@export var difficulty: int = 2

@export var save_uid: int

enum CompatIDs { # compat
	METAL_SCRAP,
	LUMEN,
	
	AMMO,
	NAPALM,
	SPEAR,
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
	FOAM_GUN
	PICKAXE,
	
	MEDPACK,
	ARMORED_BOX,
	LUMEN_CLUMP,
	METAL_NUGGET,
	TECHNOLOGY_ORB,
	KEY,
	ARTIFACT
}
