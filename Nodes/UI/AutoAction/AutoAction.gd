extends TextureRect

const CUSTOM_ACTIONS = {
	"move": "WSAD||LeftStick",
	"look": "|None|RightStick",
	"full_switch": "|WheelVertical|",
}

enum {KEYBOARD, MOUSE, JOYPAD}
enum JoypadMode {ADAPTIVE, FORCE_KEYBOARD, FORCE_JOYPAD, ONLY_JOYPAD, ONLY_KEYBOARD}
enum FitMode {NONE, MATCH_WIDTH, MATCH_HEIGHT}

@export var action_name: String
@export var joypad_mode: JoypadMode = 0
@export var favor_mouse: bool = true
@export var fit_mode: FitMode = 1
@export var constant: bool

var base_path: String
var use_joypad: bool

func _ready() -> void:
	Utils.connect("joypad_updated", Callable(self, "refresh2"))
	Utils.connect("coop_toggled", Callable(self, "update_coop"))
	
	base_path = scene_file_path.get_base_dir()
	use_joypad = Utils.is_using_joypad()
	
	if not action_name:
		return
	
	if not InputMap.has_action(get_action_name()) and not action_name in CUSTOM_ACTIONS:
		prefix = "p1_"
		assert(InputMap.has_action(get_action_name()) or action_name in CUSTOM_ACTIONS, str("Action \"", action_name, "\" does not exist in the InputMap nor CUSTOM_ACTIONS."))
	
	refresh()

func refresh():
	if is_nan(size.y):
		return
	if joypad_mode == JoypadMode.ONLY_JOYPAD:
		if not use_joypad:
			hide()
			return
		else:
			show()
	
	if joypad_mode == JoypadMode.ONLY_KEYBOARD:
		if use_joypad:
			hide()
			return
		else:
			show()
	
	if visible:
		if fit_mode != FitMode.NONE:
			custom_minimum_size = Vector2()
		
		if fit_mode == FitMode.MATCH_WIDTH:
			custom_minimum_size.x = size.y
		elif fit_mode == FitMode.MATCH_HEIGHT:
			custom_minimum_size.y = size.x
	else:
		return
	
	var is_joypad := false
	if joypad_mode != JoypadMode.ONLY_KEYBOARD and (joypad_mode == JoypadMode.FORCE_JOYPAD or joypad_mode == JoypadMode.ONLY_JOYPAD or (joypad_mode == JoypadMode.ADAPTIVE and use_joypad)):
		is_joypad = true
	
	if action_name in CUSTOM_ACTIONS:
		var image_list: PackedStringArray = CUSTOM_ACTIONS[action_name].split("|")
		assert(image_list.size() >= 3, "Need more |")
		
		if is_joypad and image_list[JOYPAD]:
			texture = get_image(JOYPAD, image_list[JOYPAD])
		elif not is_joypad:
			if favor_mouse and image_list[MOUSE]:
				texture = get_image(MOUSE, image_list[MOUSE])
			elif image_list[KEYBOARD]:
				texture = get_image(KEYBOARD, image_list[KEYBOARD])
		return
	
	var keyboard := -1
	var mouse := -1
	var joypad := -1
	var joypad_axis := -1
	var joypad_axis_value: float
	
	for event in InputMap.action_get_events(get_action_name()):
		if event is InputEventKey and keyboard == -1:
			if event.keycode > 0:
				keyboard = event.keycode
			else:
				keyboard = event.physical_keycode
		elif event is InputEventMouseButton and mouse == -1:
			mouse = event.button_index
		elif event is InputEventJoypadButton and joypad == -1:
			joypad = event.button_index
		elif event is InputEventJoypadMotion and joypad_axis == -1:
			joypad_axis = event.axis
			joypad_axis_value = event.axis_value
	
	if is_joypad and joypad >= 0:
		texture = get_joypad(joypad)
	elif is_joypad and joypad_axis >= 0:
		texture = get_joypad_axis(joypad_axis, joypad_axis_value)
	elif not is_joypad:
		if mouse >= 0 and (favor_mouse or keyboard < 0):
			texture = get_mouse(mouse)
		elif keyboard >= 0:
			texture = get_keyboard(keyboard)
	
	if not texture and action_name:
		pass
#		push_error("No icon for action: " + action_name)

