extends Node

var singleton: Object
var APP_ID = 1713810

var achievements: Node

# singleton variables
var IS_OWNED: bool = false
var IS_ONLINE: bool = false
var IS_FREE_WEEKEND: bool = false
var STEAM_ID: int = 0
var STEAM_NAME: String = ""

var active: bool
var initialized: bool
var user_stats_received: bool = false
var global_stats_received: bool = false

var user_query: int
var leaderboard_handle: int
var workshop_handle: int = -1

var downloading_maps: int
var workshop_maps: Array
var vote_status_pending: Array
var favorited: Array

var overlay_pause: bool

var store_stats_timer: Timer
var multi_building_destroyed_timer: Timer

signal leaderboard_found
signal item_created(result, id)
signal map_downloaded(path)
signal map_unsubscribed(map)

signal requested_scores(scores)
signal workshop_loaded(items, cached)
signal download_started

signal publish_status(status)
signal need_tos

func _ready() -> void:
#	if not OS.has_feature("steam"):
	achievements = load("res://Scripts/System/Achievements.gd").new()
	
	if not Engine.has_singleton("Steam"):
		return
	
	singleton = Engine.get_singleton("Steam")
	if not OS.has_feature("steam") and Music.is_game_build():
		return
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if OS.has_feature("playtest"):
		APP_ID = 1906060
	
	store_stats_timer = Timer.new()
	store_stats_timer.one_shot = true
	add_child(store_stats_timer)
	multi_building_destroyed_timer = Timer.new()
	add_child(multi_building_destroyed_timer)
	multi_building_destroyed_timer.connect("timeout", Callable(achievements, "building_destroyed_reset"))
	
	var INIT: Dictionary = singleton.steamInit(false)
	if INIT['status'] != 1:
		print(str("[STEAM] Failed to initialize singleton. ", INIT.status, ": ", INIT.verbal))
	
	singleton.connect("leaderboard_find_result", Callable(self, "_on_leaderboard_find_result"))
	singleton.connect("leaderboard_scores_downloaded", Callable(self, "_on_leaderboard_scores_downloaded"))
	singleton.connect("item_created", Callable(self, "_on_item_created"))
	singleton.connect("item_updated", Callable(self, "_on_item_updated"))
	singleton.connect("item_downloaded", Callable(self, "_on_item_downloaded"))
	singleton.connect("ugc_query_completed", Callable(self, "_on_ugc_query_completed"))
	singleton.connect("get_item_vote_result", Callable(self, "_on_get_item_vote_result"))
	singleton.connect("overlay_toggled", Callable(self, "_on_overlay_toggled"))
	singleton.connect("user_stats_received", Callable(self, "_on_user_stats_received"))
	singleton.connect("global_stats_received", Callable(self, "_on_global_stats_received"))
	singleton.connect("current_stats_received", Callable(self, "_on_current_stats_received"))
	store_stats_timer.connect("timeout", Callable(self, "store_stats"))
#	singleton.connect("file_write_async_complete", self, "_on_file_write_async_complete")

	IS_ONLINE = singleton.loggedOn()
	STEAM_ID = singleton.getSteamID()
	STEAM_NAME = singleton.getPersonaName()
	IS_OWNED = singleton.isSubscribed()
	IS_FREE_WEEKEND = singleton.isSubscribedFromFreeWeekend()

	if IS_ONLINE:
		initialized = true
		print("[STEAM] Initialized successfully.")
	else:
