@tool
extends BaseBuilding

signal lost_power

const IDLE_SPEED = 0.2

@onready var core := $Sprite2D/Core as Node2D
@onready var extract_sound := $reactor_extract as AudioStreamPlayer2D
@onready var ring := $Sprite2D/Ring as Node2D
@onready var fuel_indicator = $FuelIndicator/TextureProgressBar as Range
@onready var hot_coals := $Sprite2D/Hot_coals as Sprite2D
@onready var spawner := $spawner

@onready var range_computer = $Sprite2D/Computer5/GenericComputer
@onready var emp_computer = $Sprite2D/Computer6/GenericComputer

var fuel: float = 100
@export var speed: float = 1
@export var start_on: bool

@export var RANGE = 350
@export var disable_zap: bool
@export var enabled_screens: int = 15 # (int, FLAGS, "1", "2", "3", "4")

@export var level: int = 1

var zap_timer = 0.0
var zap_delay = 1.0
var zap_dmg = 1.0


var timer := 0.0
var emited_particles
var chunk_delivered: bool
var lumen_slots: Node2D

@export var lumen_to_spawn:int = 0
@export var dig_multiplier:float = 1.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	init_range_extender(RANGE)
	add_to_group("Light3D")
	set_disabled(not start_on, true)
	
	if start_on and not Engine.is_editor_hint():
		start()
		$AnimationPlayer.call_deferred("advance", 1000)
	
	Utils.subscribe_tech(self, "zap_upgrade")
	Utils.subscribe_tech(self, "zap_upgrade2")
	Utils.subscribe_tech(self, "zap_upgrade3")
	$Sprite2D/Computer4/GenericComputer.reload()
	
	if enabled_screens > 15:
		enabled_screens = 15
		
	var computer_list = [$Sprite2D/Computer4/GenericComputer, $Sprite2D/Computer6/GenericComputer, $Sprite2D/Computer5/GenericComputer, $Sprite2D/Computer7/GenericComputer]
	for i in 4:
		if not enabled_screens & (1 << i):
			computer_list[i].call_deferred("set_no_item")
			if i == 0:
				computer_list[i].get_node("Icon").position.x = 0

func _tech_unlocked(tech: String):
	super._tech_unlocked(tech)
	if tech == "zap_upgrade":
		zap_delay *= 0.5
	if tech == "zap_upgrade2":
		zap_delay *= 0.5
	if tech == "zap_upgrade3":
		zap_delay *= 0.5

func try_to_connect():
	pass


func dig_for_lumen():
	#if randi() %2==0:
	Utils.play_sample("res://Nodes/Buildings/Storage/bottle_pop.wav",global_position,false, 1.5).volume_db=-5
	Utils.game.map.pickables.spawn_premium_pickable_nice(spawner.global_position, Const.ItemIDs.LUMEN, Vector2.RIGHT.rotated(spawner.global_rotation + randf_range(-1.0, 1.0)) * randf_range(50, 150))

func damage(data: Dictionary):
	super.damage(data)
	if zap_timer>=zap_delay && is_running and not disable_zap:
		zap_timer=0
		var zap=preload("res://Nodes/Effects/Zap/Zap.tscn").instantiate()
		add_child(zap)
		if data.has("projectile"):
#			var ray := Utils.game.map.pixel_map.rayCastQTFromTo(data.projectile.global_position,  global_position, Utils.walkable_collision_mask, true)
#			if ray:
#				zap.global_position=ray.hit_position 
#			else:
			zap.global_position=data.projectile.global_position
			zap.global_rotation=randf_range(0,TAU)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if is_running and not destructed:
		timer += delta
		zap_timer+=delta
#		hot_coals.modulate = Color.from_hsv(sin(timer) / 180.0, - cos(timer) * 0.25 + 0.25, 4.0)
	
	if speed > IDLE_SPEED:
		if speed < IDLE_SPEED + 0.1:
			speed = IDLE_SPEED
		else:
			speed = lerp(speed, IDLE_SPEED, 0.001)
		
	core.rotation += PI * speed * delta
	ring.rotation -= PI * speed * delta

	if !Engine.is_editor_hint():
		if Utils.game.frame_from_start%11==0:
			if lumen_to_spawn>0:
				dig_for_lumen()
				Utils.game.shake(0.2,1.0)
				lumen_to_spawn-=1
				if !extract_sound.playing:
					extract_sound.play(randf_range(0,2222))
			else:
				extract_sound.stop()
#func resource_input(id: int, type: int):
#	if type == Const.ItemIDs.COAL or type == Const.ItemIDs.PURE_COAL or type == Const.ItemIDs.RICH_COAL:
#		Utils.game.map.pickables.remove_pickable(id)
#		fuel = min(fuel + (type - Const.ItemIDs.COAL + 1) * 10, fuel_indicator.max_value + 3)
#		speed = 4
#	else:
#		reject_pickable(id)

