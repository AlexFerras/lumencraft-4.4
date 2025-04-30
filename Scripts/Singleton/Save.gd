extends Node

var debug: bool
var is_saving: bool

const CONFIG_PATH = "user://config.tres"
const PLAYER_DATA_PATH = "user://Saves/player_data.tres"

var config: Config
var player_data: PlayerData

var campaign: CampaignData

var save_name: String
var story_mode: bool
var block_save: Array

var data: SaveData
var current_map: String
var start_point := -1
var game_time: int
var cheated: bool: set = set_cheated

var scoreboard: Dictionary
var sandbox_options: Dictionary

var score: int
var clones: int = 0

signal new_gamed ## debug w sumie
signal tech_unlocked(tech)
signal unclocked_tech_number(tech, num)
signal score_updated
signal saved

var map_completed: bool

func _ready() -> void:
	var dir = DirAccess.open("user://")
	dir.make_dir("Saves")
	debug = not Music.is_game_build()
	
	load_config()
	
	if ResourceLoader.exists(PLAYER_DATA_PATH):
		player_data = load(PLAYER_DATA_PATH)
		if not player_data: # compat:
			Utils.fix_broken_script(PLAYER_DATA_PATH, '[ext_resource path="res://Scripts/Data/PlayerData.gd" type="Script" id=1]')
			player_data = load(PLAYER_DATA_PATH)
		
		if not player_data:
			player_data = PlayerData.new()
	elif ResourceLoader.exists("user://player_data.tres"): # compat
		dir = DirAccess.open("user://")
		dir.copy("player_data.tres", PLAYER_DATA_PATH)
		
		player_data = load(PLAYER_DATA_PATH)
		if not player_data:
			Utils.fix_broken_script(PLAYER_DATA_PATH, '[ext_resource path="res://Scripts/Data/PlayerData.gd" type="Script" id=1]')
			player_data = load(PLAYER_DATA_PATH)
		
		if not player_data:
			player_data = PlayerData.new()
	else:
		player_data = PlayerData.new()
		player_data.take_over_path(PLAYER_DATA_PATH)
	
	var timer := Timer.new()
	timer.autostart = true
	timer.connect("timeout", Callable(self, "count_1"))
	add_child(timer)

func count_1():
	if not Utils.game:
		return
	
	game_time += 1
	count_score("time", 1)

func new_game():
	data = SaveData.new()
	data.player_data.resize(Const.PLAYER_LIMIT)
	data.save_uid = randi()
	game_time = 0
	map_completed = false
	scoreboard.clear()
	sandbox_options = {}
	current_map = ""
	clones = 0
	score = 0
	cheated = false
	block_save.clear()
	campaign = null
	emit_signal("new_gamed")

func save_game(slot: String, silent := false):
	if not silent:
		Utils.game.ui.menu.toggle(true)
	
	is_saving = true
	var p = get_tree().paused
	get_tree().paused = true
	var saving = preload("res://Nodes/UI/Saving.tscn").instantiate()
	add_child(saving)
	
#	Utils.start_time_tracking("saving")
	data.timestamp = Time.get_unix_time_from_system() + Time.get_time_zone_from_system().bias * 60
	data.game_time = game_time
	data.slot_name = get_current_map_name()
	data.game_version = int(preload("res://Tools/version.gd").VERSION)
	data.campaign = campaign != null
#	Utils.print_time_tracking_checkpoint("saving", "data")
	
	if data.slot_name.is_empty():
		data.slot_name = current_map.get_file().get_basename()
	
	BuildInterface.unred()
	var map_save = preload("res://Scripts/Data/SaveFile.gd").new()
#	Utils.push_time_tracking_checkpoint("saving")
#	map_save.store_map(Utils.game.map)
	var worker = preload("res://Scripts/ThreadedWorker.gd").create(map_save, "store_map", Utils.game.map)
	await worker.tree_exited
