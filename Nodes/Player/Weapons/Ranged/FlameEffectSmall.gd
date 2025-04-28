extends Line2D
#tool

@export var max_points := 20.0 # (float,3, 50)
@export var min_distance := 5
@export var point_length := 5.0
@export var point_lag := 0.5
@export var point_offset := Vector2(20,0)
var finished: bool

var gravity := Vector2.RIGHT

var previous_points = PackedVector2Array()
var base_points = PackedVector2Array()

func _ready():
	add_to_group("dont_save")
	
	clear_points()
	gravity = Vector2.RIGHT * point_length
	base_points.resize(max_points)
	previous_points.resize(max_points)
	for p in range( max_points ):
		super.add_point(gravity * p + point_offset)
		base_points[p] = gravity * p + point_offset
		previous_points[p] = to_global(base_points[p])

func _physics_process(_delta):
	for p in range( max_points ):
		var direction = (to_local( previous_points[p] ) - base_points[p])
		var ratio = p / max_points
		points[p] = base_points[p] + direction * ratio * point_lag + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * ratio * 10
		previous_points[p] = to_global( points[p] )



