extends Node2D
class_name BuildInterface

enum {ERROR_UNKNOWN = -1, ERROR_OUTSIDE = 1, ERROR_TERRAIN, ERROR_PLAYER, ERROR_BUILDING, ERROR_BLUEPRINT, ERROR_ENEMY, ERROR_GATE, DEMOLISH_NONE, DEMOLISH_INVALID}

const CHECKS = [
	Vector2(-1, -1), Vector2(1, -1),
	Vector2(1, -1), Vector2(1, 1),
	Vector2(1, 1), Vector2(-1, 1),
	Vector2(-1, 1), Vector2(-1, -1),
	Vector2(-1, -1), Vector2(1, 1),
	Vector2(1, -1), Vector2(-1, 1),
]
const CHECKS_NO_DIAG = [
	Vector2(-1, -1), Vector2(1, -1),
	Vector2(1, -1), Vector2(1, 1),
	Vector2(1, 1), Vector2(-1, 1),
	Vector2(-1, 1), Vector2(-1, -1),
]

@onready var cursor := $Cursor as Node2D
@onready var cursor_offset := $Cursor/Offset as Node2D
@onready var building_detector := $BuildingDetector as Node2D
@onready var why_cant := $"%ErrorLabel" as Label

var blueprint: Node2D
var align: BaseBuilding
var error: int
var finished: bool
var rotate_mode: bool
var rotate_delay: float
var try_rot: float
var prev_player: Vector2
var fking_delay := 0.1

var player

signal place(blueprint, preview)

func _ready() -> void:
	update_config()
	init_blueprint()
	remove_child(building_detector)
	Utils.game.map.add_child(building_detector)
	building_detector.global_position = cursor.global_position
	prev_player = player.global_position
	propagate_call("set_input_player", [player])

func init_blueprint():
	cursor_offset.add_child(blueprint)
	cursor.position = Vector2.RIGHT.rotated(player.get_shoot_rotation()) * 200
	Utils.game.connect("diagonal_changed", Callable(self, "update_zoom"))
	blueprint.angle = player.last_build_angle
	blueprint.set_as_preview()
	update_zoom()
	
	if not blueprint.rotate_to_angle:
		$"%Help/Rotate".hide()
		$"%Help/Rotate2".hide()
		$"%Help".set_physics_process(false)
	
	if blueprint.has_meta("demolish"):
		$"%Multiple".text = "demolish multiple"
	else:
		$"%Demolish".hide()

func update_zoom():
	blueprint.scale = blueprint.original_scale / Utils.game.camera.zoom
	call_deferred("validate")

func _process(delta: float) -> void:
	fking_delay -= delta
	position = player.position_on_screen
	
	var old_pos := cursor_offset.global_position
	var rot: int
	
	if player.using_joypad():
		rot = int(player.is_action_pressed("next_slot")) - int(player.is_action_pressed("prev_slot"))
		if rot != 0:
			try_rot += delta
			if try_rot < 0.05:
				rot = 0
			else:
				try_rot = 0
	else:
		rot = int(player.is_action_just_released("next_slot")) - int(player.is_action_just_released("prev_slot"))
	
	if player.using_joypad():
		var move: Vector2
		move = Vector2(
			Input.get_action_strength(player.get_p_action("look_right")) - Input.get_action_strength(player.get_p_action("look_left")),
			Input.get_action_strength(player.get_p_action("look_down")) - Input.get_action_strength(player.get_p_action("look_up"))
		)
		cursor.position += move * delta * 500
	elif not rotate_mode:
		cursor.position = player.to_local(player.get_mouse_pos()) / Utils.game.camera.zoom
	
	if rotate_mode:
		rotate_delay += delta
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			interact()
			if finished:
				return
		else:
			var angle: float = blueprint.angle
			var target_angle: float = cursor.get_local_mouse_position().angle()
			
			if target_angle != angle and rotate_delay >= 0.2:
				blueprint.angle = target_angle
				validate()
		
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			rotate_mode = false
			rotate_delay = 0
	elif rot != 0:
		blueprint.angle += rot * PI/24
		validate()
	
	var player_moved: bool = player.global_position != prev_player
	if cursor_offset.global_position != old_pos or player_moved:
		blueprint.on_moved()
	
	var pos: Vector2 = get_viewport().canvas_transform.affine_inverse() * (cursor.global_position)
	building_detector.global_position = pos
	
	if align:
		cursor_offset.global_position = get_viewport().canvas_transform * (align.global_position + align.get_align_offset(pos - align.global_position))
	else:
		cursor_offset.position = Vector2()
	
	if cursor_offset.global_position != old_pos or player_moved:
		validate()
	
	if error != OK:
		cursor.self_modulate = Color.RED
		blueprint.set_can_build(false)
		
		why_cant.show()
		why_cant.global_position = blueprint.global_position + Vector2.RIGHT * 100 + Vector2.UP * why_cant.size.y * 0.5
		match error:
			ERROR_UNKNOWN:
				why_cant.text = "Unknown error"
			ERROR_OUTSIDE:
				why_cant.text = "Building outside available range"
			ERROR_TERRAIN:
				why_cant.text = "Building overlaps terrain"
			ERROR_PLAYER:
				why_cant.text = "Building overlaps player"
			ERROR_BUILDING:
				why_cant.text = "Building overlaps another building"
			ERROR_BLUEPRINT:
				why_cant.text = "Building overlaps construction site"
			ERROR_ENEMY:
				why_cant.text = "Building overlaps enemy"
			ERROR_GATE:
				why_cant.text = "Gate too close to another gate"
			DEMOLISH_NONE:
				why_cant.text = "No building to demolish"
			DEMOLISH_INVALID:
				why_cant.text = "Not placed by player"
	else:
		if align:
			cursor.self_modulate = Color.GREEN
		else:
			cursor.self_modulate = Color.CYAN
		blueprint.material = null
		
		blueprint.set_can_build(true)
		why_cant.hide()
	
	prev_player = player.global_position

