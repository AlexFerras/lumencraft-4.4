@tool
extends EditorScript

var actions = ["up", "down", "left", "right", "look_up", "look_down", "look_left", "look_right", "run",
	"shoot", "shoot2", "throw_item", "build", "next_slot", "prev_slot", "interact", "cancel",
	"menu", "inventory", "map", "auto_walk", "slot1", "slot2", "slot3", "slot4", "modifier", "next_row", "prev_row",
	"respawn"
]

var keyboard = {
	up = KEY_W,
	down = KEY_S,
	left = KEY_A,
	right = KEY_D,
	run = KEY_SHIFT,
	throw_item = KEY_F,
	build = KEY_B,
	next_slot = KEY_E,
	prev_slot = KEY_Q,
	interact = KEY_SPACE,
	cancel = KEY_ESCAPE,
	menu = KEY_ESCAPE,
	inventory = KEY_TAB,
	map = KEY_M,
	auto_walk = KEY_NUMLOCK,
	slot1 = KEY_1,
	slot2 = KEY_2,
	slot3 = KEY_3,
	slot4 = KEY_4,
	modifier = KEY_CTRL,
	respawn = KEY_R,
}

var mouse = {
	shoot = MOUSE_BUTTON_LEFT,
	shoot2 = MOUSE_BUTTON_RIGHT,
	next_slot = MOUSE_BUTTON_WHEEL_DOWN,
	prev_slot = MOUSE_BUTTON_WHEEL_UP,
}

# 0A 1B 2X 3Y 4L1 5R1 6L2 7R2 8L3, 9R3, 10Select 11Start 12DUp 13DDown 14DLeft 15DRight
# TODO
var joypad = {
	run = JOY_BUTTON_GUIDE,
	#shoot = JOY_AXIS_R2,
	#shoot2 = JOY_L2,
	throw_item = JOY_BUTTON_Y,
	build = JOY_BUTTON_B,
	#next_slot = JOY_BUTTON_B5,
	#prev_slot = JOY_BUTTON_B4,
	interact = JOY_BUTTON_A,
	cancel = JOY_BUTTON_B,
	#menu = JOY_BUTTON_B1,
	inventory = JOY_BUTTON_X,
	#map = JOY_BUTTON_B0,
	auto_walk = JOY_BUTTON_Y,
	#slot1 = JOY_BUTTON_B2,
	#slot2 = JOY_BUTTON_B5,
	#slot3 = JOY_BUTTON_B3,
	#slot4 = JOY_BUTTON_B4,
	modifier = JOY_BUTTON_BACK,
	#next_row = JOY_BUTTON_B3,
	#prev_row = JOY_BUTTON_B2,
	respawn = JOY_BUTTON_X,
}
# TODO
var joypad_axis = {
	#up = -(JOY_AXIS_1 + 1),
	#down = (JOY_AXIS_1 + 1),
	#left = -(JOY_AXIS_0 + 1),
	#right = (JOY_AXIS_0 + 1),
	#look_up = -(JOY_AXIS_3 + 1),
	#look_down = (JOY_AXIS_3 + 1),
	#look_left = -(JOY_AXIS_2 + 1),
	#look_right = (JOY_AXIS_2 + 1),
}

var players = {
	p1 = [keyboard, mouse, joypad, joypad_axis],
	p2 = [keyboard, mouse],
	p3 = [joypad, joypad_axis],
	p4 = [joypad, joypad_axis],
	p5 = [joypad, joypad_axis],
	p6 = [joypad, joypad_axis],
}

var devices = {
	p1 = -1,
	p2 = -1,
	p3 = 0,
	p4 = 1,
	p5 = 2,
	p6 = 3,
}

func _run() -> void:
	for player in players:
		for action in actions:
			var events: Array
			
			for list in players[player]:
				if not action in list:
					continue
				
				match list:
					keyboard:
						events.append(create_key_event(devices[player], list[action]))
					mouse:
						events.append(create_mouse_event(devices[player], list[action]))
					joypad:
						events.append(create_joypad_event(devices[player], list[action]))
					joypad_axis:
						events.append(create_joypad_axis_event(devices[player], list[action]))
			
			ProjectSettings.set_setting(str("input/", player, "_", action), {deadzone = 0.5, events = events})
	
	ProjectSettings.save()

func create_key_event(device: int, keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.device = device
	return event

func create_mouse_event(device: int, button_index: int) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.device = device
	return event

func create_joypad_event(device: int, button_index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.device = device
	return event

func create_joypad_axis_event(device: int, axis: int) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = abs(axis) - 1
	event.axis_value = sign(axis)
	event.device = device
	return event
