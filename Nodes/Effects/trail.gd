extends Line2D
#tool

enum MODE {NONE,RANDOM, CONSTANT, SWIRL}

@export var mode: MODE = MODE.RANDOM
@export var gravity := Vector2.UP * 0.02
@export var random_gravity := false
@export var die_width_increase := 0.0
@export var random_mul := 20.0
@export var max_points := 20.0 # (float,3, 50)
@export var olding := 0.05
@export var max_random := 0.01
@export var min_distance := 5
@export var fadeout_random := Vector2(0.3, 1.0)
@export var bake := false: set = bake_texture_from_gradient

var point_age := [0.0]
var point_rand := [Vector2(0.0,0.0)]
var finished: bool
var offset: Vector2

func bake_texture_from_gradient(_what):
	var tex_width = 128
	var image = Image.new()
	image.create(tex_width, 1, false, Image.FORMAT_RGBAF)
	false # image.lock() # TODOConverter3To4, Image no longer requires locking, `false` helps to not break one line if/else, so it can freely be removed
	
	for i in tex_width:
		var ofs = float(i) / (tex_width - 1)
		image.set_pixel(i, 0, gradient.sample(ofs))
	false # image.unlock() # TODOConverter3To4, Image no longer requires locking, `false` helps to not break one line if/else, so it can freely be removed
	
	var imageTexture = ImageTexture.new()
	imageTexture.create_from_image(image) #,Texture2D.FLAG_FILTER
	material.set_shader_parameter("grad", imageTexture)

func _ready():
	add_to_group("dont_save")
	
	if not Engine.is_editor_hint():
		get_parent().connect("tree_exiting", Callable(self, "stop"))
	
	if random_gravity:
		gravity=gravity.rotated(randf()*TAU)
	offset = position
	set_as_top_level(true)
	clear_points()

func stop():
	finished = true
	get_parent().remove_child(self)
	Utils.game.map.call_deferred("add_child", self)
	
	var seq := Utils.create_tween()
	seq.tween_property(self, "modulate:a", 0.0, randf_range(fadeout_random[0], fadeout_random[1]))
	seq.tween_callback(Callable(self, "queue_free"))

func _physics_process(_delta):
	if !finished:
		add_point(get_parent().global_position + offset.rotated(get_parent().rotation))
		repair_tables()
	elif die_width_increase:
		width+=die_width_increase
	var rand_vector := Vector2(1, 0).rotated(randf_range(0, TAU))
	
	match mode:
		MODE.NONE:
			for p in range(get_point_count() -1):
				point_age[p] += olding
		MODE.RANDOM:
			for p in range(get_point_count() -1):
				point_age[p] += olding
				rand_vector = Vector2(randf_range(-1, 1), randf_range(-1, 1))
				points[p] += (gravity + ((random_mul * rand_vector) * point_age[p]).limit_length(max_random))
		MODE.SWIRL:
			for p in range(get_point_count() -1):
				point_age[p] += olding
				rand_vector += rand_vector.rotated(1.6180 * 3.0)
				points[p] += (gravity + ((random_mul * rand_vector) * point_age[p]).limit_length(max_random))
		MODE.CONSTANT:
			for p in range(get_point_count() -1):
				point_age[p] += olding
				rand_vector = point_rand[p]
				points[p] += (gravity + ((random_mul * rand_vector) * point_age[p]).limit_length(max_random))

func add_point(point_pos: Vector2, at_pos := -1):
	if len(points) > 1 and points[-2].distance_to(point_pos) < min_distance:
			#points[0]-=point_pos-points[-2] #eliminates jumpy gradient when min distance is larger
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
