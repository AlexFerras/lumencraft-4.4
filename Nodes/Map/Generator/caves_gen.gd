@tool
extends ProceduralMapCavesGenerator

@export var material_type= Const.Materials.EMPTY  # (Const.Materials)
@export var my_seed= 0: set = set_seed
@export var keep_scale =false 

func set_seed(newseed):
	if Engine.is_editor_hint():
		print("seed_poszedl")
	
	if not get_parent():
		return
	
#	if newseed == my_seed:
#		return
	my_seed=newseed
	var map_size=get_parent().scale
	var min_map_size = min(map_size.x, map_size.y)

	var map_size_parameters_lerp_t = (clamp(max(map_size.x, map_size.y), 512, 4096) - 512)/(4096-512)

	set_map_bound(Rect2(Vector2(0,0),map_size))
	set_min_angle_between_additional_tunnels(deg_to_rad(22))
	set_chance_to_keep_additional_tunnels(0.24)

	set_max_player_radius(8)

	set_min_reactor_area_radius(120)
	set_max_reactor_area_radius_random_multiplier(lerp(1.1, 1.5, map_size_parameters_lerp_t))

	set_max_boss_radius(16 + int(2*map_size_parameters_lerp_t))
	set_min_boss_spawn_area_radius(40)
	set_max_boss_spawn_area_radius_random_multiplier(lerp(1.1, 1.75, map_size_parameters_lerp_t))
	var num_of_boss_spawn_points: int = 1 + int(3*map_size_parameters_lerp_t+0.5)
	set_num_of_boss_spawn_points(num_of_boss_spawn_points)	
	set_boss_spawn_min_distance_from_reactor(min_map_size/2.5)

	set_min_cave_area_radius(25)
	set_max_cave_area_radius_random_multiplier(lerp(1.5, 2.5, map_size_parameters_lerp_t))
	var num_of_caves: int = 2 + int(map_size.x*map_size.y*0.0000034)
	set_num_of_caves(num_of_caves)

	set_min_mine_area_radius(40)
	set_max_mine_area_radius_random_multiplier(lerp(1.1, 1.75, map_size_parameters_lerp_t))
	var num_of_mines=int(2*map_size_parameters_lerp_t+0.5)

	set_num_of_mines(num_of_mines)
	set_mines_max_distance_from_reactor_area(800.0)
	
	set_min_nest_area_radius(30)
	set_max_nest_area_radius_random_multiplier(lerp(1.1, 1.75, map_size_parameters_lerp_t))
	set_num_of_nests(0)
	
	var min_wave_spawn_area_radius := 60 + int(20*map_size_parameters_lerp_t)
	set_min_wave_spawn_area_radius(min_wave_spawn_area_radius)
	set_max_wave_spawn_area_radius_random_multiplier(lerp(1.2, 1.5, map_size_parameters_lerp_t))
	set_wave_spawn_max_distance_from_reactor_area(800)
	
	var lava_sources_radiuses = [100+int(100*map_size_parameters_lerp_t), 100+int(200*map_size_parameters_lerp_t),100+int(150*map_size_parameters_lerp_t),100+int(250*map_size_parameters_lerp_t), 100+int(100*map_size_parameters_lerp_t)]
	lava_sources_radiuses.resize(min(1+int(map_size_parameters_lerp_t*4+0.5), lava_sources_radiuses.size()))
	set_lava_sources_radiuses(lava_sources_radiuses)
	
	var waves_count = owner.wave_count
	var spawners=[20+int(20*map_size_parameters_lerp_t), 20, 30, 25+int(20*map_size_parameters_lerp_t), 20+int(10*map_size_parameters_lerp_t)]
	spawners.resize(min(1+int(map_size_parameters_lerp_t*3+0.5), min(spawners.size(), max(int(waves_count/10), 1))))

	set_max_mobs_radiuses_for_wave_spawn_points(spawners)

	set_min_distance_between_all_cave_types_multiplier(lerp(0.25, 1.0, map_size_parameters_lerp_t))

	var valid := false
	var fails := 0
	
	for i in 1000:
		valid = generate_new_map(my_seed, true)
		if valid:
			break
		
		fails += 1
		my_seed += 1
		
		if fails == 5:
			fails = 0
			num_of_caves = max(num_of_caves - 1, 0)
			set_num_of_caves(num_of_caves)
			
			if num_of_caves <= 0:
				num_of_boss_spawn_points = max(num_of_boss_spawn_points - 1, 1)
				set_num_of_boss_spawn_points(num_of_boss_spawn_points)
			
			if num_of_boss_spawn_points <= 0:
				min_wave_spawn_area_radius = max(min_wave_spawn_area_radius - 1, 20)
				set_min_wave_spawn_area_radius(min_wave_spawn_area_radius)
	
	queue_redraw()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _draw():
	draw_map(self)
	print("draw_poszedl")

func map_size_changed(new_size):
	var map_size=get_parent().scale
	scale=Vector2.ONE/map_size
	set_map_bound(Rect2(Vector2(0,0),map_size))
	
	if Engine.is_editor_hint():
		set_seed(my_seed)
	
	queue_redraw()
	print("size_poszedl")
