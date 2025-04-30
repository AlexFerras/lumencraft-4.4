extends BaseEnemy
class_name StateAndWalkEnemy

@onready var sprite := get_node_or_null("Sprite2D")
@onready var animator: AnimationPlayer = get_node_or_null("AnimationPlayer")

# pathing
@export var path_search_inverval := 10.0
@export var path_resolution := 11 # 13 - 1x1px, 12 - 2x2px, 11 - 4x4px, 10 - 8x8, 9 - 16x16, 8 - 32x32,  etc. 
var waypoint_radius := 15.0
var is_path_found: bool = false
var is_path_through_terrain:bool = false
var path_data:PathfindingResultData
var path: Array
var path_index: int
var path_waypoint: Vector2
var pathing_destination: Vector2
var has_path_culling_line_of_sight:= false

# moving
@export var walk_speed := 32.0
#export var arrival_distance := 5.0
@export var animation_travel_distance := 27 # distance traveled by sprite using current sprite sheet and current scale
#var slow_down_radius := 0.0
var current_speed := 0.0
var desired_speed := 0.0
var max_speed := 0.0
const max_force := 10.0

# avoiding and collisions
@export var attack_distance := 10.0
var avoid_range := 15.0
@export var collision_radius := 5.0
#var wall_repulsion_radius := 5.0
var collision_repulsion_radius := 0.0

# stering variables
var angle := 0.0
var heading := Vector2.RIGHT
var velocity: Vector2
var delta_v:  Vector2
var angular_velocity: float

var selected_direction: Vector2

var destination  := Vector2.ZERO
var destination_direction  := Vector2.ZERO
var destination_distance  := 0.0

var default_state: String
var state: String
var state_data: Dictionary

var timer: float
var enter_state: bool
var attacked_by: Node2D
var damaged: bool
var collided: bool

#var is_retreating: bool
var is_walking :bool = false
var is_attacking :bool = false
var is_custom_animation_playing :bool = false
var is_navigation_dissabled :bool = false
var is_rotation_dissabled :bool = false

func _ready() -> void:
	if not is_zero_approx(rotation):
		heading = Vector2.RIGHT.rotated(rotation)
		rotation = 0
	sprite.rotation = heading.angle()
	
	assert(default_state, "Default state not defined. Assign it inside _init().")
	waypoint_radius  = collision_radius * 1.1
#	slow_down_radius = collision_radius
#	wall_repulsion_radius = collision_radius * 2
	avoid_range = radius + collision_radius
#	wall_repulsion_radius = avoid_range
	collision_repulsion_radius = avoid_range - collision_radius 
#	collision_repulsion_radius = wall_repulsion_radius - collision_radius

	override_custom_stat("speed", self, "walk_speed")
	
	max_speed = walk_speed
	set_state(default_state)

func _physics_process(delta)-> void:
#	print(get_process_delta_time())
#	print(get_process_delta_time())
#	if get_process_delta_time() > 0.016:
#		return
	assert(state)
	
	state_global(delta)
	
	enter_state = false
	damaged = false
	attacked_by = null
	collided = false
	timer += delta

func state_global(delta: float):
	call(state, delta)

func set_state(s: String, data := {}):
	assert(has_method(s))
	if s == state:
		return

	state = s
	state_data = data
	set_deferred("enter_state", true)
	timer = 0

func on_hit(data: Dictionary)->void:
	super.on_hit(data)
	Utils.get_audio_manager("gore_hit").play(global_position)
	damaged = true

func set_rotation_custom(rot: float):
	heading = Vector2.RIGHT.rotated(rot)
