extends Timer

enum GoalType {ANY, ALL, SEQUENCE}

@onready var fail_timer := Utils.game.ui.get_node("%FailTimer") as Control
@onready var survive_timer := Utils.game.ui.get_node("%SurviveTimer") as Control
@onready var score_panel := Utils.game.ui.get_node("TopPanel/%PlayerScore") as Control
@onready var score_label := Utils.game.ui.get_node("TopPanel/%ScoreValue") as Label

@export var objectives: Dictionary

@export var current_goal: int = -1
@export var time_limit: float
@export var initialized: bool
@export var default_objective: String

var target_score: int
var minimum_score: int = 1
var kill_count_dirty := true

func _init() -> void:
	autostart = false

func _ready() -> void:
	set_physics_process(false)
	
	await Utils.game.map_initialized
	var need_score: bool
	var goals_connected: bool
	
	var win_condition: Dictionary = objectives.get("win", {})
	if not win_condition.is_empty():
		match win_condition.type:
			"waves":
				default_objective = "Defeat all waves."
				Utils.game.map.wave_manager.connect("wave_defeated", Callable(self, "check_waves_finished"))
			"item":
				default_objective = tr("Collect %s x %d.") % [tr(Utils.get_item_name({id = win_condition.id, data = win_condition.get("data")})), win_condition.amount]
				connect("timeout", Callable(self, "check_items_collected"))
				start(0.5)
			"finish":
				match win_condition.get("goal_type", GoalType.ANY):
					GoalType.ANY:
						default_objective = "Reach the destination."
					GoalType.ALL:
						default_objective = "Reach all goal points."
					GoalType.SEQUENCE:
						default_objective = get_next_goal_objective()
						if current_goal < 0:
							current_goal = 0
						get_tree().call_group("goals", "set_current_goal", current_goal)
				
				for node in get_tree().get_nodes_in_group("goals"):
					node.connect("goal_entered", Callable(self, "goal_entered").bind(node))
					node.connect("goal_failed", Callable(self, "goal_failed"))
					var marker = preload("res://Nodes/Map/MapMarker/MapMarker.tscn").instantiate()
					marker.max_radius = 99999
					node.add_child(marker)
				goals_connected = true
			"time":
				default_objective = tr("Survive for %02d:%02d.") % [win_condition.time / 60, int(win_condition.time) % 60]
				connect("timeout", Callable(self, "win"))
				start(win_condition.time)
				
				set_physics_process(true)
				survive_timer.show()
				survive_timer.set_meta("text", survive_timer.text)
			"building":
				add_to_group("construction_observers")
				default_objective = tr("Build %s.") % tr(win_condition.target_building)
			"technology":
				Utils.subscribe_tech(self, win_condition.target_tech)
				default_objective = tr("Research %s.") % tr(Const.Technology[win_condition.target_tech].name)
			"enemy":
				add_to_group("kill_observers")
				default_objective = tr("Kill %s x %s.") % [tr(win_condition.target_enemy), win_condition.amount]
			"genocide":
				add_to_group("kill_observers")
				default_objective = "Kill all enemies." ## TODO: wyświetlać ile zostało
				connect("timeout", Callable(self, "check_enemies_alive"))
				start(0.5)
				
				var locator = preload("res://Nodes/Objects/Helper/EnemyLocator.tscn").instantiate()
				locator.wave_only = false
				Utils.game.add_child(locator)
			"score":
				target_score = win_condition.amount
				default_objective = tr("Get score of %s.") % target_score
				need_score = true
			"custom":
				default_objective = win_condition.message
			"none":
				return
			_:
				assert(false, "Error type: " + win_condition.type)
	
	Utils.game.ui.set_objective(0, default_objective)
	Utils.game.set_meta("_default_objective_", default_objective)
	
	if not goals_connected:
		for node in get_tree().get_nodes_in_group("goals"):
			node.connect("goal_entered", Callable(node, "destroy"))
	
	var fail_condition: Dictionary = objectives.get("fail", {})
	if not fail_condition.is_empty():
		if not fail_condition.reactor and Utils.game.core:
			Utils.game.core.set_meta("no_lose", true)
		
		if "time_limit" in fail_condition:
			set_physics_process(true)
			fail_timer.show()
			fail_timer.set_meta("text", fail_timer.text)
			
			if time_limit == 0:
				time_limit = fail_condition.time_limit
		
		if "min_score" in fail_condition:
			minimum_score = fail_condition.min_score
			need_score = true
	
	var scoring: Dictionary = objectives.get("scoring", {})
	if not scoring.is_empty():
		if not initialized:
			Save.scoreboard._starting_score = scoring.starting_score
			Save.score = scoring.starting_score
		
		await get_tree().process_frame # Potrzebne, bo startowe technologie itp
		Utils.game.map.scoring_rules = Utils.merge_dicts({_clear_bonus = objectives.scoring.clear_bonus}, objectives.scoring.table)
	
	if need_score:
		subscribe_to_score()
	
	initialized = true

