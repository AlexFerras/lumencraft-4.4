extends Node

#Steam stats variable names:

var BuildingsBuilt :int = 0	#BuildingsBuilt	INT
var TurretsBuilt :int = 0		#TurretsBuilt	INT
var GatesBuilt :int = 0		#GatesBuilt		INT

var MetalCollected :int = 0	#MetalCollected	INT
var LumenCollected :int = 0	#LumenCollected	INT

var AvgMetalPerHour:float = 0.0 #AvgMetalPerHour	AVGRATE
var AvgLumenPerHour:float = 0.0 #AvgLumenPerHour	AVGRATE
var AvgMetalPerMinute:float = 0.0 #AvgMetalPerMinute	AVGRATE
var AvgLumenPerMinute:float = 0.0 #AvgLumenPerMinute	AVGRATE

var FabricatedItems :int = 0	#FabricatedItems	INT
var ShreddedItems :int = 0		#ShreddedItems	INT
var KilledBugs :int = 0			#KilledBugs		INT
var KilledBosses :int = 0		#KilledBosses	INT

var MaxResearch :int = 0		#MaxResearch	INT --------???
var Deaths :int = 0				#Deaths	INT
var Clones :int = 0				#Clones	INT
var Orbs :int = 0				#Orbs	INT

var GlobalGamesWon :int = 0		#GlobalGamesWon		INT
var GlobalGamesLost :int = 0	#GlobalGamesLost	INT
var GamesWon :int = 0			#GamesWon		INT
var GamesLost :int = 0			#GamesLost	INT

var map_clones :int = 0
var map_turrets :int = 0
var map_buildings :int = 0

#var Respawns :int = 0

var WIN_NO_GUNS:bool
var WIN_NO_TURRETS:bool
var WAVE_NO_ACTION:bool
var WAVE_STAY_IN_BASE:bool

var last_bulldozered:String
var lost_building:int

var turrets := []

func get_user_stats():
	BuildingsBuilt = SteamAPI.singleton.getStatInt("BuildingsBuilt")
	TurretsBuilt   = SteamAPI.singleton.getStatInt("TurretsBuilt")
	GatesBuilt     = SteamAPI.singleton.getStatInt("GatesBuilt")
	MetalCollected = SteamAPI.singleton.getStatInt("MetalCollected")
	LumenCollected = SteamAPI.singleton.getStatInt("LumenCollected")
	AvgMetalPerHour = SteamAPI.singleton.getStatFloat("AvgMetalPerHour")
	AvgLumenPerHour = SteamAPI.singleton.getStatFloat("AvgLumenPerHour")
	AvgMetalPerMinute = SteamAPI.singleton.getStatFloat("AvgMetalPerMinute")
	AvgLumenPerMinute = SteamAPI.singleton.getStatFloat("AvgLumenPerMinute")
	if AvgMetalPerHour > 10000:
		SteamAPI.update_average_stat("AvgMetalPerHour", 1, 60)
		SteamAPI.store_stats()
	if AvgMetalPerHour > 10000:
		SteamAPI.update_average_stat("AvgLumenPerHour", 1, 60)
		SteamAPI.store_stats()

	FabricatedItems = SteamAPI.singleton.getStatInt("FabricatedItems")
	ShreddedItems   = SteamAPI.singleton.getStatInt("ShreddedItems")
	KilledBugs      = SteamAPI.singleton.getStatInt("KilledBugs")
	KilledBosses    = SteamAPI.singleton.getStatInt("KilledBosses")
	MaxResearch     = SteamAPI.singleton.getStatInt("MaxResearch")

	Deaths          = SteamAPI.singleton.getStatInt("Deaths")
	Clones          = SteamAPI.singleton.getStatInt("Clones")
	Orbs            = SteamAPI.singleton.getStatInt("Orbs")
	GamesWon        = SteamAPI.singleton.getStatInt("GamesWon")
	GamesLost        = SteamAPI.singleton.getStatInt("GamesLost")

func get_global_stats():
	GlobalGamesWon = SteamAPI.singleton.getGlobalStatInt("GlobalGamesWon")
	GlobalGamesLost = SteamAPI.singleton.getGlobalStatInt("GlobalGamesLost")

func start_map():
	lost_building = 0
	map_clones = 0
	map_turrets = 0
	map_buildings = 0
	turrets = []

	WIN_NO_GUNS = true
	WIN_NO_TURRETS = true
	
	if not Save.current_map.get_file().get_basename() in Const.BASE_DEFENSE_MAPS:
		WIN_NO_TURRETS = false
	
	WAVE_NO_ACTION = true
	WAVE_STAY_IN_BASE = false

func end_map():
	try("WIN_NO_GUNS")
	try("WIN_NO_TURRETS")

func satisfy(achievement_name: String):
	set(achievement_name, true)

func fail(achievement_name: String):
	set(achievement_name, false)

func try(achievement_name: String):
	match achievement_name:
		"LOSE_BUILDINGS":
			lost_building += 1
			if lost_building>=5:
				SteamAPI.unlock_achievement("LOSE_BUILDINGS")
			SteamAPI.multi_building_destroyed_timer.start(5)
		_:
			if get(achievement_name):
				SteamAPI.unlock_achievement(achievement_name)

