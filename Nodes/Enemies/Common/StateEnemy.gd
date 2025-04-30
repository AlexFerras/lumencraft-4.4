extends BaseEnemy
class_name StateEnemy

@onready var sprite := get_node_or_null("Sprite2D")
@onready var animator: AnimationPlayer = get_node_or_null("AnimationPlayer")

@onready var left_collision_start: Node2D = $Sprite2D/Collisions/LeftStart
@onready var left_collision_end: Node2D = $Sprite2D/Collisions/LeftEnd
@onready var right_collision_start: Node2D = $Sprite2D/Collisions/RightStart
@onready var right_collision_end: Node2D = $Sprite2D/Collisions/RightEnd

@export var path_search_inverval := 10.1
#export var path_search_inverval_random := 1.0
@export var avoid_range := 15.0
@export var waypoint_radius := 15.0
@export var slow_down_radius := 20.0
@export var path_resolution := 13 # 13 - 1x1px, 12 - 2x2px, 11 - 4x4px, 10 - 8x8, 9 - 16x16, 8 - 32x32,  etc. 
@export var walk_speed := 32.0

var has_path_culling_line_of_sight = false
var velocity: Vector2

var default_state: String
var state: String
var state_data: Dictionary
var is_retreating: bool

var timer: float
var enter_state: bool
var damaged: bool
var attacked: Node2D
var collided: bool

var target: Node2D
var is_path_found: bool
var is_path_through_terrain: bool
var path: Array
var path_index: int
var path_waypoint: Vector2

func _ready() -> void:
	assert(default_state, "Default state not defined. Assign it inside _init().")
	set_state(default_state)

func _physics_process(delta: float) -> void:
	assert(state)
	
	global_state(delta)
	call(state, delta)
	
	enter_state = false
	damaged = false
	attacked = null
	collided = false
	timer += delta

func global_state(delta: float):
	pass

func set_state(s: String, data := {}):
	assert(has_method(s))
	if s == state:
		return
	
	state = s
	state_data = data
	set_deferred("enter_state", true)
	timer = 0

func on_hit(data:Dictionary) -> void:
	Utils.play_sample(Utils.random_sound("res://SFX/Bullets/bullet_impact_body_flesh"), self)
	Utils.play_sample(Utils.random_sound("res://SFX/Enemies/Small monster Death"), self, 1.1)
	damaged = true

### Base states
func retreat_to_base(delta: float):
	if enter_state:
		is_retreating = true
	
	if global_position.distance_squared_to(state_data.base.global_position) > 10000:
		if not path:
			search_path_to(state_data.base.global_position)
			return
		follow_path()
	else:
		set_state(default_state)
		is_retreating = false

### High-level logic helpers
func search_path_to_target(type:int = 0):
	if validate_target():
		var target_pos := target.global_position
		if target is BaseBuilding:
			target_pos += target.global_position.direction_to(global_position) * target.radius
		search_path_to(target_pos, type)

func search_path_to(target_position: Vector2, type:int = 0):
	var path_data:PathfindingResultData
	is_path_found = false
	match type:
		0: # search direct path avoiding walls
			path_data = PathFinding.get_path_no_dig_from_to_position(global_position, target_position, path_resolution, true )
		1: # search direct path avoiding walls, or closest point
			path_data = PathFinding.get_path_dig_from_to_position(global_position, target_position, path_resolution, true)
		2: # search shortest path through walls
			path_data = PathFinding.get_path_any_from_to_position(global_position, target_position, path_resolution, true)
	if path_data:
		is_path_through_terrain = path_data.path_goes_through_materials
		has_path_culling_line_of_sight = true
		is_path_found = true
		path = path_data.get_path_custom()
		path_index = 0
		
func follow_path():
	if path.is_empty():
		return
	
	var next_waypoint := get_next_waypoint()
	velocity += seek(global_position, next_waypoint) * 0.05
	velocity += collision_avoidance() * 7.0 + update_avoid_others_in_range(avoid_range) * 0.5
	rotation = lerp_angle(rotation, velocity.angle(), 0.1)

