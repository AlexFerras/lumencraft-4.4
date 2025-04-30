extends Node
class_name ContextController

var pixelmap: PixelMap
var physics: PixelMapPhysics

var avoid_others_direction := Vector2.ZERO
@export var heading_map_resolution := 5
@export var navigation_fov   := 180.0

var heading_map_resolution_half :int = 0
# perception variables 

@export var sight_fov   := 360.0
@export var sight_range   := 150.0
@export var light_intolerance:= 100.0
#export var smell_range   := 20.0
#export var hearing_range := 50.0

var sight_fov_dot :=  0.0

var direct_interest := 0.0
var direct_danger   := 0.0
var heading_angle_map     := PackedFloat32Array()
#var heading_map     := PoolVectorArray()
var interest_map    := PackedFloat32Array()
var wall_map        := PackedFloat32Array()
var danger_map      := PackedFloat32Array()
var ray_map         := PackedFloat32Array()
var lowest_danger   := 0.0
var max_values_indexes    := PackedInt32Array()
var max_values_count      := 0
var current_heading_index := 0

var continue_moving_bias := 0.15
var current_navigation_mask = ~Utils.monster_attack_mask

var in_light := 0.0

@onready var parent = get_parent()

func _ready() -> void:
	
	sight_fov_dot = 1.0 - (sight_fov / 180.0)  
	
	if heading_map_resolution&1 == 0:
		heading_map_resolution += 1
	heading_map_resolution_half = int(heading_map_resolution * 0.5)
	initialize_maps()
	
func initialize_maps():
	if heading_map_resolution >= 3:
		interest_map.resize(heading_map_resolution)
		danger_map.resize(heading_map_resolution)
		wall_map.resize(heading_map_resolution)
		max_values_indexes.resize(heading_map_resolution)
		ray_map.resize(heading_map_resolution)
		heading_angle_map.resize(heading_map_resolution)
		
		var fov_half = deg_to_rad(navigation_fov) * 0.5
		heading_map_resolution_half = int(heading_map_resolution * 0.5)
		for i in heading_map_resolution:
			interest_map[i] = 0.0
			danger_map[i] = 0.0
			wall_map[i] = 0.0
			max_values_indexes[i] = -1
			heading_angle_map[i] = (float(i - heading_map_resolution_half) / heading_map_resolution_half ) * fov_half
			
			var ray = Vector2.RIGHT.rotated(heading_angle_map[i])
			
			var m = 1.0 / max(abs(ray.x), abs(ray.y))
			var new_ray = ray * m;
			ray_map[i] = new_ray.length()
	else:
		push_error("heading_map_resolution must be >= 3")
	
func avoid(direction_to_target: Vector2, direction: Vector2) -> float:
	var dot = direction_to_target.dot(direction)
	return 1.0 - abs(dot + 0.15)

func flank( direction_to_target: Vector2, direction: Vector2) -> float:
	var dot = direction_to_target.dot(direction)
	return 1.0 - abs(dot - 0.15)

func continue_moving(direction_to_target: Vector2, direction: Vector2) -> float:
	var dot = direction_to_target.dot(direction)
	return dot

func avoid_collision(direction: Vector2, distance: int = 100) -> float:
	if parent.targeting.target_is_visible:
		current_navigation_mask = ~(Utils.monster_base_attack_mask | 1<<Const.Materials.TAR)
	else:
		current_navigation_mask = ~(Utils.monster_base_attack_mask)
	if parent.is_path_through_terrain:
		current_navigation_mask = ~Utils.monster_attack_mask
	else:
		current_navigation_mask = ~Utils.monster_base_attack_mask

	var ray_collision = Utils.game.map.pixel_map.rayCastQTDistance(parent.global_position, direction, distance, current_navigation_mask)
	if ray_collision:
		return 1.0 - (ray_collision.hit_distance / distance)
	return 0.0
	