#		initialized = OS.has_feature("editor")
		print("[STEAM] Started in offline mode. singleton features disabled.")

	if initialized:
		for item in singleton.getSubscribedItems():
			var state = singleton.getItemState(item)
			if not state & 1:
				continue

			if state & 8:
				prints("[STEAM] Updating workshop item:", item)
				downloading_maps += 1
				singleton.downloadItem(item, false)
			elif state & 4:
				prints("[STEAM] Found workshop item:", item)
				var info = singleton.getItemInstallInfo(item)
				workshop_maps.append({path = info.folder + "/map.lcmap", id = item})
				emit_signal("map_downloaded", workshop_maps.back())
			else:
				prints("[STEAM] Downloading workshop item:", item)
				downloading_maps += 1
				singleton.downloadItem(item, false)

		user_query = singleton.createQueryUserUGCRequest(STEAM_ID, 5, 2, 0, APP_ID, APP_ID, 1)
		singleton.sendQueryUGCRequest(user_query)
		singleton.setLeaderboardDetailsMax(2)

#	singleton.requestUserStats(SteamAPI.STEAM_ID) # does not require to be online
#	singleton.requestGlobalStats(30)
	active = true

func _process(_delta: float) -> void:
	if not active:
		return

	singleton.run_callbacks()

func _exit_tree():
	if not active:
		return
	
#	prints(">", singleton.getStatInt("LumenCollected"))
	singleton.storeStats()

func unlock_achievement(id: String, force := false):
	if not active:
		return
	
	if not can_achieve() and not force:
		return
	
#	prints("unl", id)
	if singleton.setAchievement(id):
		singleton.storeStats()

func store_stats():
	if not active:
		return
	
	singleton.storeStats()
	
func increment_stat(stat_name: String, value:int = 1):
	if not active or not can_achieve():
		return
#	prints("inc", stat_name, value)
	
	achievements.increment_stat(stat_name, value)
	if store_stats_timer.is_stopped():
		store_stats_timer.start(10.0)

func satisfy_achievement(achievement_name:String):
	if not active:
		return
	
	achievements.satisfy(achievement_name)
	
func try_achievement(achievement_name:String):
	if not active or not can_achieve():
		return
	
	achievements.try(achievement_name)

func fail_achievement(achievement_name:String):
	if not active:
		return
	
	achievements.fail(achievement_name)

func can_achieve() -> bool:
	return not Save.cheated and Save.data and Save.data.achievements_enabled

func update_average_stat(stat_name: String, value:int, length:float = 1.0/60.0):
	if not active or not can_achieve():
		return
	achievements.update_average_stat(stat_name, value, length)

func store_score(leaderboard: String, score: int, time: int, completed: bool):
	if not active:
		return
	
	singleton.findOrCreateLeaderboard(leaderboard, 2, 1)
	await self.leaderboard_found
	singleton.uploadLeaderboardScore(score, true, [time, int(completed)], leaderboard_handle)
	
	if completed:
		singleton.findOrCreateLeaderboard(leaderboard + "/speedrun", 1, 1)
		await self.leaderboard_found
		singleton.uploadLeaderboardScore(time, true, [score, int(completed)], leaderboard_handle)

func load_leaderboard(leaderboard: String, start: int, mode: int, score_count: int):
	if not active:
		return
	
	singleton.findOrCreateLeaderboard(leaderboard, 1 if leaderboard.ends_with("/speedrun") else 2, 1)
	await self.leaderboard_found
	
	if mode == 1:
		singleton.downloadLeaderboardEntries(start - score_count / 2, start + score_count / 2, mode, leaderboard_handle)
	else:
		singleton.downloadLeaderboardEntries(start, start + score_count, mode, leaderboard_handle)

func get_nick(user: int) -> String:
	if not active:
		return ""
	
	var nickname: String = singleton.getPlayerNickname(user)
	if not nickname:
		nickname = singleton.getFriendPersonaName(user)
	
	return nickname

func get_avatar(user: int):
	if not active:
		return
	
	singleton.getPlayerAvatar(1, user) 

func create_map():
	if not active:
		return
	
	singleton.createItem(APP_ID, 0)

