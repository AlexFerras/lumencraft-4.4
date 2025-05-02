extends Node

var is_test_stats_started = false
var timestamp
var mineral_counter
var start_test_wall_counter
var turrets_count
var start_turret_hp

func process_test_stats():
	var time_dict
	var turrets_hp = 0
	if !is_test_stats_started:
		var mineral_counter_scene = load("res://Tools/MineralCounter.tscn")
		mineral_counter = mineral_counter_scene.instantiate()
		Utils.game.map.add_child(mineral_counter)
		is_test_stats_started = true
		time_dict = OS.get_time()
		timestamp = Time.get_ticks_msec()
		start_test_wall_counter = mineral_counter.ingame_calculate_walls()
		var turrets = get_tree().get_nodes_in_group("defense_tower")
		turrets_count = len(turrets)
		for turret in turrets:
			turrets_hp += turret.hp
		start_turret_hp = turrets_hp
		print("[%d:%d:%d] START COLLECTING TEST DATA" % [time_dict.hour, time_dict.minute, time_dict.second])
		print("SUM OF WALL DEF: %d" % start_test_wall_counter)
		print("NUMBER OF TURRETS: %d" % turrets_count)
		print("Sum of turrets HP: %d" % turrets_hp)
		print("Reactor HP: %d" % Utils.game.core.hp)
	else:
		time_dict = OS.get_time()
		timestamp = Time.get_ticks_msec() - timestamp
		var turrets = get_tree().get_nodes_in_group("defense_tower")
		for turret in turrets:
			turrets_hp += turret.hp
		print("[%d:%d:%d] STOP TEST" % [time_dict.hour, time_dict.minute, time_dict.second])
		print("~~~~STATISTICS~~~~:")
		print("Time: %d ms" % timestamp)
		print("Wall destroyed sccore: %d" % (start_test_wall_counter - mineral_counter.ingame_calculate_walls()))
		print("Destroyed turrets: %d" % (turrets_count - len(turrets)))
		print("Dealt dmg to turrets: %d" % (start_turret_hp - turrets_hp))
		print("Reactor hp left: %d" % Utils.game.core.hp)

