extends TextDatabase

enum Dir {U, R, D, L}

func _initialize():
	add_mandatory_property("exits", TYPE_ARRAY)

func _preprocess_entry(entry: Dictionary):
	var exits: Array
	for e in entry.exits:
		exits.append(Dir.keys().find(e))
	entry.exits = exits
	
	entry.texture = load(str("res://Nodes/Map/Generator/TerrainPieces/", entry.name, ".png"))
	entry.size = entry.texture.get_size() / Vector2(128, 128)
