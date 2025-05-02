class_name WaveGenerator

const enemies = []
var max_waves
var wait_time

var wave_threat_pull = 0
var current_wave = 0

var max_spawners
var possible_spawners = 1

func initialize(spawner_count := 0):
	wave_threat_pull = 0
	current_wave = 0
	wait_time = 0
	
	if spawner_count > 0:
		max_spawners = spawner_count
	else:
		max_spawners = len(Utils.game.map.get_tree().get_nodes_in_group("wave_spawners"))
		if max_spawners > 0:
			possible_spawners = 1
	_parse_enemy_config()


func _parse_enemy_config():
	var enemies_config = Const.Enemies
	for enemy in enemies_config:
		if enemies_config[enemy].get("threat"):
			if enemies_config[enemy].get("hide_in_editor"):
				pass
			else:
				if enemies_config[enemy].get("is_swarm"):
					enemies.append({
						"name": "Swarm/"+enemies_config[enemy]["name"],
						"threat": enemies_config[enemy]["threat"],
						"is_swarm": true,
						})
				else:
					enemies.append({
						"name": enemies_config[enemy]["name"],
						"threat": enemies_config[enemy]["threat"],
						"is_swarm": false,
						})

func generate_all_waves(waves_number) -> Array:
	initialize()
	max_waves =  waves_number
	var waves = []
	if max_spawners > 0:
		for i in max_waves:
			current_wave = i+1
			wave_threat_pull = super_threat_incrementation_function(current_wave)
			var wave = generate_wave()
			waves.append({"wave_name": random_name(), "wait_time": 1500 if current_wave==1 else wait_time, "enemies": wave, "target": 0, "multiplier":1, "repeat":0})
	return waves

func generate_map_waves(spawner_count: int, waves_number: int, endless: bool):
	initialize(spawner_count)
	max_waves =  waves_number
	var waves = []
	if max_spawners > 0:
		for i in waves_number:
			current_wave = i+1
			wave_threat_pull = super_threat_incrementation_function(current_wave)
			var wave = generate_wave()
			waves.append({"wave_name": random_name(), "wait_time": 1500 if current_wave==1 else wait_time, "enemies": wave, "target": 0, "multiplier":1, "repeat":0})
	
	if endless:
		waves[-1].repeat = -1
		waves[-1].multiplier = 1.05
	
	return waves

func generate_wave() -> Array:
	var t = wave_threat_pull
	var wave = []
	if current_wave % 10 == 0 or current_wave==max_waves:
		wave += get_boss_enemies_entries(wave_threat_pull)
		wave += get_state_enemy_entries(0.2*wave_threat_pull)
	elif current_wave % 4 == 0:
		wave += get_state_enemy_entries(0.5*wave_threat_pull)
	if wave_threat_pull > 0:
		var threat_pull = wave_threat_pull / possible_spawners
		for i in range(possible_spawners):
			var swarm_entry = get_random_swarm_enemy_entry(threat_pull, random_spawner(i, 0.4))
			if swarm_entry["count"] > 0.1:
				wave.append(swarm_entry)
#	prints(current_wave, t, wave)
	return wave

func get_state_enemy_entries(threat_pull):
	var rand
	var initial_threat_pull = threat_pull
	var wave = []
	var state_enemies = get_state_enemies_range_threat(0, threat_pull)
	var state_enemies_count = 0
	var count
	var count_limit = randi() % 10 + 1
	while(!state_enemies.is_empty() and state_enemies_count < count_limit):
		rand = randi() % len(state_enemies)
		count = floor(min(count_limit-state_enemies_count, 1 + randi() % int(floor(threat_pull / state_enemies[rand]["threat"]))))
		wave.append({"name": state_enemies[rand]["name"], "count": count, "spawner": random_spawner(-1, 1.1)})
		threat_pull -= count * state_enemies[rand]["threat"]
		state_enemies_count += count
		state_enemies = get_state_enemies_range_threat(0, threat_pull)
	wave_threat_pull = wave_threat_pull + threat_pull - initial_threat_pull
	return wave


