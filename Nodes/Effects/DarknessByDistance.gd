extends Node2D

@export var gradient: Gradient
@export var min_distance: float = 50.0
@export var max_distance: float = 350.0

@export var lava_gradient: Gradient
@export var lava_detection_rect=Vector2(400,200)

var darkness: Node
var distance_from_light:float
var original_color: Color

func _ready() -> void:
	if Utils.game.map.has_node("PixelMap/DarknessByDistance") and Utils.game.map.get_node("PixelMap/DarknessByDistance") != self:
		queue_free()
		push_error("DBD already exist, suiciding")
		return
	
	if not visible:
		set_physics_process(false)
		return
#	max_distance = max(max_distance-min_distance, 1.0)
	if not gradient:
		print_debug("no darkness gradient availible")
		set_physics_process(false)
		return
		
	if Utils.game.map.darkness:
		fetch_darkness()
	Utils.game.connect("map_changed", Callable(self, "fetch_darkness"))

func fetch_darkness():
	if not Utils.game.map.darkness or not Utils.game.map.darkness.ambient:
		return
	
	darkness = Utils.game.map.darkness.ambient
	original_color = darkness.color

func _physics_process(delta: float) -> void:
	if not (Utils.game.frame_from_start % 60):
		update_distance_from_light()
	update_darkness()
	
func update_distance_from_light():
	var closest_light := INF
	var distance := 0.0
	var closest_position := Vector2.ZERO
	for building in get_tree().get_nodes_in_group("Light3D"):
#		prints("building", building.name)
		if building.is_running:
			if is_nan(Utils.game.camera.get_camera_screen_center().y):
				return
			distance = (building.global_position - Utils.game.camera.get_camera_screen_center()).length_squared()
			if distance < closest_light:
				closest_light = distance
				closest_position = building.global_position
	distance_from_light = (closest_position - Utils.game.main_player.global_position).length()
#	prints("updating", distance_from_light)
	if distance_from_light > min_distance:
		Utils.game.near_base = true
	else:
		Utils.game.near_base = false
		SteamAPI.fail_achievement("WAVE_STAY_IN_BASE")
		
	distance_from_light = 1.0 - clamp(distance_from_light - min_distance, 0, max_distance) / max_distance
#	prints("distance_from_light", distance_from_light, "min  ", min_distance)

func update_darkness():
	if darkness:
		if is_nan(Utils.game.camera.get_camera_screen_center().y):
			return
		var center=Utils.game.camera.get_camera_screen_center()
		var lava_count=Utils.game.map.pixel_map.count_material_occurrences_rect(Const.Materials.LAVA, Rect2(center-lava_detection_rect*0.5, lava_detection_rect), 10, false)
		var max_lava=lava_detection_rect.x*lava_detection_rect.y
		$lava_audio.volume_db=linear_to_db(min(20.0*lava_count/max_lava,1.0))
		var lava_ambient=lava_gradient.sample(lava_count/max_lava)
		lava_ambient.a=0.0
		darkness.color = darkness.color.lerp(gradient.sample(distance_from_light)+lava_ambient, 0.01)

func _get_save_data() -> Dictionary:
	return Save.get_properties(self, ["visible", "gradient", "min_distance", "max_distance", "lava_gradient", "lava_detection_rect"])

func _set_save_data(data: Dictionary):
	Save.set_properties(self, data)
