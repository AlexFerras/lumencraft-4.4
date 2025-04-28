extends Resource

## TODO: skryptem to zrobić
const ACTION_LIST = ["up", "down", "left", "right", "run", "shoot", "shoot2", "throw_item", "build", "next_slot", "prev_slot", "interact", "menu", "inventory", "map", "auto_walk", "slot1", "slot2", "slot3", "slot4", "respawn"]

@export var prefix: String: set = set_prefix
@export var keyboard_remap: Dictionary
@export var joypad_remap: Dictionary

var default_keyboard: Dictionary
var default_joypad: Dictionary

var stashed_keyboard: Dictionary
var stashed_joypad: Dictionary

var has_cloned_remap: bool

func _init(p_prefix := "") -> void:
	prefix = p_prefix
	load_defaults()

func set_prefix(p_prefix: String):
	prefix = p_prefix
	load_defaults()

func load_defaults():
	for action in ACTION_LIST:
		_map_input(default_keyboard, action, get_action_key(action))
		_map_input(default_joypad, action, get_action_button(action))

func create_remap():
	keyboard_remap.clear()
	joypad_remap.clear()
	var keyboard_actions: Dictionary
	var joypad_actions: Dictionary
	
	for action in ACTION_LIST:
		_map_input(keyboard_actions, action, get_action_key(action))
		_map_input(joypad_actions, action, get_action_button(action))
	
	for action in ACTION_LIST:
		if action in keyboard_actions and action in default_keyboard:
			if keyboard_actions[action] != default_keyboard[action]:
				keyboard_remap[action] = keyboard_actions[action]
		
		if action in joypad_actions and action in default_joypad:
			if joypad_actions[action] != default_joypad[action]:
				joypad_remap[action] = joypad_actions[action]

func apply_remap(custom_prefix := prefix, restore_defaults := true):
	var temp := prefix
	prefix = custom_prefix
	
	if restore_defaults:
		restore_default_controls()
	
	for action in ACTION_LIST:
		_demap_input(keyboard_remap, action, get_action_key(action))
		_demap_input(joypad_remap, action, get_action_button(action))
	
	prefix = temp

func restore_default_controls():
	for action in ACTION_LIST:
		restore_action_default(action)

func restore_action_default(action: String):
	_demap_input(default_keyboard, action, get_action_key(action))
	_demap_input(default_joypad, action, get_action_button(action))

func clone_remap():
	stashed_keyboard = keyboard_remap.duplicate()
	stashed_joypad = joypad_remap.duplicate()
	has_cloned_remap = true

func restore_cloned_remap():
	if has_cloned_remap:
		return
	keyboard_remap = stashed_keyboard.duplicate()
	joypad_remap = stashed_joypad.duplicate()

func set_action_key(action: String, key: InputEventKey) -> bool:
	for event in InputMap.action_get_events(prefix + action):
		if event is InputEventKey:
			event.keycode = key.keycode
			return true
	return false

func get_action_key(action: String) -> InputEventKey:
	for event in InputMap.action_get_events(prefix + action):
		if event is InputEventKey:
			return event
	return null

func set_action_button(action: String, button: InputEventJoypadButton) -> bool:
	for event in InputMap.action_get_events(prefix + action):
		if event is InputEventJoypadButton:
			event.button_index = button.button_index
			return true
	return false

func get_action_button(action: String) -> InputEventJoypadButton:
	for event in InputMap.action_get_events(prefix + action):
		if event is InputEventJoypadButton:
			return event
	return null

func find_duplicates() -> Array:
	var dupes: Array
	
	for action in ACTION_LIST:
		var key1 := get_action_key(action)
		if key1:
			for action2 in ACTION_LIST:
				if action == action2:
					continue
				
				var key2 := get_action_key(action2)
				if key2:
					if key1.keycode == key2.keycode:
						dupes.append([action, action2])
						break
	
	for action in ACTION_LIST:
		var button1 := get_action_button(action)
		if button1:
			for action2 in ACTION_LIST:
				if action == action2:
					continue
				
				var button2 := get_action_button(action2)
				if button2:
					if button1.button_index == button2.button_index and not [action, action2] in dupes:
						dupes.append([action, action2])
						break
	
	return dupes

func _map_input(map: Dictionary, action: String, input):
	if input is InputEventKey:
		map[action] = input.keycode
	elif input is InputEventJoypadButton:
		map[action] = input.button_index

func _demap_input(map: Dictionary, action: String, input):
	if not action in map:
		return
	
	if input is InputEventKey:
		input.keycode = map[action]
	elif input is InputEventJoypadButton:
		input.button_index = map[action]
