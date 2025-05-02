extends MeshInstance3D

var axis : int
var degrees_per_second : float

func _ready():
	axis = randi()%7+1
	degrees_per_second = randf_range(2.0, 4.0)

func _process(delta):
	
	match axis:
		1:
			rotate(Vector3(1,0,0).normalized(), delta * deg_to_rad(degrees_per_second))

		2:
			rotate(Vector3(0,1,0).normalized(), delta * deg_to_rad(degrees_per_second))

		3:
			rotate(Vector3(0,0,1).normalized(), delta * deg_to_rad(degrees_per_second))

		4:
			rotate(Vector3(1,1,0).normalized(), delta * deg_to_rad(degrees_per_second))

		5:
			rotate(Vector3(1,0,1).normalized(), delta * deg_to_rad(degrees_per_second))

		6:
			rotate(Vector3(1,1,1).normalized(), delta * deg_to_rad(degrees_per_second))

		6:
			rotate(Vector3(0,1,1).normalized(), delta * deg_to_rad(degrees_per_second))
