extends Node2D

@onready var check_points := $check_points
@onready var timer := $Timer as Timer
@onready var sprite := $Sprite2D as Sprite2D
@export var wall_lvl = 0: set = set_wall_level

var enemy_ignore: bool

var next_check := 10.0
var radius := 50.0
var dead: bool
var wall_material=Const.Materials.WALL
@export var non_upgradable=false

func set_wall_level(new_lvl):
	if new_lvl == wall_lvl:
		return
	wall_lvl = new_lvl
	
	if not is_inside_tree():
		await self.ready
	if new_lvl==3 && wall_material!=Const.Materials.WALL3:
		sprite.clear()
		wall_material=Const.Materials.WALL3
		sprite.painting_material=wall_material
		sprite.texture = preload("res://Nodes/Buildings/Wall/Level4.png")
		sprite.refresh_mask()
		sprite.queue_draw()
	elif new_lvl==2 && wall_material!=Const.Materials.WALL2:
		sprite.clear()
		wall_material=Const.Materials.WALL2
		sprite.painting_material=wall_material
		sprite.texture = preload("res://Nodes/Buildings/Wall/Level3.png")
		sprite.refresh_mask()
		sprite.queue_draw()
	elif new_lvl==1 && wall_material!=Const.Materials.WALL1:
		sprite.clear()
		wall_material=Const.Materials.WALL1
		sprite.painting_material=wall_material
		sprite.texture = preload("res://Nodes/Buildings/Wall/Level2.png")
		sprite.refresh_mask()
		sprite.queue_draw()
	elif wall_material!=Const.Materials.WALL:
		sprite.clear()
		wall_material=Const.Materials.WALL
		sprite.texture = preload("res://Nodes/Buildings/Wall/Level1.png")
		sprite.refresh_mask()
		sprite.painting_material=wall_material
		sprite.queue_draw()

func _ready() -> void:
	BaseBuilding.init_structure(self, "Wall")
	add_to_group("player_structures")
	
	if get_meta("built", false):
		sprite.disabled = true
	$check_points.modulate=Color(randf_range(0,1),randf_range(0,1),randf_range(0,1))
	
	if non_upgradable:
		$WallComputer.set_disabled(true)

func on_placed():
	sprite.disabled = false
	sprite.queue_redraw()
	remove_meta("in_construction")
	
	var walls=get_tree().get_nodes_in_group("repair_my_pixels")
	var polygon= PackedVector2Array()
	for i in $polygon.get_children():
		polygon.append(i.global_position)
	for i in walls:
		if i!=self && i.global_position.distance_to(global_position)<100.0:
			i.remove_check_point_in_rectangle(polygon)

func remove_check_point_in_rectangle(polygon: PackedVector2Array):
	for i in check_points.get_children():
		if Geometry2D.is_point_in_polygon(i.global_position,polygon):
			check_points.remove_child(i)

func check() -> void:
	for i in check_points.get_child_count():
		if Utils.game.map.pixel_map.is_pixel_solid(check_points.get_child(i).global_position, 1<<wall_material):
			timer.start(randf_range(1.0, 2.0))
			return
		
	# no more solid points destroy
	set_process(false)
	#$Sprite.destroy()
	dead = true
	var seq := create_tween()
	seq.tween_property(self, "modulate:a", 0.0, 2.0)
	seq.tween_callback(Callable(self, "queue_free"))

func repair_pixels(where: Vector2,repair_radius=15) -> int:
	if dead or get_meta("in_construction", false) or global_position.distance_squared_to(where) > 3600:
		return 0
	
	return Utils.game.map.pixel_map.update_material_circle_with_rotated_mask(sprite.global_position, where, repair_radius, sprite.mask, wall_material, Vector3(sprite.global_scale.x, sprite.global_scale.y, sprite.global_rotation), ~Utils.walkable_collision_mask, 1)

func get_sprite_mask() -> PackedVector2Array:
	var file := ConfigFile.new()
	file.load(str("res://Nodes/Buildings/Common/Masks/Wall.png.cfg"))
	var data := file.get_value("mask", "data") as PackedVector2Array
	return data

func build_fail():
	$Sprite2D.destroy()

func _get_save_data() -> Dictionary:
	return {is_built = get_meta("built", false)}

func _set_save_data(data: Dictionary):
	if data.get("is_built", false):
		set_meta("built", true)
	
	$Sprite2D.disabled = true
	$Sprite2D.connect("ready", Callable(self, "enable_sprite_after_1_second"))

func enable_sprite_after_1_second():
	get_tree().create_timer(0.5, false).connect("timeout", Callable($Sprite2D, "set").bind("disabled", false))

func destroy():
	## TODO: fx
	$Sprite2D.destroy()
	queue_free()
