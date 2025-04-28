extends GenericStateEnemy

var is_first_spawn = true
var spawning = false
var can_spawn = false

var spawn_swarm_root: Node2D
var spawn_swarm_scene := preload("res://Nodes/Enemies/MegaSwarm/KingSpawnSwarm.tscn")
#var spawn_swarm_scene := preload("res://Nodes/Enemies/MegaSwarm/WormSwarm_lvl1.tscn")
var spawn_swarm = null
@onready var spawn_swarm_position := $Sprite2D/SpawnSwarmPosition
@onready var spawn_swarm_timer := $SwarmSpawnTimer
@export var spawn_swarm_cooldown := 45.0 # For first spawn cooldown you need to change Timer node


func _ready():
	stuck_ticks_limit_frames = 5
	spawn_swarm_root = Utils.game.map
	spawn_swarm_timer.connect("timeout", Callable(self, "_on_SwarmSpawnTimer_timeout"))
	
func _process(delta):
	pass

func state_global(delta: float):
	super.state_global(delta)
	if state == "state_attack":
		sprite.rotation = lerp_angle(sprite.rotation, angle, 0.025)
	if is_walking:
		sprite.rotation = lerp_angle(sprite.rotation, angle, 0.05)
	
	if targeting.has_target and spawn_swarm_timer.time_left == 0 and !can_spawn:
		spawn_swarm_timer.start()
		
	if can_spawn and state != "state_spawn":
		set_state("state_spawn")

func state_attack(delta: float):
	super.state_attack(delta)
	if enter_state:
		Utils.play_sample("res://SFX/Enemies/King/king_attack.wav", audio_player, false, 1, 1)

func state_spawn(delta: float):
	if enter_state:
		Utils.play_sample("res://SFX/Enemies/nest_open.wav", audio_player, false, 1, 1)
		is_custom_animation_playing = true
		#animator.play("roar")
		animator.play("spawn")
	if await animator.animation_finished:
		can_spawn = false
		is_custom_animation_playing = false
		if targeting.has_target:
			set_state("state_follow_target")
		else:
			set_state("state_idle")

func state_die(delta: float):
	super.state_die(delta)
	if enter_state:
		SteamAPI.increment_stat("KilledBosses")
		Utils.play_sample("res://SFX/Enemies/King/king_death.wav", audio_player, false, 1, 1)

func do_walk_audio():
	if !walking_audio.playing:
		step()

func step():
	Utils.play_sample(Utils.random_sound("res://SFX/Misc/slime"), walking_audio, false, 1.3, 1.3)

func _spawn_swarm():
	if !spawn_swarm or !is_instance_valid(spawn_swarm):
		is_first_spawn = true
		spawn_swarm = spawn_swarm_scene.instantiate()
		spawn_swarm.prioritize_player = true
		spawn_swarm.how_many = 0
	spawn_swarm.how_many += 10
	spawn_swarm.position = spawn_swarm_position.global_position
	spawn_swarm.rotation = spawn_swarm_position.rotation
	if is_first_spawn:
		is_first_spawn = false
		spawn_swarm_root.add_child(spawn_swarm)

func _on_SwarmSpawnTimer_timeout():
	spawn_swarm_timer.wait_time = spawn_swarm_cooldown
	can_spawn = true
