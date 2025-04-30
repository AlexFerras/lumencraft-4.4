extends Node
class_name TargetController

@onready var parent := get_parent() as Node2D

var target:Node2D
var primary_target:Node2D

var has_target           := false
var target_is_building   := false

var has_primary_target   := false
var target_is_primary    := false
var target_is_visible    := false
var target_is_in_range   := false
var target_is_in_fov     := false
var target_is_behind_wall     := false

var target_was_visible   := false
var target_last_position := Vector2.ZERO
var target_last_rotation := 0.0

var target_direction := Vector2.ZERO
var target_vector    := Vector2.ZERO
var target_distance  := 0.0
var curret_targetting_flags:int = 0
enum TargetOptions {PLAYER = 1 << 0, PET = 1 << 1, COMMON = 1 << 2, POWER_EXPANDER = 1 << 3, TURRET = 1 << 4, RESOURCE_MINE = 1 << 5}
# (int, FLAGS, "Player", "Pet", "Common", "PowerExpander", "Turret", "ResourceMine") 
@export var TARGET_FLAGS = TargetOptions.PLAYER | TargetOptions.PET | TargetOptions.COMMON | TargetOptions.POWER_EXPANDER | TargetOptions.TURRET | TargetOptions.RESOURCE_MINE
	
# (int, FLAGS, "Player", "Pet", "Common", "PowerExpander", "Turret", "ResourceMine")
@export var WAVE_TARGET_FLAGS = TargetOptions.PLAYER | TargetOptions.PET | TargetOptions.COMMON | TargetOptions.POWER_EXPANDER | TargetOptions.TURRET | TargetOptions.RESOURCE_MINE 
	

@export var target_persistance_duration := 5.0
@export var target_focus_timeout := 10.0 # this must be mutiplayer of target_persistance_duration
var target_focus_timer   := 0.0

@onready var target_persistance_timer   := randf() * target_persistance_duration
	
func validate_target():
#	print(target)
	if not is_instance_valid(target) or not target.is_inside_tree():
		target = null
		has_target = false
		target_is_visible = false
		target_is_building = false
	else:
		if target is BaseBuilding:
			target_is_building = true
			if not target.is_running:
				target = null
				has_target = false
				target_is_visible = false
				target_is_building = false
		else:
			target_is_building = false

func validate_primary_target():
	has_primary_target = true
	if not is_instance_valid(primary_target) or not primary_target.is_inside_tree():
		primary_target = null
		has_primary_target = false
	else:
		if primary_target is BaseBuilding:
			target_is_building = true

func set_primary_target( new_target:Node2D )->void:
#	set_target( new_target)
	primary_target = new_target
	has_primary_target = true
	validate_primary_target()
#	validate_target()
	target_persistance_timer = target_persistance_duration

func set_target( new_target:Node2D )->void:
	target = new_target
	has_target = true
	validate_target()
	target_persistance_timer = target_persistance_duration

func pick_target(delta: float)-> void:
	validate_target()
	if has_primary_target:
		validate_primary_target()
		curret_targetting_flags = WAVE_TARGET_FLAGS
	else:
		curret_targetting_flags = TARGET_FLAGS

	if (has_target or has_primary_target) and target_persistance_timer > 0:
		target_persistance_timer -= delta
	else:
		has_target = false
		var min_distance = INF
		var closest_player:Node2D

		if curret_targetting_flags & TargetOptions.PLAYER:
			
			closest_player = get_closest_player()
			if is_instance_valid(closest_player):
				if is_position_visible(closest_player.global_position, parent.steering.sight_range):
					target_is_visible = true
					min_distance = (closest_player.global_position - parent.global_position).length() - closest_player.radius
					set_target(closest_player)

		var closest_pet:Node2D
		if curret_targetting_flags & TargetOptions.PET:
			closest_pet = get_closest_pet( min_distance )
			if is_instance_valid(closest_pet):
				if is_position_visible(closest_pet.global_position, parent.steering.sight_range):
					target_is_visible = true
					min_distance = (closest_pet.global_position - parent.global_position).length() - closest_pet.radius
					set_target(closest_pet)

		if curret_targetting_flags > TargetOptions.PET:
			var new_target_building = get_closest_building_in_range( min(min_distance, parent.steering.sight_range) ) as Node2D

			if new_target_building:
				set_target(new_target_building)