#	Utils.print_time_tracking_checkpoint("saving", "store map")
	
	for i in Const.PLAYER_LIMIT:
		if i < Utils.game.players.size():
			data.player_data[i] = Utils.game.players[i]._get_save_data()
	
#	Utils.push_time_tracking_checkpoint("saving")
	var dir:DirAccess = Utils.safe_open(Utils.DIR, get_save_dir(slot))
	if dir:
		dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
		var f := dir.get_next()
		while not f.is_empty():
			if f.get_extension() == "lcsave":
				if f == get_map_file(slot, current_map).get_file():
					if dir.file_exists(f):
						dir.rename(f, f + ".bak")
				else:
					dir.remove(f)
			elif f.get_extension() == "bak":
				if f == get_map_file(slot, current_map).get_file() + ".bak":
					pass
				else:
					dir.remove(f)
			elif f == "campaign_progress.tres" and not data.campaign:
				dir.remove(f)
			
			f = dir.get_next()
#	Utils.print_time_tracking_checkpoint("saving", "dir shenaningans")
	
	data.take_over_path(get_save_file(slot))
	
#	Utils.push_time_tracking_checkpoint("saving")
	data.current_map = current_map
	DirAccess.open("user://").make_dir_recursive(get_save_dir(slot))
	ResourceSaver.save(data, get_save_file(slot), ResourceSaver.FLAG_CHANGE_PATH)
#	Utils.print_time_tracking_checkpoint("saving", "save data")
	worker = preload("res://Scripts/ThreadedWorker.gd").create(map_save, "save_to_file", get_map_file(slot, current_map))
	await worker.tree_exited
#	Utils.print_time_tracking_checkpoint("saving", "save map")
	
	if campaign:
		ResourceSaver.save(campaign, get_campaign_file(slot), ResourceSaver.FLAG_CHANGE_PATH)
	
	saving.queue_free()
	get_tree().paused = p
	is_saving = false
	emit_signal("saved")

func get_current_map_name() -> String:
	if Save.campaign:
		if Save.campaign.current_map.is_empty():
			return tr("Hub")
		else:
			return tr(Const.CampaignLevels[Save.campaign.current_map].level_name)
	elif current_map.get_extension() == "lcmap":
		var map_file := MapFile.new()
		map_file.load_metadata(current_map)
		return tr(map_file.map_name)
	else:
		return tr(Const.MapNames.get(current_map.get_file().get_basename(), ""))

func autosave():
	save_game("Autosave_story")

func load_game(slot: String):
	data = null
	new_game()
	
	data = load(get_save_file(slot))
	
	if data.game_version < 6470: # compat
		for player in data.player_data:
			if not player: # co
				continue
			
			for item in player.inventory:
				item.id = SaveData.CompatIDs.keys()[item.id]
	
	game_time = data.game_time
	
	if Utils.game:
		Utils.game.queue_free()
		await Utils.game.tree_exited
	
	if has_meta("force_map"):
		data.current_map = get_meta("force_map")
		remove_meta("force_map")
	
	Utils.log_message("Save game version: %s" % data.game_version)
	
	if data.campaign:
		campaign = load(get_campaign_file(slot))
		if data.current_map == "res://Maps/Campaign/Hub.tscn":
			Game.start_map("res://Maps/Campaign/Hub.tscn")
			return
	
	Game.start_map(get_map_file(slot, data.current_map))

func get_save_dir(slot: String) -> String:
	return str("user://Saves/", slot)

func get_save_file(slot: String) -> String:
	return str(get_save_dir(slot), "/data.tres")

func get_map_file(slot: String, map: String) -> String:
	return str(get_save_dir(slot), "/", map.get_file().get_basename(), ".lcsave") ## TODO: naprawić konflikty jak ta sama nazwa.

func get_campaign_file(slot: String) -> String:
	return str(get_save_dir(slot), "/campaign_progress.tres")