func start():
	start_on = true
	$AnimationPlayer.play("startup")
#	$reveal_fog.set_physics_process(true)

func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "explode":
		Utils.remove_from_tracker(self)
		set_disabled(true)
		enemy_ignore = true
		$HealthBarParent.hide()
	elif anim_name == "startup":
		set_disabled(false)

var destructed: bool

func open_door():
	$open_door_anim.play("open")
	pass

func destroy(explode := true):
	if destructed:
		return
	destructed = true
	SteamAPI.unlock_achievement("LOSE_1")

	check_unhandled_exception_achievement()
	if lumen_slots:
		lumen_slots.queue_free()
		lumen_slots = null

	if get_meta("no_lose", false):
		init_range_extender(0)
		play_explode()
		return
	
	var seq := create_tween()
	seq.tween_callback(Callable(Utils.game.ui, "start_cutscene"))
	seq.tween_callback(Callable(Utils.game.camera, "set_physics_process").bind(false))
	seq.tween_property(Utils.game.camera, "global_position", global_position, 1).set_trans(Tween.TRANS_SINE)
	seq.tween_callback(Callable(self, "play_explode"))
	
	seq.tween_interval(4)
	seq.tween_callback(Callable(Utils.game, "game_over").bind("Reactor destroyed"))

func check_unhandled_exception_achievement():
	var units:int = 0
	var swarms = Utils.game.map.enemies_group.get_all_swarms_nodes()
	var max_attack_range = 0.0
	for s in swarms:
		if "attack_range" in s:
			max_attack_range = max(max_attack_range, s.attack_range)
		if "shot_range" in s:
			max_attack_range = max(max_attack_range, s.shot_range)
		units += s.getUnitsInCircle(global_position, radius + max_attack_range + 1, true, true).size()
		if units>1: break

	if units <=1:
		var nodes = Utils.game.map.enemy_tracker.getTrackingNodes2DInCircle( position, 300, true )
		if is_instance_valid(nodes):
			units += nodes.size()
		if units == 1:
			if nodes.size() > 0:
				if not (nodes[0].enemy_data.name in Const.BOSS_ENEMIES):
					SteamAPI.unlock_achievement("BUG")
			else:
				SteamAPI.unlock_achievement("BUG")

func play_explode():
#	var explosion := Const.EXPLOSION.instance() as Node2D
#	explosion.type = explosion.NEUTRAL
#	explosion.scale = Vector2.ONE
#	explosion.position = global_position
#	Utils.game.map.add_child(explosion)
	
#	apply_mask(-1)
#	queue_free()
	$AnimationPlayer.play("explode")

func explode():
	var explosion := Const.EXPLOSION.instantiate() as Node2D
	explosion.type = explosion.NEUTRAL
	explosion.scale = Vector2.ONE
	explosion.position = global_position
	Utils.game.map.add_child(explosion)

func animate_range(percent:float):
#	prints("Range", RANGE*percent)
	init_range_extender(RANGE*percent)
	emit_signal("lost_power")


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_arc(Vector2(), RANGE, 0, TAU, 32, Color.YELLOW)

func set_disabled(disabled: bool, force := false):
	super.set_disabled(disabled, force)
	
	if disabled:
		init_range_extender(0.0)
	else:
		init_range_extender(RANGE) ## TODO: jak był upgrade to skasuje, ale w sumie to się nigdy nie dzieje
	
	$Sprite2D/Computer7/GenericComputer.set_disabled(disabled)
	$Sprite2D/Computer6/GenericComputer.set_disabled(disabled)
	$Sprite2D/Computer5/GenericComputer.set_disabled(disabled)
	$Sprite2D/Computer4/GenericComputer.set_disabled(disabled)

func _get_save_data() -> Dictionary:
	var data: Dictionary
	
	data.range_cost = level
	data.emp_count = emp_computer.emp_count
	data.max_hp = max_hp
	
	if lumen_slots:
		data.merge(lumen_slots.get_data())
	
	return Utils.merge_dicts(_get_save_data(), data)

func _set_save_data(data: Dictionary):
	super._set_save_data(data)
	if not "range_cost" in data: # compat
		return
	
	await self.ready
	
	if "count" in data:
		add_lumen_slots(data.count, data.powered)
	
	level = data.range_cost
	emp_computer.emp_count = data.emp_count
	max_hp = data.get("max_hp", max_hp)

func add_lumen_slots(amount: int, powered := 0):
	if amount == 0:
		return
	
	lumen_slots = load("res://Nodes/Buildings/Reactor/ReactorLumenSlots.tscn").instantiate()
	lumen_slots.count = amount
	lumen_slots.powered = powered
	add_child(lumen_slots)

func is_condition_met(condition: String, data: Dictionary) -> bool:
	if condition == "lumen_chunk_delivered":
		if chunk_delivered:
			chunk_delivered = false
			return true
	elif condition == "destroyed":
		return destructed
	
	return false
