@tool
extends Marker2D

@onready var anim := $AnimationPlayer
@onready var marker := $WaveMarker

@export var radius := 150.0: set = set_radius

var prepared: bool
var spawning_swarm: bool
var enemy_queue: Array

signal spawned_enemy(enemy)
signal spawn_ended

func _ready():
	set_process(false)

func _process(delta: float) -> void:
	if spawning_swarm:
		return
		
	if not enemy_queue.is_empty():
		var i := 0
		var enemy: Node2D
		while i < enemy_queue.size():
			enemy = enemy_queue[i]
			var delay = enemy.get_meta("delay", 0)
			if delay > 0:
				enemy.set_meta("delay", delay - delta)
				i += 1
			else:
				break
		
		if i == enemy_queue.size():
			return
		enemy_queue.remove_at(i)
		
		if enemy.has_meta("swarm"):
			spawning_swarm = true
			enemy.position = global_position
			enemy.connect("finished", Callable(self, "set").bind("spawning_swarm", false))
		else:
			while not enemy.position or Utils.game.map.pixel_map.is_pixel_solid(enemy.position, Utils.walkable_collision_mask):
				enemy.position = global_position + Utils.random_point_in_circle(radius)
		
		enemy.add_to_group("__wave_enemies__")
		Utils.game.map.add_child(enemy)
		
		emit_signal("spawned_enemy", enemy)
	else:
		get_tree().create_timer(3.0, false).connect("timeout", Callable(self, "end_spawn"))

func end_spawn():
	anim.play("stop")
	set_process(false)
	prepared = false
	emit_signal("spawn_ended")

func can_spawn() -> bool:
	return not spawning_swarm

func nest_open_sound():
	Utils.play_sample("res://SFX/Enemies/nest_open.wav",global_position)

func prepare_spawn() -> void:
	#sprite.show()
	anim.play("start")
	#sprite.scale = Vector2()
	
	await get_tree().create_timer(3.0, false).timeout
	set_process(true)

func spawn_enemy(enemy: Node2D):
	if not prepared:
		prepare_spawn()
		prepared = true
	
	assert(enemy.position == Vector2())
	
	if enemy is BaseEnemy:
		enemy.tracking_enabled = false
		enemy.connect("ready", Callable(enemy, "launch_attack").bind(Utils.game.main_player if enemy.get_meta("_wave_target_") == 2 or not is_instance_valid(Utils.game.core) else Utils.game.core as Node2D))
	
	enemy_queue.append(enemy)

func spawn_swarm(swarm: Node2D):
	if not prepared:
		prepare_spawn()
		prepared = true
	
	assert(swarm.position == Vector2())
	
	swarm.spawn_radius = radius
	swarm.set_meta("swarm", true)
	
	enemy_queue.append(swarm)

func set_radius(r: float):
	radius = r
	
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_set_transform_matrix(get_global_transform().affine_inverse())
		draw_arc(global_position, radius, 0, TAU, 64, Color.ORANGE, 2)

func is_spawning() -> bool:
	return spawning_swarm or not enemy_queue.is_empty()

func set_random_marker(random: bool):
	if random:
		marker.texture = preload("res://Nodes/Map/MapMarker/QuestionMark.png")
	else:
		marker.texture = preload("res://Nodes/Map/MapMarker/skull_marker.png")
	marker.arrow = marker.texture
