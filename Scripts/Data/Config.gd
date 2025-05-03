extends Resource
class_name Config

enum {WINDOWED, BORDERLESS_FULLSCREEN, FULLSCREEN}
enum {CONTROL_AUTO, CONTROL_KEYBOARD, CONTROL_JOYPAD, CONTROL_ALL}

var ALL_ACTIONS

@export var language: String = TranslationServer.get_locale()

# Audio
@export var sound_enabled: bool = true
@export var sound_volume: float = 1
@export var music_enabled: bool = true
@export var music_volume: float = 1
@export var mute_when_unfocused: bool = true

# Controls
@export var controls1: Resource = preload("res://Scripts/Data/ControlsRemap.gd").new("p2_")
@export var controls2: Resource = preload("res://Scripts/Data/ControlsRemap.gd").new("p3_")
@export var controls3: Resource = preload("res://Scripts/Data/ControlsRemap.gd").new("p4_")
@export var alternate_movement: bool = false
@export var control_schemes := [0, 1, 2, 3, 4]
@export var single_player_controls: int

# Screen
@export var vsync: bool = true
#export var use_limit_fps: bool = false
@export var limit_fps:int = 60

@export var is_fullscreen: bool = false
@export var screenmode: int = WINDOWED

@export var fullscreen_resolution := Vector2()
@export var windowed_resolution := Vector2()


# Performace
@export var light_downsample:int= 4
var downsample:int= 4

@export var glow_high_quality: bool = true
@export var glow_type:int= 2
@export var glow_intensity:float= 0.75
@export var glow_strength:float= 0.8
@export var shadow_render_steps:int= 8
#export var shadow_short_render_steps:int= 12

# UI
#export var ui_scaleing: float = 1.0
@export var enable_autosave: bool = true
@export var low_health_alarm: bool = true
@export var show_enemy_health: bool = true
@export var show_damage_numbers: bool = true
@export var show_control_tooltips: bool = true
@export var ui_scale: float = 0.8
@export var additional_zoom: bool
@export var aim_hack := true

@export var blood_color: Color = Color("ff0000")
@export var ui_main_color: Color = Color("ffb800")
@export var ui_secondary_color: Color = Color("09a184")

@export var editor_console_active: bool


# Accessibility
@export var joypad_vibrations: float = 1.0
@export var screenshake: float = 1.0
@export var cursor_scale: float = 0.5

@export var demo_timer: bool
@export var prev_version: int

var once: bool
var previous_resolution = Vector2()
var target_window_position = Vector2()
var target_window_size = Vector2()
var old_config: Resource

var p1_action_stash: Array

var refresh_display := true

func _init() -> void:
	ALL_ACTIONS = preload("res://Scripts/Data/ControlsRemap.gd").ACTION_LIST.duplicate()
	ALL_ACTIONS.append_array(["look_up", "look_down", "look_left", "look_right", "next_row", "prev_row"])
	
	for action in ALL_ACTIONS:
		p1_action_stash.append(InputMap.action_get_events("p1_" + action))
	
	prev_version = int(preload("res://Tools/version.gd").VERSION)

func apply():
	apply_controls()
	if refresh_display:
		target_window_position = DisplayServer.screen_get_position()
		apply_display()
		refresh_display = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if (vsync) else DisplayServer.VSYNC_DISABLED)
#	set_ui_sacle()
	apply_frame_cap()
	apply_downsampling()
	apply_shadow_steps()
	apply_audio()
	apply_environment()
	if has_changed("language"):
		TranslationServer.set_locale(language)
	
	if additional_zoom:
		Const.CAMERA_ZOOM = 10
	else:
		Const.CAMERA_ZOOM = 8
	
	Utils.recolor_theme(ui_main_color, ui_secondary_color)
	Const.BLOOD_COLOR = blood_color
	
	Utils.get_tree().call_group("config_observers", "update_config")
	Save.save_config()
	
#	Utils.display_handler.handle_your_shit()
	backup_config()
#	old_config = duplicate()
	
	
func request_refresh_display():
	refresh_display = true