func publish_map(workshop_id: int, map_name: String, map_description: String, update_note: String, preview: String, tags: PackedStringArray, metadata: String):
	if not active:
		return
	
	var update_handle = singleton.startItemUpdate(APP_ID, workshop_id)
	singleton.setItemTitle(update_handle, map_name)
	singleton.setItemDescription(update_handle, map_description)
	singleton.setItemContent(update_handle, ProjectSettings.globalize_path("user://workshop/published_map"))
	singleton.setItemPreview(update_handle, preview)
	singleton.setItemVisibility(update_handle, 0)
	singleton.setItemMetadata(update_handle, metadata)
	singleton.setItemTags(update_handle, tags)
	singleton.submitItemUpdate(update_handle, update_note)

func load_workshop(sort: int, page: int, search: String, tags: Array):
	## TODO: podobno to ma być zwalniane
	var handle = singleton.createQueryAllUGCRequest(sort, 2, APP_ID, APP_ID, page)
	singleton.setSearchText(handle, search)
	for tag in tags:
		singleton.addRequiredTag(handle, tag)
	singleton.setMatchAnyTag(handle, false)
	singleton.setReturnLongDescription(handle, true)
	singleton.setReturnKeyValueTags(handle, true)
	singleton.setReturnMetadata(handle, true)
	singleton.sendQueryUGCRequest(handle)

func unsubscribe_map(id: int):
	singleton.unsubscribeItem(id)
	emit_signal("map_unsubscribed", id)

func subscribe_map(id: int):
	singleton.subscribeItem(id)
	downloading_maps += 1
	emit_signal("download_started")
	singleton.downloadItem(id, false)

func get_vote_status(item: int): ## wywalane
	vote_status_pending.append(item)
	if vote_status_pending.size() > 1:
		return
	
	singleton.getUserItemVote(item)

func _on_leaderboard_find_result(handle: int, result: int):
	leaderboard_handle = handle
	emit_signal("leaderboard_found")

func _on_leaderboard_scores_downloaded(message: String, scores: Array):
	emit_signal("requested_scores", scores)

func _on_item_created(result: int, file_id: int, tos: bool):
	if tos:
		emit_signal("need_tos")
	
	emit_signal("item_created", result, file_id)

func _on_item_updated(result: int, tos: bool):
	if tos:
		emit_signal("need_tos")
	emit_signal("publish_status", result)

func _on_item_downloaded(result: int, file_id: int, app_id: int):
	if result == 1:
		downloading_maps -= 1
		var item_data: Dictionary = singleton.getItemInstallInfo(file_id)
		workshop_maps.append({path = item_data.folder + "/map.lcmap", id = file_id})
		emit_signal("map_downloaded", workshop_maps.back())
	else:
		print("[STEAM] Workshop download error: ", result, "(item ", file_id, ")")

func _on_ugc_query_completed(handle: int, result: int, total_returned: int, total_matching: int, cached: bool):
	if result == 1:
		if handle == user_query:
			for i in total_returned:
				var data = singleton.getQueryUGCResult(handle, i)
				favorited.append(data.file_id)
			
			singleton.releaseQueryUGCRequest(handle)
			user_query = -1
			return
		
		workshop_handle = handle
		emit_signal("workshop_loaded", total_returned, cached)
	elif result == 2: # nie wiem co to, ale chyba działa
		workshop_handle = handle
		emit_signal("workshop_loaded", 0, true)
	else:
		print("[STEAM] Workshop query error: ", result)

func _on_get_item_vote_result(result: int, file_id: int, up: bool, down: bool, none: bool):
	if result == 1:
		vote_status_pending.erase(file_id)
	
	if not vote_status_pending.is_empty():
		singleton.getUserItemVote(vote_status_pending.front())

func _on_user_stats_received(game_id: int, result: int, user_id: int):
#	print("[STEAM] User stats gooood: ", result)
	if result == 1:
		user_stats_received = true
		achievements.get_user_stats()
	else:
		print("[STEAM] Request user stats error: ", result)

func _on_global_stats_received(game_id: int, result: String):
#	print("[STEAM] Global stats gooood: ", result)
	if result == "ok":
		global_stats_received = true
		achievements.get_global_stats()
	else:
		print("[STEAM] Request global stats error: ", result)
		
