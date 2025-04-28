extends Node2D
class_name ParticleManagerSimple

const MAX_PARTICLES = 10000

@onready var pixel_map := get_parent() as PixelMap

var points_to_spawn: PackedVector2Array
var colors_to_spawn: PackedColorArray
var spawn_velocity: Vector2
var particle_scene: PackedScene

func _ready() -> void:
	add_to_group("dont_save")
	create_particles()
	

func create_particles():
	var particles := particle_scene.instantiate() as GPUParticles2D
	particles.amount = MAX_PARTICLES
	particles.process_material.set_shader_parameter("map_texture", pixel_map.get_texture())
	particles.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(particles)

func get_particles() -> GPUParticles2D:
	return get_child(get_child_count() - 1) as GPUParticles2D

func spawn_particles(points: PackedVector2Array, colors: PackedColorArray, velocity := Vector2()):
	assert(points.size() == colors.size())
	points_to_spawn.append_array(points)
	colors_to_spawn.append_array(colors)
	spawn_velocity = velocity
	call_deferred("flush_spawn")

func flush_spawn():
	if points_to_spawn.is_empty():
		return
	
	if points_to_spawn.size() > MAX_PARTICLES:
		points_to_spawn.resize(MAX_PARTICLES)
		colors_to_spawn.resize(MAX_PARTICLES)
	
	var particles := get_particles()
	var spawn: int = particles.process_material.get_shader_parameter("spawn")
	if spawn + points_to_spawn.size() > MAX_PARTICLES:
		get_tree().create_timer(60).connect("timeout", Callable(particles, "queue_free"))
		create_particles()
		flush_spawn()
		return
	
	apply_shader_values(spawn)
	
	points_to_spawn.resize(0)
	colors_to_spawn.resize(0)



func apply_shader_values(spawn: int):
	var particles := get_particles()
	particles.process_material.set_shader_parameter("spawn2", spawn)
	particles.process_material.set_shader_parameter("spawn", spawn + points_to_spawn.size())
	particles.process_material.set_shader_parameter("emission_texture_points", Utils.create_emission_mask_from_points(points_to_spawn))
	particles.process_material.set_shader_parameter("emission_texture_color", Utils.create_emission_mask_from_colors(colors_to_spawn))
	particles.process_material.set_shader_parameter("emission_texture_point_count", points_to_spawn.size())
	particles.process_material.set_shader_parameter("spawn_velocity", spawn_velocity)

func spawn_in_position(pos : Vector2, amount :int = 100, velocity = Vector2(0,0), color = Color.WHITE):
	var points: PackedVector2Array
	var colors: PackedColorArray
	points.resize(amount)
	colors.resize(amount)
	for i in amount:
		points[i] = pos
		colors[i] = color
	spawn_particles(points,colors,velocity)

func spawn_shell(pos : Vector2, velocity = Vector2(0,0)):
	spawn_in_position(pos, 1, velocity, Color.YELLOW)