func get_keyboard(key: int) -> Texture2D:
	match key:
		KEY_0, KEY_KP_0: ## TODO: oddzielne ikony chyba?
			return get_image(KEYBOARD, "0")
		KEY_1, KEY_KP_1:
			return get_image(KEYBOARD, "1")
		KEY_2, KEY_KP_2:
			return get_image(KEYBOARD, "2")
		KEY_3, KEY_KP_3:
			return get_image(KEYBOARD, "3")
		KEY_4, KEY_KP_4:
			return get_image(KEYBOARD, "4")
		KEY_5, KEY_KP_5:
			return get_image(KEYBOARD, "5")
		KEY_6, KEY_KP_6:
			return get_image(KEYBOARD, "6")
		KEY_7, KEY_KP_7:
			return get_image(KEYBOARD, "7")
		KEY_8, KEY_KP_8:
			return get_image(KEYBOARD, "8")
		KEY_9, KEY_KP_9:
			return get_image(KEYBOARD, "9")
		KEY_A:
			return get_image(KEYBOARD, "A")
		KEY_B:
			return get_image(KEYBOARD, "B")
		KEY_C:
			return get_image(KEYBOARD, "C")
		KEY_D:
			return get_image(KEYBOARD, "D")
		KEY_E:
			return get_image(KEYBOARD, "E")
		KEY_F:
			return get_image(KEYBOARD, "F")
		KEY_G:
			return get_image(KEYBOARD, "G")
		KEY_H:
			return get_image(KEYBOARD, "H")
		KEY_I:
			return get_image(KEYBOARD, "I")
		KEY_J:
			return get_image(KEYBOARD, "J")
		KEY_K:
			return get_image(KEYBOARD, "K")
		KEY_L:
			return get_image(KEYBOARD, "L")
		KEY_M:
			return get_image(KEYBOARD, "M")
		KEY_N:
			return get_image(KEYBOARD, "N")
		KEY_O:
			return get_image(KEYBOARD, "O")
		KEY_P:
			return get_image(KEYBOARD, "P")
		KEY_Q:
			return get_image(KEYBOARD, "Q")
		KEY_R:
			return get_image(KEYBOARD, "R")
		KEY_S:
			return get_image(KEYBOARD, "S")
		KEY_T:
			return get_image(KEYBOARD, "T")
		KEY_U:
			return get_image(KEYBOARD, "U")
		KEY_V:
			return get_image(KEYBOARD, "V")
		KEY_W:
			return get_image(KEYBOARD, "W")
		KEY_X:
			return get_image(KEYBOARD, "X")
		KEY_Y:
			return get_image(KEYBOARD, "Y")
		KEY_Z:
			return get_image(KEYBOARD, "Z")
		KEY_F1:
			return get_image(KEYBOARD, "F1")
		KEY_F2:
			return get_image(KEYBOARD, "F2")
		KEY_F3:
			return get_image(KEYBOARD, "F3")
		KEY_F4:
			return get_image(KEYBOARD, "F4")
		KEY_F5:
			return get_image(KEYBOARD, "F5")
		KEY_F6:
			return get_image(KEYBOARD, "F6")
		KEY_F7:
			return get_image(KEYBOARD, "F7")
		KEY_F8:
			return get_image(KEYBOARD, "F8")
		KEY_F9:
			return get_image(KEYBOARD, "F9")
		KEY_F10:
			return get_image(KEYBOARD, "F10")
		KEY_F11:
			return get_image(KEYBOARD, "F11")
		KEY_F12:
			return get_image(KEYBOARD, "F12")
		KEY_LEFT:
			return get_image(KEYBOARD, "Left")
		KEY_RIGHT:
			return get_image(KEYBOARD, "Right")
		KEY_UP:
			return get_image(KEYBOARD, "Up")
		KEY_DOWN:
			return get_image(KEYBOARD, "Down")
		KEY_QUOTELEFT:
			return get_image(KEYBOARD, "Tilde")
		KEY_MINUS, KEY_KP_SUBTRACT:
			return get_image(KEYBOARD, "Minus")
		KEY_PLUS, KEY_KP_ADD:
			return get_image(KEYBOARD, "Plus")
		KEY_BACKSPACE:
			return get_image(KEYBOARD, "Backspace")
		KEY_BRACELEFT:
			return get_image(KEYBOARD, "BracketLeft")
		KEY_BRACERIGHT:
			return get_image(KEYBOARD, "BracketRight")
		KEY_SEMICOLON:
			return get_image(KEYBOARD, "Semicolon")
		KEY_QUOTEDBL:
			return get_image(KEYBOARD, "Quote")
		KEY_BACKSLASH:
			return get_image(KEYBOARD, "BackSlash")
		KEY_ENTER, KEY_KP_ENTER:
			return get_image(KEYBOARD, "Enter")
		KEY_ESCAPE:
			return get_image(KEYBOARD, "Esc")
		KEY_LESS:
			return get_image(KEYBOARD, "LT")
		KEY_GREATER:
			return get_image(KEYBOARD, "GT")
		KEY_QUESTION:
			return get_image(KEYBOARD, "Question")
		KEY_CTRL:
			return get_image(KEYBOARD, "Ctrl")
		KEY_SHIFT:
			return get_image(KEYBOARD, "Shift")
		KEY_ALT:
			return get_image(KEYBOARD, "Alt")
		KEY_SPACE:
			return get_image(KEYBOARD, "Space")
		KEY_META:
			return get_image(KEYBOARD, "Win")
		KEY_CAPSLOCK:
			return get_image(KEYBOARD, "CapsLock")
		KEY_TAB:
			return get_image(KEYBOARD, "Tab")
		KEY_PRINT:
			return get_image(KEYBOARD, "PrintScrn")
		KEY_INSERT:
			return get_image(KEYBOARD, "Insert")
		KEY_HOME:
			return get_image(KEYBOARD, "Home")
		KEY_PAGEUP:
			return get_image(KEYBOARD, "PageUp")
		KEY_DELETE:
			return get_image(KEYBOARD, "Delete")
		KEY_END:
			return get_image(KEYBOARD, "End")
		KEY_PAGEDOWN:
			return get_image(KEYBOARD, "PageDown")
		KEY_NUMLOCK:
			return get_image(KEYBOARD, "NumLock")
	return null

