extends Sprite2D

@onready var bounding_rect: Sprite2D = get_node_or_null(@"BoundingRect")
@onready var ground_rect: Sprite2D = get_node_or_null(@"GroundRect")
@onready var angle_indicator: CanvasItem = get_node_or_null(@"AngleIndicator")
@onready var socket: Node2D = get_node_or_null(@"Socket")
@onready var item_icon: Node2D = get_node_or_null(@"Item")

@export var building_data: Dictionary
@export var use_sprite_for_scale: bool
@export var combined_scale: bool

@export var original_scale: Vector2
@export var angle: float: set = set_angle
@export var rotate_to_angle := true

var target_building: Node2D
var can_build: bool
var canceled: bool

signal cancel

func _ready() -> void:
	set_physics_process(false)
	add_to_group("dont_save")
	
	if not bounding_rect:
		push_error("Brak bounding rect w " + filename.get_file())
		return
	
	bounding_rect.hide()
	if ground_rect:
		ground_rect.hide()
	await get_parent().ready
	
	if get_parent().is_in_group("player_buildings") and name != "TerrainMask":
		queue_free()

func on_moved():
	pass

func set_as_preview():
	if angle_indicator:
		angle_indicator.show()
	
	if ground_rect:
		ground_rect.show()
	else:
		bounding_rect.show()
	
	if item_icon:
		item_icon.hide()

func is_multibuild() -> bool:
	return false

func set_angle(a: float):
	if not building_data.get("build_rotate", false):
		return
	
	angle = a
	if rotate_to_angle:
		rotation = angle

func on_placed():
	if angle_indicator:
		angle_indicator.hide()
	
	if ground_rect:
		ground_rect.hide()
		#ground_rect = null
		bounding_rect.show()

func set_can_build(can: bool):
	can_build = can
	
	if can:
		material = null
		if bounding_rect:
			bounding_rect.modulate = Color(0, 1, 0, 0.3)
		if ground_rect:
			ground_rect.modulate = Color(0, 1, 0, 0.3)
	else:
		material = preload("res://Resources/Materials/InvalidBuilding.tres")
		if bounding_rect:
			bounding_rect.modulate = Color(1, 0, 0, 1)
		if ground_rect:
			ground_rect.modulate = Color(1, 0, 0, 1)

func set_target_building(building: Node2D):
	target_building = building
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if not bounding_rect:
		return
	
	var rects: Array
	if bounding_rect.get_child_count() > 0:
		for rect in bounding_rect.get_children():
			rects.append(BuildInterface.RotatedRect.new(Rect2(rect.global_position, rect.global_scale * 0.5), rect.global_rotation))
	else:
		if bounding_rect.scale.x < 0.00001:
			rects.append(BuildInterface.RotatedRect.new(Rect2(), 0))
		else:
			rects.append(BuildInterface.RotatedRect.new(Rect2(bounding_rect.global_position, bounding_rect.global_scale * 0.5), bounding_rect.global_rotation))
	
	var rects2: Array
	
	if ground_rect:
		if ground_rect.get_child_count() > 0:
			for rect in ground_rect.get_children():
				rects2.append(BuildInterface.RotatedRect.new(Rect2(rect.global_position, rect.global_scale * 0.5), rect.global_rotation))
		else:
			if ground_rect.scale.x < 0.00001:
				rects2.append(BuildInterface.RotatedRect.new(Rect2(), 0))
			else:
				rects2.append(BuildInterface.RotatedRect.new(Rect2(ground_rect.global_position, ground_rect.global_scale * 0.5), ground_rect.global_rotation))
	
	var canbu := can_build
	var error = BuildInterface.are_rects_occupied(self, socket.global_position if socket else global_position, rects,rects2)
	
	set_can_build(not bool(error))
	if can_build and not canbu:
		BuildInterface.unred()

func get_sprite_mask() -> PackedVector2Array:
	var file := ConfigFile.new()
	if use_sprite_for_scale:
		file.load(str("res://Nodes/Buildings/Common/Masks/", $Sprite2D.texture.resource_path.get_file(), ".cfg"))
	else:
		file.load(str("res://Nodes/Buildings/Common/Masks/", texture.resource_path.get_file(), ".cfg"))
	var data := file.get_value("mask", "data") as PackedVector2Array
	
	return data

func get_bounds() -> Rect2:
	var rect := bounding_rect
	if ground_rect:
		rect = ground_rect
	
	var size := bounding_rect.global_scale
	return Rect2(bounding_rect.global_position - size * 0.5, size)

func _get_save_data() -> Dictionary:
	return {scene = filename, pos = global_position, rot = angle}

func cancel():
	if canceled:
		return
	
	emit_signal("cancel")
	canceled = true
	
	for id in building_data.cost:
		for i in building_data.cost[id]:
			Pickup.launch({id = id, amount = 1}, global_position, Utils.random_point_in_circle(130), false)
	
	queue_free()

static func _instance_from_save(map: Map, data: Dictionary):
	var instance = load(data.scene).instantiate()
	map.add_child(instance)
	
	var building
	for bdata in Const.Buildings.values():
		if bdata.get("icon", "") == data.scene:
			building = load(bdata.scene).instantiate()
			instance.building_data = bdata
			break
	
	instance.position = data.pos
	instance.angle = data.rot
	
	if not building:
		push_error("Failed to load building")
		return
	
	building.position = data.pos
	if building is BaseBuilding:
		building.in_construction = true
		building.angle = data.rot
	else:
		building.rotation = data.rot
	instance.set_target_building(building)
	
	return [building, instance]
