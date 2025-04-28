extends Node2D
class_name ParticleManager

var MAX_PARTICLES = 10000

@onready var pixel_map := get_parent() as PixelMap

var points_to_spawn: PackedVector2Array
var colors_to_spawn: PackedColorArray
var spawn_velocity: Vector2
var particle_scene: PackedScene

var explosion_queue: Array
var particles_to_reset: Dictionary
var repel_create=false

func _init() -> void:
	if Music.is_switch_build():
		MAX_PARTICLES = 500

func _ready() -> void:
	add_to_group("dont_save")
	create_particles()
	
func _process(delta):
	if repel_create:
		process()
	
	for particles in particles_to_reset.keys():
		if not is_instance_valid(particles):
			particles_to_reset.erase(particles)
			continue
		particles_to_reset[particles] -= 1
		
		if particles_to_reset[particles] == 0:
			particles.process_material.set_shader_parameter("explosion_position", Vector2(0,0))
			particles_to_reset.erase(particles)
			
			while not explosion_queue.is_empty():
				var particles2 = explosion_queue.pop_front()
				if is_instance_valid(particles2[0]):
					callv("explode_particles", particles2)
					break

func process():
	var repelers_positions := PackedVector2Array()
	for repeler in get_tree().get_nodes_in_group("repels_debris"):
		repelers_positions.append(repeler.global_position)

	var repelers_positions_texture = Utils.create_emission_mask_from_points(repelers_positions)
	
	var wants_repelers = get_tree().get_nodes_in_group("wants_repelers_texture")
	for particles in wants_repelers:
		particles.process_material.set_shader_parameter("repelers_positions", repelers_positions_texture)
		particles.process_material.set_shader_parameter("repelers_positions_count", repelers_positions.size())

func create_particles():
	var particles := particle_scene.instantiate() as GPUParticles2D
	particles.amount = MAX_PARTICLES
	particles.process_material.set_shader_parameter("map_texture", pixel_map.get_texture())
	particles.process_mode = Node.PROCESS_MODE_ALWAYS
	if Music.is_switch_build():
		particles.lifetime = min(particles.lifetime, 10)
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

func explosion_happened(pos: Vector2, radius: float, strength: float):
	for particles in get_children():
		explode_particles(particles, pos, radius, strength)

func explode_particles(particles: GPUParticles2D, pos: Vector2, radius: float, strength: float):
	if particles in particles_to_reset:
#		explosion_queue.append([particles, pos, radius, strength])
		return
	
	particles.process_material.set_shader_parameter("explosion_position", pos)
	particles.process_material.set_shader_parameter("explosion_radius", radius)
	particles.process_material.set_shader_parameter("explosion_strength", strength)
	particles.process_material.set_shader_parameter("explosion_time", Time.get_ticks_msec() * 0.001)
	particles_to_reset[particles] = 2


func spawn_in_position(pos : Vector2, amount :int = 100, velocity = Vector2(0,0), color = Color.WHITE):
	var points: PackedVector2Array
	var colors: PackedColorArray
	points.resize(amount)
	colors.resize(amount)
	for i in amount:
		points[i] = pos
		colors[i] = color
	spawn_particles(points,colors,velocity)

