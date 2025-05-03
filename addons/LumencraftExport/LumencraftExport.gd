@tool
extends EditorPlugin

var exporter: Exporter

func _enter_tree() -> void:
	exporter = Exporter.new()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)

class Exporter extends EditorExportPlugin:
	var music_list: Array
	var settings_copy: Dictionary
	
	func _init() -> void:
		music_list = Music.get_music_list()
	
	func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
		overwrite_setting("display/window/size/viewport_width", 1280)
		overwrite_setting("display/window/size/viewport_height", 720)
		overwrite_setting("display/window/size/borderless", true)
		overwrite_setting("display/window/stretch/shrink", 0.3333333333)
		ProjectSettings.save()
	
	func _export_end() -> void:
		restore_setting("display/window/size/viewport_width")
		restore_setting("display/window/size/viewport_height")
		restore_setting("display/window/size/borderless")
		restore_setting("display/window/stretch/shrink")
		ProjectSettings.save()
	
	func overwrite_setting(setting: String, value):
		settings_copy[setting] = ProjectSettings.get_setting(setting)
		ProjectSettings.set_setting(setting, value)
	
	func restore_setting(setting: String):
		ProjectSettings.set_setting(setting, settings_copy[setting])
	
	func _export_file(path: String, type: String, features: PackedStringArray) -> void:
		if not "expo" in features and path.get_file().get_basename() =="Trailer":
			skip()
		
		if path.begins_with("res://Maps/Pregenerated/"):
			skip()
		
		if path.begins_with("res://Nodes/Map/Generator/RectGenerators/CraftedRects/Sources/"):
			skip()
		
		if path.begins_with("res://Resources/Terrain/ArrayTest/"):
			skip()
		
		if path.begins_with("res://Music/") and not path in music_list:
			skip()
		
		if "demo" in features:
			pass
#			if path.begins_with("res://Scenes/Editor/"):
#				skip()
		else:
			if path.begins_with("res://Scenes/Demo/"):
				skip()
		
#		if not "steam" in features and path.findn("steam") > -1 and path.get_extension() != "gd":
#			skip()