func validate():
	unred()
	
	if blueprint.has_meta("demolish"):
		error = blueprint.get_error()
	
	var rects1: Array
	var rects2: Array
	
	var bounding_rect: Sprite2D = blueprint.bounding_rect
	var ground_rect: Sprite2D = blueprint.ground_rect
	var edge_line: Line2D = blueprint.get_node_or_null("TerrainDetectionEdge")
	
	if bounding_rect:
		if bounding_rect.get_child_count() > 0:
			for rect in bounding_rect.get_children():
				rects1.append(RotatedRect.new(Rect2(
					get_viewport().canvas_transform.affine_inverse() * (rect.global_position),
					rect.texture.get_size() * rect.global_scale * 0.5 / get_viewport().canvas_transform.get_scale()
				), rect.global_rotation))
		else:
			rects1.append(RotatedRect.new(Rect2(
				get_viewport().canvas_transform.affine_inverse() * (bounding_rect.global_position),
				bounding_rect.texture.get_size() * bounding_rect.global_scale * 0.5 / get_viewport().canvas_transform.get_scale()
			), bounding_rect.global_rotation))
	else:
		rects1.append(RotatedRect.new(Rect2(
			get_viewport().canvas_transform.affine_inverse() * (blueprint.global_position),
			blueprint.get_size() * 0.5
		), blueprint.global_rotation))
	
	if ground_rect:
		if ground_rect.get_child_count() > 0:
			for rect in ground_rect.get_children():
				rects2.append(RotatedRect.new(Rect2(
					get_viewport().canvas_transform.affine_inverse() * (rect.global_position),
					rect.texture.get_size() * rect.global_scale * 0.5 / get_viewport().canvas_transform.get_scale()
				), rect.global_rotation))
		else:
			rects2.append(RotatedRect.new(Rect2(
				get_viewport().canvas_transform.affine_inverse() * (ground_rect.global_position),
				ground_rect.texture.get_size() * ground_rect.global_scale * 0.5 / get_viewport().canvas_transform.get_scale()
			), ground_rect.global_rotation))
	
	var has_non_empty_rect: bool
	for rect in rects1:
		if rect.has_area():
			has_non_empty_rect = true
			break
	
	for rect in rects2:
		if rect.has_area():
			has_non_empty_rect = true
			break
	
	if not has_non_empty_rect:
		return
	
	var edges: PackedVector2Array
	if edge_line:
		for point in edge_line.points:
			edges.append(get_viewport().canvas_transform.affine_inverse() * (edge_line.global_position + point))
	
	var socket: Vector2 = get_viewport().canvas_transform.affine_inverse() * (blueprint.global_position)
	if blueprint.socket:
		socket += blueprint.socket.position.rotated(blueprint.rotation) * blueprint.original_scale
	error = are_rects_occupied(blueprint, socket, rects1, rects2, edges)
	
	if blueprint.socket:
		blueprint.socket.modulate = Color.RED if error == ERROR_OUTSIDE else Color.WHITE

var interacted: bool

