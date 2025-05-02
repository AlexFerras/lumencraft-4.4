extends VBoxContainer

func _ready() -> void:
	set_physics_process(false)
	
	for child in get_children():
		if child is Label:
			child.set_meta("text", child.text)

func _on_CheckBox_toggled(button_pressed: bool) -> void:
	set_physics_process(button_pressed)

func _physics_process(delta: float) -> void:
	var regular_in_tree = 0
	var regular_in_tracker = Utils.game.map.enemy_tracker.nrOfTrackingObjects()
	var regular_in_wave = 0
	var swarm_in_tree = 0
	var swarm_in_wave = 0
	var swarm_alive_in_tree = 0
	var swarm_alive_in_wave = 0
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy.is_dead:
			regular_in_tree += 1
	
	for swarm in get_tree().get_nodes_in_group("MegaSwarm"):
		swarm_in_tree += 1
		swarm_alive_in_tree += swarm.getNumOfLivingUnits()
	
	for enemy in get_tree().get_nodes_in_group("__wave_enemies__"):
		if enemy is BaseEnemy and not enemy.is_dead:
			regular_in_wave += 1
		elif enemy is Swarm:
			swarm_in_wave += 1
			swarm_alive_in_wave += enemy.getNumOfLivingUnits()
	
	set_text($AllTree, regular_in_tree + swarm_alive_in_tree)
	set_text($AllWave, regular_in_wave + swarm_alive_in_wave)
	
	set_text($RegularTree, regular_in_tree)
	set_text($RegularTracker, regular_in_tracker)
	set_text($RegularWave, regular_in_wave)
	
	set_text($SwarmCount, swarm_in_tree)
	set_text($SwarmCountWave, swarm_in_wave)
	set_text($SwarmEnemies, swarm_alive_in_tree)
	set_text($SwarmWave, swarm_alive_in_wave)

func set_text(where, what):
	where.text = where.get_meta("text") % what
