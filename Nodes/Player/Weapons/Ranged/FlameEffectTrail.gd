extends Line2D
#tool

@export var random_mul := 20.0
@export var max_points := 20.0 # (float,3, 50)
@export var olding := 0.05
@export var max_random := 0.01
@export var min_distance := 5

var point_age := [0.0]
var point_rand := [Vector2(0.0,0.0)]
var finished: bool
var offset: Vector2
var gravity := Vector2.ZERO

func _ready():
	add_to_group("dont_save")
	
	if not Engine.is_editor_hint():
		get_parent().connect("tree_exiting", Callable(self, "stop"))
	
#	offset = position
	clear_points()

func _physics_process(_delta):
	if !finished:
		add_point_custom(Vector2.ZERO)
		repair_tables()
	var rand_vector := Vector2.RIGHT.rotated(randf_range(0, TAU))
	gravity = Vector2.RIGHT * 60

	for p in range(get_point_count() -1):
		point_age[p] += olding
		rand_vector = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * random_mul
		points[p] += (gravity + (rand_vector * point_age[p]).limit_length(max_random))


func add_point_custom(point_pos: Vector2, at_pos := -1):
	if len(points) > 1 and points[-2].distance_to(point_pos) < min_distance:
		points[-1] = point_pos
	else:
		point_age.append(0.0)
		point_rand.append(Vector2(randf_range(-1, 1), randf_range(-1, 1)))
		super.add_point(point_pos, at_pos)
	
	while get_point_count() > max_points:
		remove_point(0)
		point_age.pop_front()
		point_rand.pop_front()

func repair_tables():
	while get_point_count() > len(point_age):
		point_age.append(0.0)
		point_rand.append(Vector2(randf_range(-1, 1), randf_range(-1, 1)))