func interact():
	if fking_delay > 0:
		return
	
	interacted = true
	if error:
		return
	
	if not rotate_mode and not player.using_joypad() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		rotate_mode = true
		return
	
	player.last_build_angle = blueprint.angle
	
	Utils.play_sample("res://SFX/Building/InterfaceAccept.wav")
	var created_building: Node2D = load(blueprint.building_data.scene).instantiate()
	if created_building is BaseBuilding:
		created_building.angle = blueprint.angle
		created_building.owning_player_id = player.player_id
	else:
		created_building.rotation = blueprint.angle
		created_building.set_meta("in_construction", true)
	
	if player.is_action_pressed("run"):
		var building2 := blueprint.duplicate()
		blueprint.set_meta("choosen_one", true)
		emit_signal("place", created_building, blueprint)
		
		if not player.build_menu.is_building_available(blueprint.building_data):
			finish_building()
			building2.queue_free()
			return
		
		rotate_delay = 0
		cursor_offset.add_child(building2)
		blueprint = building2
		blueprint.set_as_preview()
		
		var rot = blueprint.rotation
		blueprint.rotation = 0
		blueprint.angle = rot
	else:
		blueprint.set_meta("choosen_one", true)
		emit_signal("place", created_building, blueprint)
		finish_building()

func finish_building():
	finished = true
	Utils.game.map.post_process.stop_build_mode(blueprint.position)
	set_process(false)
	queue_free()

func interact_continuous():
	if interacted and blueprint.is_multibuild():
		interact()

func cursor_entered(area: Area2D):
	if area == blueprint:
		return
	
	if area is BaseBuilding:
		align = area

func cursor_exited(area: Area2D):
	if area == align:
		align = null

func _exit_tree() -> void:
	building_detector.queue_free()
	unred()

static func are_rects_occupied(build: Node2D, socket_pos: Vector2, rects: Array, alternate_rects := [], edges := PackedVector2Array()) -> int:
	var ret: int = ERROR_UNKNOWN
	
	for expander in Utils.get_tree().get_nodes_in_group("range_expander"):
		if expander == build or not expander.has_meta("range_expander_radius"):
			continue
		
		var rad: float = expander.get_meta("range_expander_radius")
		if socket_pos.distance_to(expander.global_position) <= rad:
			ret = OK
			break
	
	for expander in Utils.get_tree().get_nodes_in_group("temporary_expander"):
		if expander == build or not expander.has_meta("range_expander_radius"):
			continue
		
		var rad: float = expander.get_meta("range_expander_radius")
		if socket_pos.distance_to(expander.global_position) <= rad:
			ret = OK
			break
	
	if ret != OK:
		return ERROR_OUTSIDE
	
	var has_non_empty_rect: bool
	for rect in rects:
		if rect.has_area():
			has_non_empty_rect = true
			break
	
	if not has_non_empty_rect:
		for rect in alternate_rects:
			if rect.has_area():
				has_non_empty_rect = true
				break
	
	if not has_non_empty_rect:
		return OK
	
	for rect in rects:
		ret = is_rect_occupied(build, rect)
		if ret != OK:
			return ret
	
	var check_edges := true
	if not edges.is_empty():
		check_edges = false
		
		for i in edges.size() - 1:
			var p1 := edges[i].rotated(rects.front().rotation)
			var p2 := edges[i + 1].rotated(rects.front().rotation)
			
			if Utils.game.map.pixel_map.rayCastQTFromTo(p1, p2, Utils.player_bullet_collision_mask, true, true):
				return ERROR_TERRAIN
	
	if alternate_rects.size()>0:
		for rect in alternate_rects:
			ret = is_rect_occupied_terrain(build, rect, true)
			if ret != OK:
				return ret
	else:#jak nie ma zadnego ground recta to trzeba sprawdzic z bounding jako terenowym
		for rect in rects:
			ret = is_rect_occupied_terrain(build, rect, true)
			if ret != OK:
				return ret
	
	return ret

static func make_nodes2d_red_if_in_oriented_rect(tracker: Nodes2DTrackerMultiLvl, rect: Rect2, rect_angle: float):
	var nodes = tracker.getTrackingNodes2DInOrientedRect(rect, rect_angle, true)
	if not nodes.is_empty():
		for node in nodes:
			make_red(node)
		return true
	return false

