extends Camera2D
class_name GameCamera

@onready var previous_mouse_position = get_global_mouse_position()
@onready var previous_position = global_position
@onready var target_position = global_position
@onready var target_zoom = Vector2(1.0, 1.0)
@onready var additional_zoom = 0.0
#onready var debug = $"../CanvasLayer/Debug"

const zoom_levels = [0.0625, 0.0833333, 0.125, 0.1875 ,0.25, 0.375, 0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4]
var current_zoom_index = 0
var LMB_pressed = false
var MMB_pressed = false
var RMB_pressed = false

var target: Node2D
var player: Player
var is_camera_following := false
var selected_node: Node2D

func _ready():
	target_zoom = Vector2.ONE * zoom_levels[current_zoom_index]
	zoom = target_zoom
	set_process_input(false)
	add_to_group("config_observers")

func set_target(new_target: Node2D):
	set_camera_following(true)
	target = new_target

func toggle_camera_following():
	is_camera_following = not is_camera_following
	
func set_camera_following(value: bool):
	is_camera_following = value

func _physics_process(delta: float):
	if not is_instance_valid(target):
		set_camera_following(false)
		return
	
	if not target.is_inside_tree():
		return
		
	if is_camera_following:
		target_position = target.global_position
	
	global_position = lerp(global_position, target_position, 20 * delta)
#	global_position = target_position
	var az=target.get("additional_zoom")
	if !az:
		az=0.0
	zoom = lerp(zoom, target_zoom+az*Vector2.ONE, 2 * delta)
	Utils.game.update_screen_diagonal()

func _input(event):
	if event is InputEventMouseMotion:
		if MMB_pressed:
			target_position = previous_position + previous_mouse_position - get_local_mouse_position()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			drag(event)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN: # zoom camera
			zoom_camera(event)

func drag( event ):
	if event.pressed: 
		MMB_pressed = true
		previous_mouse_position = get_local_mouse_position()
		previous_position = global_position
	else:
		MMB_pressed = false

func zoom_camera( event ):
	if abs(zoom_levels[current_zoom_index] - zoom.x) < 0.1 * target_zoom.x:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and current_zoom_index > 0:
			current_zoom_index -= 1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and current_zoom_index < zoom_levels.size()-1:
			current_zoom_index += 1
		target_zoom = Vector2.ONE * zoom_levels[current_zoom_index]
	Utils.game.update_screen_diagonal()

func force_update():
	if target:
		global_position = target.global_position
		force_update_scroll()

func update_config():
	if target_zoom.is_equal_approx(Vector2.ONE / 8) or target_zoom.is_equal_approx(Vector2.ONE / 10):
		target_zoom = Vector2.ONE / Const.CAMERA_ZOOM
