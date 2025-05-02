@tool
extends EditorScript

var regex_gd: RegEx
var regex_tscn: RegEx

var all: Array
var found = 0

func _run() -> void:
	regex_gd = RegEx.new()
	if regex_gd.compile("random_sound\\(\"(.+)\"\\)") != OK:
		return
	regex_tscn = RegEx.new()
	if regex_tscn.compile("random_sound\\(\\\\\"(.+)\\\\\"\\)") != OK:
		return
	scan_dir("res://")
	print(all)
	prints("Found:", found)

func scan_dir(dir: String):
	var d := DirAccess.new()
	d.open(dir)
	d.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
	
	var file := d.get_next()
	while file:
		if d.current_is_dir():
			scan_dir(dir.plus_file(file))
		else:
			if file.get_extension() == "gd" or file.get_extension() == "tscn":
				var f := File.new()
				f.open(dir.plus_file(file), File.READ)
				var lines := f.get_as_text().split("\n")
				
				for line in lines:
					if line.strip_edges().begins_with("#"):
						continue
					
					var result: RegExMatch
					if file.get_extension() == "gd":
						result = regex_gd.search(line)
					else:
						result = regex_tscn.search(line)
					
					if result:
						found += 1
						var string := "\"" + result.get_string(1) + "\""
						if not string in all:
							all.append(string)
#						print(result.get_string(1))
		
		file = d.get_next()