#		if not target_is_building and not target_is_visible:
		if not target_is_visible:
			if target_focus_timer > 0:
				target_focus_timer -= 5
				if is_instance_valid(target):
					set_target(target)
				elif is_instance_valid(closest_player):
					set_target(closest_player)
			else:
				target_persistance_timer = target_persistance_duration

	if has_target:
		update_target_is_visible()
		if target_is_visible:
			target_focus_timer = target_focus_timeout

func get_closest_player()->Node2D:
	var closest_player:Node2D
	if not Utils.game.players.is_empty():
		var distance:= 0.0
		var min_distance:= INF
		for posiible_player_target in Utils.game.players:
			if not posiible_player_target.dead:
				distance = (parent.global_position - posiible_player_target.global_position).length_squared()
				if distance < min_distance:
					min_distance = distance
					closest_player = posiible_player_target
	return closest_player

func get_closest_pet(search_range: float)->Node2D:
	var closest_pet:Node2D 
	for node in Utils.game.map.pet_tracker.getTrackingNodes2DInCircle( parent.global_position, search_range, true):
		if not node.is_dead:
			var pet_distance = parent.global_position.distance_to(node.global_position) - node.radius
			if pet_distance < search_range:
				search_range = pet_distance
				closest_pet = node
	return closest_pet

#func get_closest_running_node(tracker: Nodes2DTrackerMultiLvl, search_range: float)->Node2D:
#	var closest_building:Node2D 
#	var min_distance_sq := search_range*search_range
#	for node in tracker.getTrackingNodes2DInCircle( parent.global_position, search_range, true):
#		if node.is_running:
#			var building_dist_sq =  (node.global_position - parent.global_position).length_squared() - node.radius*node.radius
#			if building_dist_sq < min_distance_sq:
#				min_distance_sq = building_dist_sq
#				closest_building = node
#
#	return closest_building

func get_closest_building_in_range(search_range:float)->Node2D:
	var building = Utils.game.map.strategic_buildings_group.get_closest_tracking_node2d_in_circle(parent.global_position, search_range, true)
	
	if building and building.is_running:
		return building

	return null

func update_target_data(target_position: Vector2) -> void:
	target_vector = target_position - get_parent().global_position
	target_direction = target_vector.normalized()
	target_distance = target_vector.length()
	if target_is_building:
		target_distance -= target.radius

func update_target_is_visible() -> bool:
	update_target_data(target.global_position)
	
	target_is_primary = false
	if has_primary_target:
		target_is_primary = primary_target == target

	target_is_in_fov = parent.heading.dot(target_direction) >=  parent.steering.sight_fov_dot
	target_is_in_range = target_distance <= parent.steering.sight_range
	target_was_visible = target_is_visible
	target_is_visible = false
	target_is_behind_wall = false
	if target_is_in_fov and target_is_in_range:
		target_is_visible = true
		if target_is_building:
#			if target.is_running:
			var collision := Utils.game.map.pixel_map.rayCastQTDistance(parent.global_position, target_direction, target_distance, ~Utils.monster_sight_mask, false)
			if collision:
				target_is_visible = false
		else:
			var collision := Utils.game.map.pixel_map.rayCastQTDistance(parent.global_position, target_direction, target_distance, Utils.walkable_collision_mask)
			if collision:
				target_is_visible = false
				var material_hit = Utils.get_pixel_material(Utils.game.map.pixel_map.get_pixel_at(collision.hit_position-collision.hit_normal*0.5))
				if Utils.walls_and_gate_mask & (1<<material_hit):
					target_is_behind_wall = true
				

#	target_is_visible = true
	return target_is_visible


func is_looking_at_target(tolerance := 0.01) -> bool:
	return parent.heading.dot(target_direction) >= 1.0 - tolerance

func is_position_visible(pos: Vector2, view_range: float = INF) -> bool:
	var distance  := parent.global_position.distance_to(pos)
	var direction := parent.global_position.direction_to(pos)

	if distance <= view_range:
		var col := Utils.game.map.pixel_map.rayCastQTDistance(parent.global_position, direction, distance, Utils.walkable_collision_mask)
		if col:
			return false
	else:
		return false
	return true

func is_node_visible_in_range(node: Node2D, view_range:float = INF) -> bool:
	return is_position_visible(node.global_position, view_range)