func _on_current_stats_received(game_id: int, result: int, user_id: int):
#	print("[STEAM] Request current stats gooood: ", result)
	if result == 1:
#		print("request_global_stats")
		singleton.requestGlobalStats(30) # does not require to be online
	else:
		print("[STEAM] Request current stats error: ", result)

func request_stats():
	user_stats_received = false
	global_stats_received = false
#	print("request_stats")
#	singleton.requestCurrentStats()
#	print("request_user_stats")
	singleton.requestUserStats(SteamAPI.STEAM_ID) # does not require to be online

func release_workshop_handle():
	singleton.releaseQueryUGCRequest(workshop_handle)
	workshop_handle = -1

static var GIF_BYTES = PackedByteArray([71, 73, 70])
static var PNG_BYTES = PackedByteArray([137, 80, 78, 71])
static var JPG_BYTES = PackedByteArray([255, 216, 255, 224])
static var JPG_BYTES2 = PackedByteArray([255, 216, 255, 225])

func load_preview_image(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		var dir = DirAccess.open(path.get_base_dir())
		dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
		
		var file := dir.get_next()
		while not file.is_empty():
			if file.begins_with(path.get_file()):
				path = str(path.get_base_dir(), "/", file)
				break
			
			file = dir.get_next()
	
	var old_path := path
	if path.get_extension().is_empty():
		var file = FileAccess.open(path, FileAccess.READ)
		var bytes := file.get_buffer(file.get_length())
		
		var bytes3 = bytes.slice(0, 2)
		if bytes3 == GIF_BYTES:
			path += ".gif"
		else:
			var bytes4 = bytes.slice(0, 3)
			if bytes4 == PNG_BYTES:
				path += ".png"
			if bytes4 == JPG_BYTES or bytes4 == JPG_BYTES2:
				path += ".jpg"
	
	if path != old_path:
		pass
		#dir.rename(old_path, path)
	
	match path.get_extension():
		"png", "jpg":
			var image := Image.new()
			image.load(path)
			var texture = ImageTexture.create_from_image(image)
			return texture
		
	#	"gif":
	#		var image := Image.new()
	#		image.load(path)
	#		
	#		var texture := AnimatedTexture.new()
	#		texture.frames = image.get_frame_count()
	#		texture.fps = 30
	#		
	#		for i in image.get_frame_count():
	#			var frame := image.get_frame_image(i)
	#			var frame_tex := ImageTexture.new()
	#			frame_tex.create_from_image(frame)
	#			
	#			texture.set_frame_texture(i, frame_tex)
	#			texture.set_frame_delay(i, image.get_frame_delay(i))
			
			return texture
	
	return null

func _on_overlay_toggled(toggle: bool):
	if toggle:
		overlay_pause = not get_tree().paused
		get_tree().paused = true
	else:
		if overlay_pause:
			get_tree().paused = false

func save_files(files: Array):
	if not active:
		return
	
#	singleton.beginFileWriteBatch()
	
	for file in files:
		print("[singleton] Cloud saving: ", file)
		var f := File.new()
		f.open(file, f.READ)
		var data := f.get_buffer(f.get_length())
		print(singleton.fileWrite(ProjectSettings.globalize_path(file), data))
#		singleton.fileWriteAsync(file, data)
	
#	singleton.endFileWriteBatch()

func _on_file_write_async_complete(result):
	print("[singleton] Cloud saved: ", result)

func query_item_tags(item: int, callback: Callable):
	var tags: PackedStringArray
	if not active:
		return tags
	
	var handle = singleton.createQueryUGCDetailsRequest([item])
	singleton.sendQueryUGCRequest(handle)
	await singleton.ugc_query_completed
	for i in singleton.getQueryUGCNumTags(handle, 0):
		tags.append(singleton.getQueryUGCTagDisplayName(handle, 0, i))
	singleton.releaseQueryUGCRequest(handle)
	
	callback.call(tags)
