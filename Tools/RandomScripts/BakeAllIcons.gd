@tool
extends EditorScript

func _run() -> void:
	var dir := DirAccess.new()
	dir.open("res://Nodes/Buildings/Icons/")
	dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
	
	var baker = load("res://Tools/RandomScripts/TextureVectorOutlineBaker.gd").new()
	
	var file := dir.get_next()
	while not file.is_empty():
		if file.begins_with("Icon"):
			print("Baking ", file)
			
			var scene = load(dir.get_current_dir().plus_file(file)).instantiate()
			baker.bake_scene(scene)
			scene.queue_free()
		
		file = dir.get_next()