static func is_rect_occupied(build: Node2D, rect: RotatedRect) -> int:
	if not rect.has_area():
		return OK
	
	var rect_to_check := Rect2(rect.position - rect.size, rect.size * 2)
	
	if make_nodes2d_red_if_in_oriented_rect(Utils.game.map.common_buildings_tracker, rect_to_check, rect.rotation):
		return ERROR_BUILDING
	
	if make_nodes2d_red_if_in_oriented_rect(Utils.game.map.gate_buildings_tracker, rect_to_check, rect.rotation):
		return ERROR_BUILDING
	
	if make_nodes2d_red_if_in_oriented_rect(Utils.game.map.power_expander_buildings_tracker, rect_to_check, rect.rotation):
		return ERROR_BUILDING
	
	if make_nodes2d_red_if_in_oriented_rect(Utils.game.map.turret_buildings_tracker, rect_to_check, rect.rotation):
		return ERROR_BUILDING
	
	if make_nodes2d_red_if_in_oriented_rect(Utils.game.map.mine_buildings_tracker, rect_to_check, rect.rotation):
		return ERROR_BUILDING
	
	if make_nodes2d_red_if_in_oriented_rect(Utils.game.map.passive_buildings_tracker, rect_to_check, rect.rotation):
		return ERROR_BUILDING
	
	if make_nodes2d_red_if_in_oriented_rect(Utils.game.map.player_tracker, rect_to_check, rect.rotation):
		return ERROR_PLAYER
	
	var on_blueprint: bool
	for node in Utils.get_tree().get_nodes_in_group("blueprints"):
		if build.get("_is_wall_") and node.get("_is_wall_"):
			continue
		
		if not node.visible:
			continue
		
		var rect1 := Rect2(rect.position - rect.size, rect.size * 2)
		var rect2: Rect2 = node.get_bounds()
		
		if node != build and Utils.orientedRectangleOrientedRectangleIntersect(rect.position, rect1.size, build.rotation, node.position, rect2.size, node.rotation):
			if node.has_meta("demolish"):
				continue
			
			on_blueprint = true
			make_red(node)
	
	if on_blueprint:
		return ERROR_BLUEPRINT
	
	if Utils.game.map.enemy_tracker.getTrackingNodes2DInOrientedRect(Rect2(rect.position - rect.size, rect.size * 2), rect.rotation, true):
		return ERROR_ENEMY

	return OK
	
	
static func is_rect_occupied_terrain(build: Node2D, rect: RotatedRect, check_edges: bool) -> int:
	if not rect.has_area():
		return OK
	
	if build.has_method("custom_check"):
		return build.custom_check(rect.position, rect.size, rect.rotation)
	else:
		if check_edges:
			for i in CHECKS_NO_DIAG.size() / 2:
				if Utils.game.map.pixel_map.rayCastQTFromTo(rect.position + (rect.size * CHECKS_NO_DIAG[i * 2]).rotated(rect.rotation), rect.position + (rect.size * CHECKS_NO_DIAG[i * 2 + 1]).rotated(rect.rotation), Utils.player_bullet_collision_mask, true, true):
					return ERROR_TERRAIN
		
		var hist_rect=Rect2(rect.position - rect.size, rect.size * 2)
		var area= hist_rect.get_area()
		var hist=Utils.game.map.pixel_map.get_materials_histogram_rect_rotated(Rect2(hist_rect.position, hist_rect.size),rect.rotation, true)
		var total_pixels=0
		
		for i in 32:
			if i!= Const.Materials.EMPTY && i!= Const.Materials.TAR:
				total_pixels += hist[i]
		if total_pixels/area>0.05:
			return ERROR_TERRAIN
	return OK

static func make_red(node: Node2D, deferred := false):
	if not node.is_in_group("redded"):
		if deferred:
			node.call_deferred("add_to_group", "redded")
		else:
			node.add_to_group("redded")
		node.set_meta("redded_original_color", node.modulate)
		node.modulate = Color.RED

static func unred():
	for node in Utils.get_tree().get_nodes_in_group("redded"):
		node.modulate = node.get_meta("redded_original_color", Color.WHITE)
		node.remove_from_group("redded")

class RotatedRect:
	var position: Vector2
	var size: Vector2
	var rotation: float
	
	func _init(re: Rect2, ro: float):
		position = re.position
		size = re.size
		rotation = ro
	
	func has_area() -> bool:
		return not Rect2(position, size).has_no_area()
	
	func _to_string() -> String:
		return str(Rect2(position, size), "r", rotation)

func update_config():
	$SkalujMnie.scale = Vector2.ONE * Save.config.ui_scale
	$"%Help".visible = Save.config.control_tooltips_visible()