func get_slot_string(slot: String) -> Array:
	var string := slot.trim_suffix("_story")
	
	var timestamp: int
	var version: int
	if ResourceLoader.exists(get_save_file(slot)):
		var save_data: SaveData = load(Save.get_save_file(slot))
		if not save_data: # compat
			Utils.fix_broken_script(Save.get_save_file(slot), '[ext_resource path="res://Scripts/Data/SaveData.gd" type="Script" id=1]')
			save_data = load(Save.get_save_file(slot))
		timestamp = save_data.timestamp
		version = save_data.game_version
		var time := Time.get_datetime_dict_from_unix_time(timestamp)
		string += " [color=#%s]%02d/%02d/%02d %02d:%02d[/color] %s" % [Const.UI_SECONDARY_COLOR.to_html(false), int(str(time.year).substr(2)), time.month, time.day, time.hour, time.minute, save_data.slot_name]
	
	return [string, timestamp, version]

func get_story_slot(slot: String, story: bool):
	return str(slot , "_story" if story else "")

func get_unclocked_tech(s :String) -> int:
	return data.unlocked_tech_number.get(s, 0)

func set_unlocked_tech(s: String, num: int):
	if SteamAPI.can_achieve():
		if check_tech_max_level(Const.ItemIDs.DRILL):
			SteamAPI.unlock_achievement("UPGRADE_DRILL_MAX")
		if Utils.game.main_player.get_item_count(Const.ItemIDs.MAGNUM) > 0:
			if check_tech_max_level(Const.ItemIDs.MAGNUM):
				SteamAPI.unlock_achievement("UPGRADE_PISTOL_MAX")
		if Utils.game.main_player.get_item_count(Const.ItemIDs.SPEAR) > 0:
			if Save.check_tech_max_level(Const.ItemIDs.SPEAR):
				SteamAPI.unlock_achievement("UPGRADE_SPEAR_MAX")
		if Utils.game.main_player.get_item_count(Const.ItemIDs.MACHINE_GUN) > 0:
			if Save.check_tech_max_level(Const.ItemIDs.MACHINE_GUN):
				SteamAPI.unlock_achievement("UPGRADE_MACHINEGUN_MAX")
		if Utils.game.main_player.get_item_count(Const.ItemIDs.SHOTGUN) > 0:
			if Save.check_tech_max_level(Const.ItemIDs.SHOTGUN):
				SteamAPI.unlock_achievement("UPGRADE_SHOTGUN_MAX")
		if Utils.game.main_player.get_item_count(Const.ItemIDs.FLAMETHROWER) > 0:
			if Save.check_tech_max_level(Const.ItemIDs.FLAMETHROWER):
				SteamAPI.unlock_achievement("UPGRADE_FLAMER_MAX")

#	if s.ends_with("drilling_power"):
#		if num >= 5:
#			SteamAPI.unlock_achievement("UPGRADE_DRILL_MAX")
	data.unlocked_tech_number[s] = num
	emit_signal("unclocked_tech_number", s, num)

func check_tech_max_level(id):
	var all_upgraded = true
	for upgrade in Const.Items[id].upgrades:
		if Save.get_unclocked_tech(str(id, upgrade.name)) < upgrade.costs.size():
			all_upgraded = false
			break
	return all_upgraded

#	for id in Const.game_data.upgradable_weapons:
#		for upgrade in Const.Items[id].upgrades:
#			if Save.get_unclocked_tech(str(id, upgrade)) < Const.Items[id].upgrades[upgrade].costs.size():
#				all_upgraded = false
#				break
#
#		if not all_upgraded:
#			break

func unlock_tech(tech: String):
	if not tech in data.unlocked_tech:
		data.unlocked_tech[tech] = true
		count_score("tech_researched")
		emit_signal("tech_unlocked", tech)

func is_tech_unlocked(tech: String) -> bool:
	if not data:
		return true
	return tech in data.unlocked_tech

func is_tech_requirements_unlocked(tech: String) -> bool:
	for dep in Const.Technology[tech].get("depend", []):
		if not is_tech_unlocked(dep):
			return false
	return true

func get_unlocked_tech_list() -> Array:
	return data.unlocked_tech.keys()

