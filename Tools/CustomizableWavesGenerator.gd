class_name CustomizableWavesGenerator

var waves_enemies_generator = WavesEnemiesGenerator.new()

func clear():
	waves_enemies_generator.clear()

func set_emergency_swarm(enemy: String):
	var enemies_config = Const.Enemies
	var enemy_info = enemies_config.get(enemy)
	if enemy_info:
		var enemy_name = enemy_info.get("name")
		var enemy_threat = enemy_info.get("threat", 10)
		waves_enemies_generator.set_emergency_swarm_enemy_type("Swarm/"+enemy_name, enemy_threat)

func add_new_enemy_type_to_waves_enemies_generator(enemy: String, start_wave_id: int, end_wave_id: int):
	var enemies_config = Const.Enemies
	var enemy_info = enemies_config.get(enemy)
	if enemy_info:
		var enemy_name = enemy_info.get("name")
		var enemy_threat = enemy_info.get("threat", 10)
		if !enemy_name:
			print("There is no enemy name...")
			return;
			
		if enemy_info.get("is_swarm", false):
			waves_enemies_generator.add_new_swarm_enemy_type("Swarm/"+enemy_name, enemy_threat, start_wave_id - 1, end_wave_id - 1)
		else:
			waves_enemies_generator.add_new_state_enemy_type(enemy_name, enemy_threat, start_wave_id - 1, end_wave_id - 1, enemy_threat >= 1000)

func add_new_enemy_type_with_custom_threat_to_waves_enemies_generator(enemy: String, start_wave_id: int, end_wave_id: int, enemy_threat: float):
	var enemies_config = Const.Enemies
	var enemy_info = enemies_config.get(enemy)
	if enemy_info:
		var enemy_name = enemy_info.get("name")
		if !enemy_name:
			print("There is no enemy name...")
			return;
			
		if enemy_info.get("is_swarm", false):
			waves_enemies_generator.add_new_swarm_enemy_type("Swarm/"+enemy_name, enemy_threat, start_wave_id - 1, end_wave_id - 1)
		else:
			waves_enemies_generator.add_new_state_enemy_type(enemy_name, enemy_threat, start_wave_id - 1, end_wave_id - 1, enemy_threat >= 1000)

func set_default_waves_ememies(min_time_between_waves_multiplier: float = 1.0, threat_multiplier: float = 1.0):
	waves_enemies_generator.clear()

	var min_time_between_waves: int = max(10*min_time_between_waves_multiplier, 1.0)
	waves_enemies_generator.set_additional_time_before_first_wave_in_min((25 - min_time_between_waves) if min_time_between_waves<25 else 0)
	waves_enemies_generator.set_min_time_between_waves_in_min(min_time_between_waves)
	waves_enemies_generator.set_additional_time_for_boss_waves_in_min(5)
	waves_enemies_generator.set_additional_threat_for_boss_waves(600*threat_multiplier)

	set_emergency_swarm("Strong Spider Swarm")

	add_new_enemy_type_to_waves_enemies_generator("Spider Swarm", 1, 22)
	add_new_enemy_type_to_waves_enemies_generator("Worm Swarm", 3, 28)
	add_new_enemy_type_to_waves_enemies_generator("Strong Spider Swarm", 5, 48)
	add_new_enemy_type_to_waves_enemies_generator("Flying Swarm", 8, 28)
	add_new_enemy_type_to_waves_enemies_generator("Strong Worm Swarm", 12, 64)
	add_new_enemy_type_to_waves_enemies_generator("Slow Swarm", 14, 48)
	add_new_enemy_type_to_waves_enemies_generator("Explosive Swarm", 18, 48)
	add_new_enemy_type_to_waves_enemies_generator("Shooting Swarm", 16, 28)
	add_new_enemy_type_to_waves_enemies_generator("Flying Shooting Swarm", 22, 64)
	add_new_enemy_type_to_waves_enemies_generator("Strong Flying Swarm", 24, 100)
	add_new_enemy_type_to_waves_enemies_generator("Black Spider Swarm", 28, 100)

	add_new_enemy_type_to_waves_enemies_generator("Arthoma", 5, 100)
	add_new_enemy_type_to_waves_enemies_generator("Suicidoma", 8, 30)
	add_new_enemy_type_to_waves_enemies_generator("Suicacidoma", 10, 30)
	add_new_enemy_type_to_waves_enemies_generator("Acidoma", 10, 100)
	add_new_enemy_type_to_waves_enemies_generator("Gobbler", 16, 100)

	add_new_enemy_type_to_waves_enemies_generator("Crystal GRUBAS", 1, 100)
	add_new_enemy_type_to_waves_enemies_generator("Turtle", 1, 100)
	add_new_enemy_type_to_waves_enemies_generator("King", 11, 100)

func generate_map_waves(seeed: int, spawner_count: int, waves_count: int, threat_multiplier: float, endless: bool):
	waves_count = max(waves_count, 1)

	var first_wave_base_threat: float = 150.0
	var last_wave_base_threat: float = (2150.0-first_wave_base_threat)/pow(9.0/max(waves_count-1.0, 1.0), 2) + first_wave_base_threat

	threat_multiplier = abs(threat_multiplier)
	var waves = waves_enemies_generator.generate_waves_enemies(seeed, waves_count, first_wave_base_threat*threat_multiplier, last_wave_base_threat*threat_multiplier, spawner_count, true)

	if endless and waves:
		waves[-1].repeat = -1
		waves[-1].multiplier = 1.05
	
	return waves

func generate_enemy_group_based_on_wave(seeed: int, wave_id: int, threat_pool: float, boss_wave: bool = false):
	var enemy_group = waves_enemies_generator.generate_enemies_group_based_on_wave(seeed, wave_id-1, threat_pool, boss_wave, false)
	return enemy_group
