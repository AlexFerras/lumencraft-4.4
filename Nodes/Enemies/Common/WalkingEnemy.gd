extends StateEnemy
class_name WalkingEnemy

@export var search_target_radius: float = 150

var random_target: Vector2

func _init() -> void:
	default_state = "look_for_target"

func global_state(delta: float):
	update_position_and_rotation(delta)

func look_for_target(delta: float):
	if not path and timer >= 1:
		random_target = global_position + Utils.random_point_in_circle(100, 50)
		search_path_to(random_target)
		timer = 0
	else:
		follow_path()
	
	var targets = Utils.game.map.player_tracker.getTrackingNodes2DInCircle(global_position, search_target_radius, true)
	
	if not targets.is_empty():
		var max_dist := INF
		for t in targets:
			var dist: float = global_position.distance_squared_to(t.global_position)
			if dist < max_dist:
				target = t
				max_dist = dist
		
		set_state("goto_target")

func goto_target(delta: float):
	pass

func launch_attack(t: Node2D):
	target = t
