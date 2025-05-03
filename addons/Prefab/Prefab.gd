extends PackedScene
class_name Prefab

static func create(node: Node, deferred_free := false) -> Prefab:
	assert(node, "Invalid node provided.")
	node.unique_name_in_owner = false
	
	var to_check := node.get_children()
	while not to_check.is_empty():
		var sub: Node = to_check.pop_back()
		if sub.owner == null:
			continue
		
		if sub.scene_file_path.is_empty():
			to_check.append_array(sub.get_children())
		sub.owner = node
	
	var prefab: Prefab = load("res://addons/Prefab/Prefab.gd").new()
	prefab.pack(node)
	
	if deferred_free:
		node.queue_free()
	else:
		node.free()
	
	return prefab

static func fake_create(node: Node, deferred_free := false) -> FakePrefab:
	assert(not node.filename.is_empty())
	var prefab := FakePrefab.new(node)
	
	if deferred_free:
		node.queue_free()
	else:
		node.free()
	
	return prefab

static func create_fake_from_data(data: Dictionary) -> FakePrefab:
	var prefab := FakePrefab.new(null)
	prefab.scene = load(data.scene)
	prefab.data = data.data
	return prefab

class FakePrefab:
	var scene: PackedScene
	var data: Dictionary
	
	func _init(node: Node) -> void:
		if not node:
			return
		
		scene = load(node.filename)
		data = Utils.get_savable_properties(node)
#		data = preload("res://Scripts/Data/SaveFile.gd").get_savable_properties(node)
	
	func instance() -> Node:
		var node := scene.instantiate()
		for property in data:
			node.set(property, data[property])
		return node
	
	func _get_save_data() -> Dictionary:
		return {scene = scene.resource_path, data = data}