func load_config():
	config = null
	
	if ResourceLoader.exists(CONFIG_PATH):
		config = load(CONFIG_PATH) as Config
		if not config: # compat
			Utils.fix_broken_script(CONFIG_PATH, '[ext_resource path="res://Scripts/Data/ControlsRemap.gd" type="Script" id=1]')
			Utils.fix_broken_script(CONFIG_PATH, '[ext_resource path="res://Scripts/Data/Config.gd" type="Script" id=2]', 3)
			config = load(CONFIG_PATH) as Config
	
	if not config:
		config = Config.new()
		
		if Music.is_switch_build():
			config.glow_high_quality = false
			config.glow_intensity = 0.0
			config.glow_strength = 0.8
			config.glow_type = 1
			config.light_downsample = 1
			config.shadow_render_steps = 2
			config.joypad_vibrations = 0
			config.single_player_controls = Config.CONTROL_JOYPAD
			config.screenmode = Config.FULLSCREEN
			config.fullscreen_resolution = Vector2(1280, 720)
			
			config.controls2.set_action_button("build", Utils.button_event(JOY_BUTTON_A))
			config.controls2.set_action_button("interact", Utils.button_event(JOY_BUTTON_B))
			config.controls2.create_remap()
			
			config.controls3.set_action_button("build", Utils.button_event(JOY_BUTTON_A))
			config.controls3.set_action_button("interact", Utils.button_event(JOY_BUTTON_B))
			config.controls3.create_remap()
	
	if Const.get_override("TEST_SWITCH"):
			config.controls2.set_action_button("build", Utils.button_event(JOY_BUTTON_A))
			config.controls2.set_action_button("interact", Utils.button_event(JOY_BUTTON_B))
			config.controls2.create_remap()
			
			config.controls3.set_action_button("build", Utils.button_event(JOY_BUTTON_A))
			config.controls3.set_action_button("interact", Utils.button_event(JOY_BUTTON_B))
			config.controls3.create_remap()
	
	if config.prev_version < int(preload("res://Tools/version.gd").VERSION):
		if config.prev_version < 9000:
			config = Config.new()
		
		config.prev_version = int(preload("res://Tools/version.gd").VERSION)
		save_config()
	config.shadow_render_steps = clamp(config.shadow_render_steps,2,10)
	
	if Array(OS.get_cmdline_args()).has("windowed"):
		config.is_fullscreen=false
		config.resolution=Vector2(1280,720)
	config.apply()

func save_config():
	ResourceSaver.save(config, CONFIG_PATH)

func count_score(field: String, inc := 1):
	scoreboard[field] = scoreboard.get(field, 0) + inc
	score += Utils.game.map.scoring_rules.get(field, 0) * inc
	emit_signal("score_updated")

func do_event(event: String) -> bool:
	if event in data.events:
		return false
	data.events.append(event)
	return true

func is_event_done(event: String) -> bool:
	return event in data.events

func get_properties(object: Object, properties: Array) -> Dictionary:
	var dict: Dictionary
	for property in properties:
		dict[property] = object.get(property)
	return dict

func set_properties(object: Object, properties: Dictionary):
	for property in properties:
		if not property.begins_with("_"):
			object.set(property, properties[property])

func block_save_by(by: String):
	if not by in block_save:
		block_save.append(by)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.keycode == KEY_R and event.command and event.shift:
		reset_config()

func reset_config():
	config = Config.new()
	config.apply()

func _get_save_data() -> Dictionary:
	return get_properties(self, ["start_point", "game_time", "cheated", "scoreboard", "sandbox_options", "clones", "score", "map_completed"])

func _set_save_data(d: Dictionary):
	set_properties(self, d)

func campaign_cleanup():
	var camp := campaign
	new_game()
	campaign = camp

func is_hub() -> bool:
	return current_map == "res://Maps/Campaign/Hub.tscn"

func set_cheated(c):
	cheated = c
	Utils.game.ui.get_node("%CanAchieve").update_status()