func apply_controls():
	controls1.apply_remap()
	controls2.apply_remap()
	controls3.apply_remap()
	
	for i in ALL_ACTIONS.size():
		var action := str("p1_", ALL_ACTIONS[i])
		InputMap.action_erase_events(action)
		
		if single_player_controls != CONTROL_JOYPAD:
			for event in p1_action_stash[i]:
				if event is InputEventKey or event is InputEventMouse:
					InputMap.action_add_event(action, event)
		
		if single_player_controls != CONTROL_KEYBOARD:
			for event in p1_action_stash[i]:
				if event is InputEventJoypadButton or event is InputEventJoypadMotion:
					InputMap.action_add_event(action, event)
	
	if single_player_controls != CONTROL_JOYPAD:
		controls1.apply_remap("p1_")

	if single_player_controls != CONTROL_KEYBOARD:
		controls2.apply_remap("p1_", false)

func apply_display():
	if fullscreen_resolution == Vector2():
		fullscreen_resolution = DisplayServer.screen_get_size()
	
	if windowed_resolution == Vector2():
		if Const.is_steam_deck:
			windowed_resolution = DisplayServer.screen_get_size()
			screenmode = FULLSCREEN
			additional_zoom = true
		elif OS.has_feature("OSX"):
			screenmode = FULLSCREEN
			windowed_resolution = DisplayServer.screen_get_size() / 2
		else:
			windowed_resolution = DisplayServer.screen_get_size() / 2
	
	if OS.has_feature("editor") and not has_meta("editor"):
		set_meta("editor", true)
		Utils.log_message("Running from Editor")
		prints ("Screenmode has changed:", has_changed("screenmode"), "\nFullscreen resolution has changed:",has_changed("fullscreen_resolution"), "\nWindowed resolution has changed:", has_changed("windowed_resolution"))
	if (has_changed("screenmode") or has_changed("fullscreen_resolution") or has_changed("windowed_resolution")):
		if screenmode == Save.config.WINDOWED:
			is_fullscreen = false
#			OS.window_fullscreen = false
#			OS.set_window_always_on_top(false)
			Utils.get_tree().connect("idle_frame", Callable(OS, "center_window").bind(), CONNECT_ONE_SHOT)
		else:
			is_fullscreen = true
			target_window_size = DisplayServer.screen_get_size()
			target_window_position = DisplayServer.screen_get_position()
#			OS.window_fullscreen = false
			var window = Utils.get_window()
			Utils.get_window().mode = Window.MODE_MAXIMIZED if (false) else Window.MODE_WINDOWED
			match OS.get_name():
				"OSX":
					pass
				_:
					window.unresizable = not (true)
					window.borderless = false

			window.borderless = true
			Utils.handler.handle_resigs()
			Utils.handler.handle_movix()
			Utils.handler.handle_maxing()

#			if screenmode == Save.config.FULLSCREEN:
#				OS.window_size = size
##				OS.window_fullscreen = true
#			else:
#				OS.window_size = size + Vector2(0,1)
#
#		var string = "OS Screen(%s): %s, Mode: "
#		match screenmode:
#			0:
#				string += "windowed"
#			1:
#				string += "borderless fullscreen"
#			2:
#				string += "exclusive fullscreen"
#
#		string += ", Render: [current:%s, set:%s], Window size: %s"
#		Utils.log_message(string % [OS.current_screen, OS.get_screen_size(), previous_resolution, get_resolution(), OS.window_size])



#	if not once and (has_changed("screenmode") or has_changed("fullscreen_resolution") or has_changed("windowed_resolution")):
#		once = OS.has_feature("OSX")
#		match screenmode:
#			WINDOWED:
#				is_fullscreen = false
#				OS.window_borderless = false
#				OS.window_fullscreen = false
#				OS.window_size = windowed_resolution
#				OS.center_window()
#
#			BORDERLESS_FULLSCREEN:
#				is_fullscreen = true
#				OS.window_fullscreen = false
#				OS.window_borderless = true
#				OS.window_maximized  = true
#				OS.window_size = OS.window_size + Vector2(0,1)
#
#			FULLSCREEN:
#				is_fullscreen = true
#				OS.window_fullscreen = true
#				OS.window_borderless = false
#				OS.window_maximized = true
#                 Utils.get_viewport().size = fullscreen_resolution

#---------------
	#			Utils.get_viewport().set_deferred("size", resolution)
#				Utils.get_tree().create_timer(0.5).connect("timeout", Utils.get_viewport(), "set", ["size", fullscreen_resolution])
	#			Utils.get_tree().create_timer(0.1).connect("timeout", Input, "set_mouse_mode", [Input.MOUSE_MODE_CONFINED])
