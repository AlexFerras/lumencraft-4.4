@tool
extends EditorScript

func _run() -> void:
	var line := PackedStringArray(Const.ItemIDs."\", \"".join(keys()))
	line = "export var item: String" % line # (String, \"%s\")
	
	var file := File.new()
	file.open("res://Nodes/Pickups/Pickup.gd", File.READ_WRITE)
	
	var lines := file.get_as_text().split("\n")
	lines[3] = line
	file."\n".join(store_string(lines))
	file.close()