func _physics_process(delta: float) -> void:
	if time_limit > 0:
		time_limit -= delta
		fail_timer.text = tr(fail_timer.get_meta("text")) % [int(ceil(time_limit) / 60), int(ceil(time_limit)) % 60]
		if time_limit <= 0:
			Utils.game.game_over("Time up")
	
	if survive_timer.visible:
		survive_timer.text = tr(survive_timer.get_meta("text")) % [int(ceil(time_left) / 60), int(ceil(time_left)) % 60]

func check_waves_finished():
	if Utils.game.map.wave_manager.is_finished():
		win()

func check_items_collected():
	for player in Utils.game.players:
		if player.get_item_count(objectives.win.id, objectives.win.get("data")) >= objectives.win.amount:
			win()
			stop()

func win():
	if Save.map_completed:
		return
	
	survive_timer.hide()
	stop()
	
	if objectives.get("auto_finish"):
		Utils.game.win("")
		Utils.game.ui.show_result(true)
	else:
		Utils.game.win()

func get_next_goal_objective() -> String:
	for goal in get_tree().get_nodes_in_group("goals"):
		if goal.index == current_goal:
			if not goal.message.is_empty():
				return goal.message
			break
	
	return "Reach the next goal."

func goal_entered(goal: Node2D):
	match objectives.win.get("goal_type", GoalType.ANY):
		GoalType.ANY:
			get_tree().call_group("goals", "destroy")
			win()
		GoalType.ALL:
			goal.destroy()
			if get_tree().get_nodes_in_group("goals").size() == 1:
				win()
		GoalType.SEQUENCE:
			current_goal += 1
			get_tree().call_group("goals", "set_current_goal", current_goal)
			if current_goal == get_tree().get_nodes_in_group("goals").size():
				win()
			else:
				var message := get_next_goal_objective()
				if message != Utils.game.ui.objective_text:
					Utils.game.ui.set_objective(0, message, true)

func goal_failed():
	current_goal = 0
	get_tree().call_group("goals", "set_current_goal", current_goal)

func subscribe_to_score():
	score_panel.show()
	update_score()
	Save.connect("score_updated", Callable(self, "update_score"))

func update_score():
	if Save.score < 0:
		score_label.text = "%010d" % Save.score
		score_panel.modulate = Color("6600ff")
	else:
		score_label.text = " %010d" % Save.score
		score_panel.modulate = Color("00cbff")
	
	if target_score > 0 and Save.score >= target_score:
		win()
	
	if minimum_score < 1 and Save.score < minimum_score:
		Utils.game.game_over("Minimum score not met")

func building_placed(building_name: String):
	if building_name == objectives.win.target_building:
		win()

func enemy_killed(enemy_name: String):
	if objectives.win.type == "enemy":
		if enemy_name == objectives.win.target_enemy:
			objectives.win.amount -= 1
			if objectives.win.amount == 0:
				win()
	else:
		kill_count_dirty = true

func check_enemies_alive():
	if not kill_count_dirty:
		return
	kill_count_dirty = false

	var living_enemies: int = Utils.game.map.enemy_tracker.nrOfTrackingObjects() + Utils.game.map.enemies_group.num_of_all_swarms_units(true)
	
	if living_enemies == 0:
		win()

func _tech_unlocked(tech: String):
	if tech == objectives.win.target_tech:
		win()
