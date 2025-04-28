extends "res://Nodes/Buildings/Turret/GenericTurret.gd"

var shoot_delay: float
@export var projectile_speed := 400.0

@export var base_shoot_delay: float
@onready var base_projectile_speed = projectile_speed

@onready var top := find_child("Top") as Node2D
@onready var shoot_point := top.get_node("ShootPoint") as Node2D
@onready var laser := top.get_node_or_null("ShootPoint/Laser") as Sprite2D
@onready var laser_start := top.get_node_or_null("ShootPoint/LaserStart") as Node2D
@onready var animator: AnimationPlayer = get_node_or_null("AnimationPlayer")

var shoot_timer: float
var looker: Tween
var random_angle := INF
var no_enemy: bool = true
var time_since_last_enemy: float = 100

var setup_complete := false

func _ready() -> void:
	if not hack:
		on_placed()
		
	#todo wywalic naprawia ze moby bija wylaczone turety bez collision shape - dla tych co maja save z wylaczonym 
	var col=get_node("CollisionShape2D")
	if col:
		col.disabled=false
		
	if laser:
		Utils.connect_to_lazy(self)

func on_placed():
	if animator:
		set_process(false)
	else:
		complete_setup()

	angle_to_target = global_rotation

func complete_setup():
	setup_complete = true
#	$ComputerScreen.global_position = global_position + Vector2.UP * 35

func _on_setup_complete(animation):
#	Utils.play_sample(preload("res://SFX/Turret/TurretReady.wav"), self)
	complete_setup()
#	look_for_enemy()

func _physics_process(delta):
	time_since_last_enemy += delta
	
	if not is_running or not setup_complete:
		return

	shoot_timer += delta

	refresh_target_data(shoot_timer >= shoot_delay || shoot_timer == 0)
	
	if not (target is int) and not target:
		look_for_enemy()
		no_enemy = true
		_no_target()
		return

	stop_looking()
	update_targeting_solution(projectile_speed)

	top.global_rotation = lerp_angle(top.global_rotation, angle_to_target, 0.5)
	if has_target_solution:
		if abs(wrapf(top.global_rotation - angle_to_target, -PI, PI)) > lerp(PI/8,PI/60, (target_position - global_position).length()/max_range):
			return

	if no_enemy:
		if time_since_last_enemy >= 3.0:
			Utils.play_sample(preload("res://SFX/Turret/alarm_siren_warning_01.wav"), self)
		
		no_enemy = false
		_target_found()
	
	time_since_last_enemy = 0
	
	if shoot_timer >= shoot_delay:
		_shoot()
		shoot_timer = 0

func _lazy_process():
	if not is_inside_tree():
		return
	
	var ray_start := laser_start.to_global(Vector2(10, 0))
	var ray := Utils.game.map.pixel_map.rayCastQTDistance(ray_start, Vector2.RIGHT.rotated(laser_start.global_rotation), max_range-10,Utils.turret_bullet_collision_mask, true)
	if ray:
		laser.end_point = ray.hit_position
	else:
		laser.end_point = laser_start.global_position+Vector2(max_range,0.0).rotated(laser_start.global_rotation)
	laser.start_point = laser_start.global_position

func look_for_enemy():
	if looker:
		return

	looker = create_tween().set_loops()
	looker.tween_method(Callable(self, "look_random"), 0.0, 1.0, 1.0 + randf()*2.0)
	looker.tween_callback(Callable(self, "set").bind("random_angle", INF))

func look_random(v: float):
	if not is_inside_tree() or not is_running:
		return
	
	if random_angle == INF:
		random_angle = angle_to_target + randf_range(-PI/4, PI/4)
	top.global_rotation = lerp_angle(top.global_rotation, random_angle, 0.01)

func stop_looking():
	if not looker:
		return
	
	looker.kill()
	looker = null

func update_angle():
	rotation = angle

func get_angle() -> float:
	return rotation

func _no_target():
	pass

func _target_found():
	pass

func _shoot():
	pass

func set_disabled(disabled: bool, force := false):
	super.set_disabled(disabled, force)
	set_physics_process(not disabled)
	
	if animator:
		if disabled:
			animator.play("PowerOFF")
			setup_complete = false
			if not force:
				play_animation_sample("PowerOFF")
		else:
			animator.play("PowerON")
			if not animator.is_connected("animation_finished", Callable(self, "_on_setup_complete")):
				animator.connect("animation_finished", Callable(self, "_on_setup_complete").bind(), CONNECT_ONE_SHOT)
			if not force:
				play_animation_sample("PowerON")
		if force:
			animator.advance(99999)
			
func apply_mask(type):
	if type==Const.Materials.STOP:
		type=Const.Materials.LOW_BUILDING
	super.apply_mask(type)
	
func set_mask_power_ON():
	apply_mask(Const.Materials.STOP)
	add_to_group("player_buildings")
	
func set_mask_power_OFF():
	apply_mask(-1)
	if not Save.is_hub():
		remove_from_group("player_buildings")

func play_animation_sample(animation: String):
	var anime: Animation = animator.get_animation(animation)
	for i in anime.get_track_count():
		if anime.track_get_type(i) == Animation.TYPE_AUDIO:
			var time := anime.track_get_key_time(i, 0)
			var sample: AudioStream = anime.track_get_key_value(i, 0).stream
			get_tree().create_timer(time, false).connect("timeout", Callable(Utils, "play_sample").bind(sample, self, 1.2))
			return
