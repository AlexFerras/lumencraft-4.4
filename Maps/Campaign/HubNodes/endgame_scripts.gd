extends Node2D

func endgame_start():
	player_ignored()
	get_tree().create_timer(35,false).connect("timeout", Callable(self, "hub_emp"))
	
	Utils.game.map.wave_manager.setup_spawners(get_tree().get_nodes_in_group("wave_spawners"))
	Utils.game.map.wave_manager.set_data_from_file("res://Maps/HubEndWave.cfg")
	Utils.play_sample(Music.Campaign.endgame,$AudioStreamPlayer2dont_touch)
	
	

func hub_emp():
	$"%emp_hub_animator".play("emp_hub")

	Utils.play_sample(Music.Campaign.endgame,$AudioStreamPlayer3dont_touch)

func player_ignored():
	for player in Utils.game.players:
		player.collider.get_child(0).disabled=true
	pass
	

func player_unignored():
	for player in Utils.game.players:
		player.collider.get_child(0).disabled=false
	pass
	

func kill_all_enemies():
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.take_damage_raw({damage = 9999999})

	for swarm_node in Utils.game.map.enemies_group.get_all_swarms_nodes():
		var swarm: Swarm = swarm_node
		swarm.killAllUnits()
	pass

func _process(delta):
	for player in Utils.game.players:
		player.hp = player.get_max_hp()