func get_joypad(button: int) -> Texture2D:
	match button:
		JOY_BUTTON_A:
			return get_image(JOYPAD, "A")
		JOY_BUTTON_B:
			return get_image(JOYPAD, "B")
		JOY_BUTTON_X:
			return get_image(JOYPAD, "X")
		JOY_BUTTON_Y:
			return get_image(JOYPAD, "Y")
		JOY_BUTTON_LEFT_SHOULDER:
			return get_image(JOYPAD, "LB")
		JOY_BUTTON_RIGHT_SHOULDER:
			return get_image(JOYPAD, "RB")
		JOY_AXIS_TRIGGER_LEFT:
			return get_image(JOYPAD, "LT")
		JOY_AXIS_TRIGGER_RIGHT:
			return get_image(JOYPAD, "RT")
		JOY_BUTTON_LEFT_STICK:
			return get_image(JOYPAD, "L")
		JOY_BUTTON_RIGHT_STICK:
			return get_image(JOYPAD, "R")
		JOY_BUTTON_BACK:
			return get_image(JOYPAD, "Select")
		JOY_BUTTON_START:
			return get_image(JOYPAD, "Start")
		JOY_BUTTON_DPAD_UP:
			return get_image(JOYPAD, "DPadUp")
		JOY_BUTTON_DPAD_DOWN:
			return get_image(JOYPAD, "DPadDown")
		JOY_BUTTON_DPAD_LEFT:
			return get_image(JOYPAD, "DPadLeft")
		JOY_BUTTON_DPAD_RIGHT:
			return get_image(JOYPAD, "DPadRight")
		JOY_BUTTON_MISC1:
			return get_image(JOYPAD, "Share")
	return null

func get_joypad_axis(axis: int, value: float) -> Texture2D:
	match axis:
		JOY_AXIS_LEFT_X:
			if value < 0:
				return get_image(JOYPAD, "LeftStickLeft")
			elif value > 0:
				return get_image(JOYPAD, "LeftStickRight")
			else:
				return get_image(JOYPAD, "LeftStick")
		JOY_AXIS_LEFT_Y:
			if value < 0:
				return get_image(JOYPAD, "LeftStickUp")
			elif value > 0:
				return get_image(JOYPAD, "LeftStickDown")
			else:
				return get_image(JOYPAD, "LeftStick")
		JOY_AXIS_RIGHT_X:
			if value < 0:
				return get_image(JOYPAD, "RightStickLeft")
			elif value > 0:
				return get_image(JOYPAD, "RightStickRight")
			else:
				return get_image(JOYPAD, "RightStick")
		JOY_AXIS_RIGHT_Y:
			if value < 0:
				return get_image(JOYPAD, "RightStickUp")
			elif value > 0:
				return get_image(JOYPAD, "RightStickDown")
			else:
				return get_image(JOYPAD, "RightStick")
	return null

func get_mouse(button: int) -> Texture2D:
	match button:
		MOUSE_BUTTON_LEFT:
			return get_image(MOUSE, "Left")
		MOUSE_BUTTON_RIGHT:
			return get_image(MOUSE, "Right")
		MOUSE_BUTTON_MIDDLE:
			return get_image(MOUSE, "Middle")
		MOUSE_BUTTON_WHEEL_DOWN:
			return get_image(MOUSE, "WheelDown")
		MOUSE_BUTTON_WHEEL_LEFT:
			return get_image(MOUSE, "WheelLeft")
		MOUSE_BUTTON_WHEEL_RIGHT:
			return get_image(MOUSE, "WheelRight")
		MOUSE_BUTTON_WHEEL_UP:
			return get_image(MOUSE, "WheelUp")
	return null

func get_image(type: int, image: String) -> Texture2D:
	match type:
		KEYBOARD:
			return load(base_path + "/Keyboard/" + image + ".png") as Texture2D
		MOUSE:
			return load(base_path + "/Mouse/" + image + ".png") as Texture2D
		JOYPAD:
			return load(base_path + "/Joypad/" + image + ".png") as Texture2D
	return null

var player
var prefix: String

func refresh2():
	if is_instance_valid(player):
		use_joypad = player.using_joypad()
	else:
		use_joypad = Utils.is_using_joypad()
	refresh()

func set_input_player(p):
	player = p
	prefix = "p1_"
	refresh2()

func get_action_name() -> String:
	return prefix + action_name

func set_prefix(p: String):
	prefix = p
	refresh()

func update_coop(enable: bool):
	if not is_instance_valid(player) or not enable:
		prefix = "p1_"
		refresh2()
		return
	
	prefix = "p%s_" % player.control_id
	refresh2()