func get_boss_enemies_entries(threat_pull):
	var bosses = get_state_enemies_range_threat(1000, threat_pull)
	var count_limit = floor(current_wave/10)
	var wave = []
	var count = 0
	var rand
	while(!bosses.is_empty() and count < count_limit):
		rand = randi() % len(bosses)
		wave.append({"name": bosses[rand]["name"], "count": 1, "spawner": random_spawner(-1, 1.1)})
		threat_pull -= bosses[rand]["threat"]
		wave_threat_pull -= bosses[rand]["threat"]
		count += 1
		bosses = get_state_enemies_range_threat(1000, threat_pull)
	return wave

func get_random_swarm_enemy_entry(threat_pull, spawner_number):
	var swarm_enemies = get_swarm_enemies()
	var rand = randi() % len(swarm_enemies)
	var count = round(threat_pull/swarm_enemies[rand]["threat"])
	return {"name": swarm_enemies[rand]["name"], "count": count, "spawner": spawner_number}

func random_spawner(biased_spawner, randomness):
	if randf() < randomness:
		return randi() % possible_spawners
	else:
		return biased_spawner

func get_state_enemies_range_threat(min_threat, max_threat):
	var state_enemies = []
	for enemy in enemies:
		if min_threat <= enemy["threat"] and enemy["threat"] <= max_threat and !enemy["is_swarm"]:
			state_enemies.append(enemy)
	return state_enemies

func get_swarm_enemies():
	var swarm_enemies = []
	for enemy in enemies:
		if enemy["is_swarm"]:
			swarm_enemies.append(enemy)
	return swarm_enemies

var previous_threat = 0
func super_threat_incrementation_function(x):
	var friction = floor((current_wave-1)/10)+1
	#return x * 20
	#return 110 * (atan(x/2-5) + PI/2)
	var increment
	if x % 10 == 0:
		increment=800
	elif x % 5 == 0:
		increment=300
	elif x % 2 == 0 and x!=2:
		increment=200
	else:
		increment=100
	previous_threat += friction * increment
	if x % int(max(1, floor(max_waves / max_spawners)))==0:
		possible_spawners += 1
		possible_spawners = max_spawners if possible_spawners > max_spawners else possible_spawners
	return align_random_time() * previous_threat

func align_random_time():
	var minutes = randi() % 11 + 5
	wait_time = minutes * 60
	return 1 + (10 - minutes) * 0.05  

const i = ["Horrible", "Dangerous", "Dark", "Scary", "Creepy", "Shocking", "Abominable", "Awful", "Nasty", "Terrifying", "Threatening", "Eldritch", "Grotesque"]
const j = ["Attack", "Siege", "Battle", "Aggression", "Charge", "Invasion", "Strike", "Skirimish", "Encounter", "Assault"]
const k = ["Huge", "Big", "Gigantic", "Colossal", "Massive", "Heavy"]

func random_name() -> String:
	var string
	if current_wave % 10 == 0 or current_wave == max_waves:
		string = tr(k[randi()%k.size()]) + " " + tr(i[randi() % i.size()]) + " " + tr(j[randi() % j.size()])
	else:
		string = tr(i[randi() % i.size()]) + " " + tr(j[randi() % j.size()])
	return string

func generate_enemy_group(threat_pull):
	if enemies.is_empty():
		_parse_enemy_config()
	var wave_threat_buff = wave_threat_pull
	var current_wave_buff = current_wave
	wave_threat_pull = threat_pull
	current_wave = 10 
	var enemy_group = []
	if threat_pull > 1500:
		enemy_group.append_array(get_boss_enemies_entries(wave_threat_pull))
	enemy_group.append_array(get_state_enemy_entries(wave_threat_pull))
	var swarm = get_random_swarm_enemy_entry(wave_threat_pull, -1)
	if swarm["count"] > 0.1:
		if swarm["count"] > 20:
			swarm["count"]
		enemy_group.append(get_random_swarm_enemy_entry(wave_threat_pull, -1))
	wave_threat_pull = wave_threat_buff
	current_wave = current_wave_buff
	for entry in enemy_group:
		entry.erase("spawner")
	return enemy_group