#				Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	#			OS.window_size = resolution
#	Utils.get_viewport().size
#	screen_diagonal = Utils.get_viewport().size.length()
#	screen_diagonal = resolution.length()

func apply_window_resize():
	apply_vieport_size()

func apply_window_maximize():
	Utils.log_message("Maximizing Window")
	if screenmode == Save.config.FULLSCREEN:
		Utils.get_window().size = target_window_size
#		OS.window_fullscreen = true
	else:
		Utils.get_window().size = target_window_size + Vector2i(0,1)
		
func apply_window_move():
	Utils.get_window().position = target_window_position

func apply_vieport_size():
	Utils.get_viewport().size = get_resolution()
	if get_resolution() != previous_resolution:
		previous_resolution = get_resolution()

func apply_frame_cap():
	Engine.max_fps = limit_fps

func apply_downsampling():
	light_downsample = clamp(light_downsample, 1, 6)
	downsample = 1<<(6 - light_downsample)
	if not Utils.game or not Utils.game.map or not Utils.game.map.darkness:
		return
	Utils.game.map.darkness.on_window_resized()
	
func apply_shadow_steps():
	if not Utils.game or not Utils.game.map or not Utils.game.map.darkness:
		return
	Utils.game.map.darkness.update_lights_materials_render_steps()
	
func apply_environment():
	if not Utils.get_environment():
		return
	var enviro :Environment= Utils.get_environment()
	
	match glow_type:
		0:
			pass
		1:
			enviro.set("glow_levels/2", true)
			enviro.set("glow_levels/3", false)
			enviro.set("glow_levels/4", true)
			enviro.set("glow_levels/5", false)
		2:
			enviro.set("glow_levels/2", false)
			enviro.set("glow_levels/3", true)
			enviro.set("glow_levels/4", false)
			enviro.set("glow_levels/5", true)

	enviro.glow_intensity = glow_intensity
	enviro.glow_strength = glow_strength
	# RECHECK
	#enviro.glow_high_quality = glow_high_quality
	
	if enviro.glow_intensity <=0.01:
		enviro.glow_enabled = false
	else:
		enviro.glow_enabled = true

func apply_audio():
	if has_changed("sound_enabled") or has_changed("sound_volume"):
		sound_enabled = sound_volume > 0 ## tymczasowo??
		AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not sound_enabled)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sound_volume))
	
	if has_changed("music_enabled") or has_changed("music_volume"):
		music_enabled = music_volume > 0 ## tymczasowo??
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not music_enabled)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_volume))

func backup_config():
	old_config = duplicate()

func apply_ui_sacle():
#	Utils.get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_DISABLED, SceneTree.STRETCH_ASPECT_EXPAND, Vector2(960, 540), ui_scaleing)
#	Utils.get_viewport().size = Save.config.resolution
#	set_camera_zoom(ui_scaleing/4.0)
	pass

func set_startup_setting():
#	var override := ConfigFile.new()
#	override.load("res://override.cfg")
#	override.set_value("display", "window/size/width", int(Save.config.resolution.x) )
#	override.set_value("display", "window/size/height", int(Save.config.resolution.y) )
#	override.set_value("display", "window/size/fullscreen", OS.window_fullscreen )
#
#	override.save("res://override.cfg")
	pass

func set_resolution(new_resolution: Vector2):
#	prints("setting resolution ",new_resolution)
	match screenmode:
		WINDOWED:
			windowed_resolution = new_resolution
		BORDERLESS_FULLSCREEN:
			fullscreen_resolution = new_resolution
		FULLSCREEN:
			fullscreen_resolution = new_resolution

func set_sceen_mode(new_mode: int):
	if new_mode > FULLSCREEN or new_mode < WINDOWED:
		screenmode = WINDOWED
	else:
		screenmode = new_mode

func get_resolution(fullscreen_flag := is_fullscreen) -> Vector2:
	if fullscreen_flag:
		return fullscreen_resolution
	else:
		return windowed_resolution

func get_sceen_mode() -> int:
	return screenmode

func has_changed(property: String) -> bool:
	if old_config:
		return get(property) != old_config.get(property)
	return true

func control_tooltips_visible() -> bool:
	return show_control_tooltips or Save.current_map == "res://Maps/TutorialMap.tscn"
