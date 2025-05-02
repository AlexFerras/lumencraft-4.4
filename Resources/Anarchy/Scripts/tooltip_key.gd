extends PanelContainer

@onready var label: Label = $"%ValueKey"
@onready var key_texture: Control = $"%TooltipKey"
@onready var joy_texture: Control = $"%TooltipButton"
@onready var mouse_texture: TextureRect = $"%TooltipMouse"

const ButtonNames = {
	JOY_BUTTON_0: "A",
	JOY_BUTTON_1: "B",
	JOY_BUTTON_2: "X",
	JOY_BUTTON_3: "Y",
	JOY_BUTTON_4: "LB",
	JOY_BUTTON_5: "RB",
	JOY_BUTTON_6: "LT",
	JOY_BUTTON_7: "RT",
	JOY_BUTTON_8: "L",
	JOY_BUTTON_9: "R",
	JOY_BUTTON_10: "SELECT",
	JOY_BUTTON_11: "START",
	JOY_BUTTON_12: "D-UP",
	JOY_BUTTON_13: "D-DOWN",
	JOY_BUTTON_14: "D-LEFT",
	JOY_BUTTON_15: "D-RIGHT",
	JOY_BUTTON_16: "HOME",
	JOY_BUTTON_17: "SHARE",
}

const AxisNames = {
	JOY_AXIS_0: "L",
	JOY_AXIS_1: "L",
	JOY_AXIS_2: "L",
	JOY_AXIS_3: "L",
}

#const CUSTOM_ACTIONS = {
#	"move": "WSAD||LeftStick",
#	"look": "|None|RightStick",
#	"full_switch": "|WheelVertical|",
#}

const CUSTOM_ACTIONS = ["move", "look"]

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

var player
var prefix: String

func _ready() -> void:
	Utils.connect("joypad_updated", Callable(self, "refresh2"))
	Utils.connect("coop_toggled", Callable(self, "update_coop"))
	
	base_path = filename.get_base_dir()
	use_joypad = Utils.is_using_joypad()
	
	if not action_name:
		return
	
	if not InputMap.has_action(get_action_name()) and not action_name in CUSTOM_ACTIONS:
		prefix = "p1_"
		assert(InputMap.has_action(get_action_name()) or action_name in CUSTOM_ACTIONS, str("Action \"", action_name, "\" does not exist in the InputMap nor CUSTOM_ACTIONS."))
	
	refresh()

func refresh():
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
	
	var keyboard := -1
	var mouse := -1
	var joypad := -1
	var joypad_axis := -1
	var joypad_axis_value: float
	
	var string_joy: String
	var string_key: String
	
	if action_name in CUSTOM_ACTIONS:
		if action_name == "move":
			prefix = "p1_" ## uh ;_;
			var keys: PackedStringArray
			for action in [prefix + "up", prefix + "down", prefix + "left", prefix + "right"]:
				for event in InputMap.action_get_events(action):
					if event is InputEventKey and keyboard == -1:
						keys.append(event.as_text())
			
			keyboard = 0
			string_key = "/".join(keys)
			string_joy = "L"
	else:
		for event in InputMap.action_get_events(get_action_name()):
			if event is InputEventKey and keyboard == -1:
				string_key = event.as_text()
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
	
	label.text = "??"
	
	mouse_texture.hide()
	if is_joypad and not string_joy.is_empty():
		label.text = string_joy
	elif is_joypad and joypad >= 0:
		label.text = ButtonNames[joypad]
	elif is_joypad and joypad_axis >= 0:
		label.text = AxisNames[joypad_axis]
	elif not is_joypad:
		if mouse >= 0 and (favor_mouse or keyboard < 0):
			mouse_texture.show() ## TODO: ikonki różne
			label.text = ""
		elif keyboard >= 0:
			label.text = string_key
	
	key_texture.visible = not is_joypad and not mouse_texture.visible
	joy_texture.visible = is_joypad

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