func update_position_and_rotation(delta: float):
	var prev_velocity := velocity
	var position_velocity := physics.custom_physics_step(global_position, velocity, radius - 1, 0.5,Utils.walkable_collision_mask)
	global_position = position_velocity.position
	velocity = position_velocity.size
	
	if not velocity.is_equal_approx(prev_velocity):
		collided = true
	position += velocity * delta
	
	if velocity.length_squared() > 0.1:
		rotation = lerp_angle(rotation, velocity.angle(), 0.1)

### Low-level logic helpers

func is_near_target(distance: float) -> bool:
	if not validate_target():
		return false
	return global_position.distance_squared_to(target.global_position) < distance * distance

func is_looking_at_target(tolerance := 0.01) -> bool:
	if not validate_target():
		return false
	return Vector2.RIGHT.rotated(rotation).dot(global_position.direction_to(target.global_position)) > 1 - tolerance

func is_position_visible(pos: Vector2, view_range: float = INF) -> bool:
	var distance := global_position.distance_to(pos)
	var direction := global_position.direction_to(pos)
	
	if distance <= view_range:
		var col := pixelmap.rayCastQTDistance(global_position, direction, distance, Utils.walkable_collision_mask)
		if col:
			return false
	else:
		return false
	
	return true

func get_waypoint_radius(p_velocity: Vector2) -> float:
	return clamp(waypoint_radius * p_velocity.length() / (walk_speed * 0.5), 10, waypoint_radius)

func get_next_waypoint() -> Vector2:
	var next_waypoint: Vector2 = path[path_index]
	while global_position.distance_to(next_waypoint) < get_waypoint_radius(velocity):
		path_index += 1
		if path_index == path.size():
			path.clear()
			return next_waypoint
		else:
			next_waypoint = path[path_index]
	next_waypoint = path[path_index]
	
	return next_waypoint
	
func cull_path():
	if path_index + 1 < path.size():
		var col := pixelmap.rayCastQTFromTo(global_position, path[path_index+1], Utils.walkable_collision_mask)
		if col:
			has_path_culling_line_of_sight = false
		else:
			path_index += 1
	else:
		has_path_culling_line_of_sight = false

func seek(my_pos: Vector2, target_pos: Vector2) -> Vector2:
	var seek_force: Vector2
	var to_target:= target_pos - global_position
	var desired_velocity := to_target.normalized() * walk_speed
	
	var to_target_length = target_pos.distance_to(my_pos)
	var velocity_factor = 1.0
	if to_target_length < slow_down_radius:
		velocity_factor = to_target_length / slow_down_radius
	
	desired_velocity *= velocity_factor
	seek_force = (desired_velocity - velocity)
	return seek_force

func collision_avoidance() -> Vector2:
	var avoidance_force: Vector2
	var left = physics.raycast(left_collision_start.global_position, left_collision_end.global_position)
#	if not left:
#		left = get_world_2d().direct_space_state.intersect_ray(left_collision_start.global_position, left_collision_end.global_position, [self], Const.ENEMY_COLLISION_LAYER, false, true)
#		if left and left.collider is BaseBuilding:
#			target = left.collider
	
	var right = physics.raycast(right_collision_start.global_position, right_collision_end.global_position)
#	if not right:
#		right = get_world_2d().direct_space_state.intersect_ray(right_collision_start.global_position, right_collision_end.global_position, [self], Const.ENEMY_COLLISION_LAYER, false, true)
#		if right and right.collider is BaseBuilding:
#			target = right.collider
	
	if left:
		avoidance_force += Vector2.DOWN.rotated(rotation)
	
	if right:
		avoidance_force += Vector2.UP.rotated(rotation)
	
	return avoidance_force

func update_avoid_others_in_range(avrange: float) -> Vector2:
	return Utils.game.map.enemy_tracker.getAwayVectorFromOtherTrackingNodes(self, avrange)

func validate_target() -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree():
		target = null
	return target != null