#	var ray_collision = Utils.game.map.pixel_map.rayCastQTDistance(parent.global_position, direction, distance, current_navigation_mask)
#	if ray_collision:
#
#		var material_hit = Utils.get_pixel_material(Utils.game.map.pixel_map.get_pixel_at(ray_collision.hit_position-ray_collision.hit_normal*0.5))
#		if parent.is_path_through_terrain:
#			if Utils.monster_attack_mask & (1<<material_hit):
#				return 0.0
#		else:
#			if Utils.monster_base_attack_mask & (1<<material_hit):
#				return 0.0
#		return 1.0 - (ray_collision.hit_distance / distance)
#	return 0.0

func handle_light_tolerance():
	add_light_tolerance(check_in_light() * 2)

func check_in_light(distance: int = 1) -> float:
	var light_max :float = 0.0
	var dot :float = 0.0
	for flare in Utils.game.map.flares_tracker.getTrackingNodes2DInCircle(parent.global_position, distance, true):
		light_max = max(light_max,  1.0 / flare.global_position.distance_to(parent.global_position))
		
	for cone_light in Utils.game.map.lights_tracker.getTrackingNodes2DInCircle(parent.global_position, distance, true):
		dot = Vector2.RIGHT.rotated(cone_light.global_rotation).dot( cone_light.global_position.direction_to(parent.global_position) )
		if dot < cone_light.fov_angle/PI:
			continue
		light_max = max(light_max, dot / cone_light.global_position.distance_to( parent.global_position ) )
	return light_max

func avoid_light(direction: Vector2, offset:float = 0.0, distance: int = 1) -> float:
	return 0.0
	var light_dot :float = 0.0
	var dot :float = 0.0
	for flare in Utils.game.map.flares_tracker.getTrackingNodes2DInCircle(parent.global_position, distance, true):
		dot = direction.dot( flare.global_position.direction_to(parent.global_position) )
		dot = 1.0 - abs(dot  - offset)
		light_dot = max(light_dot,  dot / flare.global_position.distance_to(parent.global_position))
		
	for cone_light in Utils.game.map.lights_tracker.getTrackingNodes2DInCircle(parent.global_position, distance, true):
		dot = Vector2.RIGHT.rotated(cone_light.global_rotation).dot( cone_light.global_position.direction_to(parent.global_position) )
		if dot < cone_light.fov_angle/PI:
			continue
		dot *= direction.dot( cone_light.global_position.direction_to( parent.global_position ) )
		dot = 1.0 - abs(dot - offset)
		light_dot = max(light_dot, dot / cone_light.global_position.distance_to( parent.global_position ) )
		
	return light_dot

func danger_light(direction: Vector2, offset:float = 0.0, distance: int = 1) -> float:
	return avoid_light(- direction, offset, distance)

func keep_distance(p_target_distance : float, desired_distance: float = 100.0) -> float:
	var weight = max(0, min(p_target_distance - desired_distance, desired_distance) / desired_distance)
	return weight

func seek( vector_to_target: Vector2, distance_to_target: Vector2 ) -> float:
	vector_to_target *= parent.max_speed / distance_to_target
	var force = vector_to_target - parent.velocity
	return force * (parent.max_force / parent.max_speed )

func seek_scalar( direction_to_target: Vector2, direction: Vector2 ) -> float:
	var dot = direction_to_target.dot(direction)
	return (dot + 1.0) / 2.0
	
func navigate( skip_walls := false ) -> void:
	avoid_others_direction = Utils.game.map.enemy_tracker.getAwayVectorFromOtherTrackingNodes( parent, parent.avoid_range )
	var heading_vector = Vector2.ZERO
	
	## importante ------------------- 
	# initialize ALL intrests for go straight
	direct_interest = seek_scalar( parent.destination_direction, parent.heading) + continue_moving_bias
#	in_light = avoid_light( parent.destination_direction, 0.25 )
	direct_interest = max(direct_interest,  in_light * light_intolerance )
	
	# initialize ALL dangers for go straight 
	direct_danger = clamp( parent.destination_direction.dot(- avoid_others_direction), 0, 1)