func increment_stat(stat_name: String, value:int):
	var stat = get(stat_name) + value
#	print(stat)
	SteamAPI.singleton.setStatInt(stat_name, stat)
	set(stat_name, stat)
	match stat_name:
		"Clones":
			map_clones += value
			if Save.clones == 8 and map_clones >= 8:
				SteamAPI.unlock_achievement("NINE_LIVES")
		"Deaths":
			if stat >= 10:
				SteamAPI.unlock_achievement("IM_BACK")

#	prints("[STEAM] stat increase: ",stat_name, stat)

func update_average_stat(stat_name: String, value:int, length:float):
	SteamAPI.singleton.updateAvgRateStat(stat_name, value, length)
#	prints("[STEAM] stat average: ",stat_name, value)

func building_destroyed_reset():
	lost_building = 0

func _get_save_data() -> Dictionary:
	return Save.get_properties(self, ["WAVE_STAY_IN_BASE", "WAVE_NO_ACTION", "NINE_LIVES", "IM_BACK", "WIN_NO_GUNS", "WIN_NO_TURRETS", "map_clones", "turrets"])

func _set_save_data(data: Dictionary):
	Save.set_properties(self, data)

################## implemented:

# TUTORIAL_FINISHED
# SOLAR_SCORE
# DAMIAN_MAP_50_KILLS
# KILL_GRUBAS
# WEDNESDAY
# BUILDER_1 #BuildingsBuilt (5-)
# BUILDER_2 #BuildingsBuilt (40-)
# BUILDER_3 #BuildingsBuilt (120-0)
# TURRETS_1 #TurretsBuilt (5-0)
# TURRETS_2 #TurretsBuilt (25-0)
# TURRETS_3 #TurretsBuilt (200-0)
# GATES_1 #GatesBuilt (1-0)
# GATES_2 #GatesBuilt (5-0)
# GATES_3 #GatesBuilt (25-0)
# GATES_4 #GatesBuilt (50-0)
# METAL_1 #MetalCollected (1000-0)
# METAL_2 #MetalCollected (10000-0)
# METAL_3 #MetalCollected (100000-0)
# LUMEN_1 #MetalCollected (500-0)
# LUMEN_2 #LumenCollected (5000-0)
# LUMEN_3 #LumenCollected (25000-0)
# LUMEN_4 #LumenCollected (100000-0)
# SHREDDER_1 #ShreddedItems (1-0)
# SHREDDER_2 #ShreddedItems (10-0)
# SHREDDER_3 #ShreddedItems (100-0)
# SHREDDER_4 #ShreddedItems (500-0)
# DEAD_BUGS_1 #KilledBugs (100-0)
# DEAD_BUGS_2 #KilledBugs (500-0)
# DEAD_BUGS_3 #KilledBugs (2500-0)
# DEAD_BUGS_4 #KilledBugs (10000-0)
# DEAD_BOSS_1 #KilledBosses (1-0)
# DEAD_BOSS_2 #KilledBosses (10-0)
# DEAD_BOSS_3 #KilledBosses (25-0)
# DEAD_BOSS_4 #KilledBosses (50-0)
# DIE_1 #Deaths (1-0)
# DIE_2 #Deaths (5-0)
# DIE_3 #Deaths (15-0)
# ORBS_10 #Orbs (10-0)
# ORDER_69 #Clones (69-0)
# LOSE_1
# KILL_FLARE
# KILL_FLARE_BOSS
# UPGRADE_SPEED_11
# DIE_GOLD_LAVA
# DIE_GATE_CRUSH
# MORE_PYLONS
# ST_JAVELIN
# CO_OP_2
# CO_OP_REVIVE
# LOSE_LAVA
# BOSS_RETURN_TO_SPAWN ----test---- ???
# DUAL_WIELD
# WIN_1
# WIN_2
# WIN_3
# GET_FLAMER
# GET_PISTOL
# GET_MACHINEGUN
# GET_SHOTGUN
# GET_SPEAR
# THE_CURE
# FIRE_LASER
# STORAGE_FULL
# POWER_OUTPOST
# UPGRADE_STATS_MAX
# UPGRADE_DRILL_MAX
# RICK_ROLL
# WIN_FAST
# UPS_1
# MONSTER_ON_NOMSTER
# HOME_MAKEOVER
# LOSE_BUILDINGS
# DONT_NEED_2_DRILLS
# UPGRADE_ALL_TURRETS
# RIP
# OCD
# BUG
# SHISHKEBAB

# SCIENCE_1 MaxResearch (0-2)
# SCIENCE_2 MaxResearch (0-12)
# SCIENCE_3 MaxResearch (0-24)
# SCIENCE_ALL Research all technologies


# require save informations
# WAVE_STAY_IN_BASE - test more
# WAVE_NO_ACTION - test more
# NINE_LIVES
# IM_BACK
# WIN_NO_GUNS
# WIN_NO_TURRETS

