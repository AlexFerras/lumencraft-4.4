extends ParticleManagerSimple

func apply_shader_values(spawn: int):
	var particles := get_particles()
	particles.process_material.set_shader_parameter("spawn2", spawn)
	particles.process_material.set_shader_parameter("spawn", spawn + points_to_spawn.size())
	particles.process_material.set_shader_parameter("emission_texture_points", Utils.create_emission_mask_from_points(points_to_spawn))
	particles.process_material.set_shader_parameter("emission_texture_color", Utils.create_emission_mask_from_colors(colors_to_spawn))
	particles.process_material.set_shader_parameter("emission_texture_point_count", points_to_spawn.size())
	particles.process_material.set_shader_parameter("spawn_velocity", spawn_velocity)

func spawn_in_position(pos : Vector2, amount = 100, velocity = Vector2(0,0), color = Color.WHITE):
	var points: PackedVector2Array
	var colors: PackedColorArray
	points.resize(amount)
	colors.resize(amount)
	for i in amount:
		points[i] = pos
		colors[i] = color
	spawn_particles(points, colors, velocity)