#	direct_danger = max(direct_danger, danger_light(parent.destination_direction, 0.25 ))
	
	if not skip_walls and not parent.is_attacking:
		direct_danger = max( avoid_collision( parent.destination_direction, parent.avoid_range), direct_danger )
	## -------------------------------
	
	lowest_danger = direct_danger
	for i in heading_map_resolution:
		# Move to target
		heading_vector = parent.heading.rotated(heading_angle_map[i])
		
		interest_map[i] = seek_scalar(parent.destination_direction, heading_vector)
		
#		var new_light = avoid_light(heading_vector, 0.25) 
#		in_light = max(in_light, new_light)
#		interest_map[i] = max(interest_map[i], new_light * light_intolerance)
		
		if not parent.is_attacking:
			interest_map[i] += continue_moving(parent.heading, heading_vector) * continue_moving_bias
		
		# Avoid other dudes
		danger_map[i] = 0
		danger_map[i] = max(heading_vector.dot(-avoid_others_direction), danger_map[i]) 
		
		# Avoid lights
#		danger_map[i] = max(danger_map[i], danger_light(heading_vector, 0.25))

#		# Avoid walls.
		if not skip_walls and not parent.is_attacking and not parent.targeting.target_is_behind_wall and not parent.targeting.target_is_building:
			wall_map[i] = avoid_collision(heading_vector, ray_map[i] * parent.avoid_range)
			danger_map[i] = max(wall_map[i], danger_map[i])
		
		if lowest_danger > danger_map[i]:
			lowest_danger = danger_map[i]
			
#	for i in heading_map_resolution:
#		interest_map[i] += wall_map[heading_map_resolution - 1 - i]
	
	parent.add_rage(in_light * 10)
	add_light_tolerance(in_light * 2)

func navigate_z_faloo() -> Vector2:
	avoid_others_direction = Utils.game.map.enemy_tracker.getAwayVectorFromOtherTrackingNodes( parent, parent.avoid_range )
#	var heading_vector = parent.destination_direction + avoid_others_direction
	
#	in_light = check_in_light()
#	parent.add_rage(in_light * 10)
#	add_light_tolerance(in_light * 2)
	return (parent.destination_direction + avoid_others_direction).normalized()

func angle_difference( angle_1:float, angle_2:float ):
	var angle_diference = fmod( angle_2 - angle_1 + PI, TAU ) - PI
	if angle_diference < -PI:
		angle_diference += TAU
	return angle_diference
	
func get_desired_heading() -> Vector2:
	var max_weight := -INF
	for i in heading_map_resolution:
		if is_equal_approx(danger_map[i], lowest_danger):
			if interest_map[i] > max_weight:
				max_weight = interest_map[i]
				max_values_count = 1
				max_values_indexes[0] = i
			elif interest_map[i] == max_weight:
				max_values_indexes[max_values_count] = i
				max_values_count += 1
	
	if direct_danger == lowest_danger:
		if direct_interest >= max_weight:
			return parent.destination_direction
	
	var max_angle_difference = INF
	var current_angle_difference = 0.0
	for i in max_values_count:
		current_angle_difference = angle_difference( heading_angle_map[max_values_indexes[i]], parent.heading.angle() )
		if abs(current_angle_difference) < max_angle_difference: 
			max_angle_difference = current_angle_difference
			current_heading_index = max_values_indexes[i]
	
	return parent.heading.rotated( heading_angle_map[current_heading_index] )

func get_force_corrected_desired_heading() -> Vector2:
	var new_heading = get_desired_heading()
	var avoidance_ray :Vector2
	var avoidance_vector :Vector2
	for i in heading_map_resolution:
		if danger_map[i] > 0 and not abs(heading_angle_map[i]) == 0:
			avoidance_ray = parent.heading.rotated(heading_angle_map[i])
			avoidance_vector = parent.heading.rotated(-heading_angle_map[i])
			new_heading += danger_map[i] * avoidance_vector * max(0,avoidance_ray.dot(parent.destination_direction))
	
	return new_heading.normalized()
	
func add_light_tolerance( value:float ):
	light_intolerance = max( light_intolerance - value, 0) 
