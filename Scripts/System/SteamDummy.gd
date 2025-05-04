extends Node

var singleton: Object = null
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


func unlock_achievement(id: String, force := false):
	pass

func store_stats():
	pass

func increment_stat(stat_name: String, value:int = 1):
	pass

func satisfy_achievement(achievement_name:String):
	pass

func try_achievement(achievement_name:String):
	pass

func fail_achievement(achievement_name:String):
	pass

func can_achieve() -> bool:
	return false

func update_average_stat(stat_name: String, value:int, length:float = 1.0/60.0):
	pass

func store_score(leaderboard: String, score: int, time: int, completed: bool):
	pass

func load_leaderboard(leaderboard: String, start: int, mode: int, score_count: int):
	pass

func get_nick(user: int) -> String:
	return "BadNickname"

func get_avatar(user: int):
	pass

func create_map():
	pass

func publish_map(workshop_id: int, map_name: String, map_description: String, update_note: String, preview: String, tags: PackedStringArray, metadata: String):
	pass

func load_workshop(sort: int, page: int, search: String, tags: Array):
	pass

func unsubscribe_map(id: int):
	pass

func subscribe_map(id: int):
	pass

func get_vote_status(item: int): ## wywalane
	pass

func _on_leaderboard_find_result(handle: int, result: int):
	pass

func _on_leaderboard_scores_downloaded(message: String, scores: Array):
	pass

func _on_item_created(result: int, file_id: int, tos: bool):
	pass

func _on_item_downloaded(result: int, file_id: int, app_id: int):
	pass

func _on_ugc_query_completed(handle: int, result: int, total_returned: int, total_matching: int, cached: bool):
	pass

func _on_get_item_vote_result(result: int, file_id: int, up: bool, down: bool, none: bool):
	pass

func _on_user_stats_received(game_id: int, result: int, user_id: int):
	pass

func request_stats():
	pass

func release_workshop_handle():
	pass

func load_preview_image(path: String) -> Texture2D:
	return null

func save_files(files: Array):
	pass

func query_item_tags(item: int, callback: Callable):
	pass
