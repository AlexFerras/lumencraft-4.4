extends Node2D

@onready var spawn_timer :=  $SpawnTimer

@export var swarm_object: PackedScene

@onready var sprite := $Hole
@onready var mask := $mask
@onready var animator := $AnimationPlayer as AnimationPlayer

@export var total_monsters := 10
@export var max_monsters_at_once := 6 
@export var spawn_batch := 3
@export var spawn_interval := 1.0 
@export var trigger_timeout := 3.0
@export var is_endless_spawner := false

@export var trigger_size := 15.0
@export var ignore_buildings: bool = false

var mega_swarm: Swarm
var spawn_counter := 0
var live_counter := 0
var marker_grow := 0

var triggered: bool
var opened: bool

var positions: PackedVector2Array
var colors: PackedColorArray

var mask_image:Image
var spawned_monsters: int
var spawn_tween: Tween

var is_enabled = false

func _ready():
	assert(get_parent().global_transform == Transform2D(), "Dziura musi być pod parentem na (0, 0) bez skali i rotacji.")
	
	positions.resize(50)
	colors.resize(50)
	for i in 50:
		colors[i] = Color.DARK_GRAY * Color(0.1,0.1,0.1,1.0)
		positions[i] = global_position
	
	spawn_batch = min(spawn_batch, max_monsters_at_once)
	mask_image = mask.texture.get_data()
	$AudioStreamPlayer2D.stream = load("res://SFX/Environmnent/rock_earthquake_impact_0"+str(randi()%2+1)+".wav")
	if is_zero_approx(trigger_size):
		$Area2D/CollisionShape2D.disabled = true
	else:
		$Area2D/CollisionShape2D.shape.radius = trigger_size
	$Cracks.rotation = randi()*TAU
	$Cracks.frame = randi()%4
	
	var enemy_data := Const.get_entry_by_scene(Const.Enemies, swarm_object.resource_path)
	assert(not enemy_data.is_empty())
	if enemy_data.is_swarm:
		mega_swarm = Utils.game.map.swarm_manager.request_swarm(enemy_data.scene)

func _on_spawn_timer_timeout():
	opened = true
	
	if not is_endless_spawner and spawn_counter >= total_monsters:
		animator.play("fade")
		spawn_timer.stop()
		spawn_tween = null
	else:
		if spawn_counter < total_monsters:
			var i = 0
			while i < spawn_batch:
				if mega_swarm:
					live_counter = mega_swarm.getNumOfUnitsInCircle(global_position, 200, false, true)
				
				if live_counter >= max_monsters_at_once:
					break
				
				if mega_swarm:
					if spawn_tween and spawn_tween.is_running():
						break
					
					if mega_swarm.how_many == -1:
						mega_swarm.how_many = 0
					
					var to_spawn :float= min(spawn_batch, total_monsters - spawn_counter)
					to_spawn = min(to_spawn, max_monsters_at_once - live_counter)
#					mega_swarm.how_many += to_spawn
					spawn_tween = mega_swarm.spawn_in_radius_with_delay(global_position, 3, to_spawn, 0.01, 0.01)
					spawn_counter += to_spawn
					i += to_spawn
				else:
					var new_swarm = swarm_object.instantiate()
					live_counter += 1
					spawn_counter += 1
					i += 1
				
					if ignore_buildings and "is_ignoring_buildings" in new_swarm:
						new_swarm.is_ignoring_buildings=true
				
					new_swarm.position = global_position
					Utils.game.map.add_child(new_swarm)
					new_swarm.connect("died", Callable(self, "enemy_dead"))
				
				if spawn_counter >= total_monsters:
					break
		
		spawn_timer.start( spawn_interval )

func _on_Area2D_body_entered(body):
	if not is_enabled and body is Player:
		trigger()

func enemy_dead():
	live_counter -= 1

func spawn_debris():
	Utils.game.map.pixel_map.particle_manager.spawn_particles(positions, colors, Vector2.ZERO)

func trigger(notify := true):
	triggered = true
	force_enable()
#	if notify:
#		if is_endless_spawner:
#			Utils.game.ui.notify("Endless swarm aproaching!")
#		else:
#			Utils.game.ui.notify("Something hides beneath the ground!")
	
	if not opened:
		Utils.game.shake(1.0, 2.0)

func force_enable():
	remove_from_group("hole")
	if Utils.game.map.pixel_map.is_pixel_solid(global_position, Utils.walkable_collision_mask):
		animator.play("destroy_terrain")
	else:
		animator.play("grow")
	
	if opened:
		animator.advance(10000)
		spawn_timer.start(spawn_interval)
	else:
		$AudioStreamPlayer2D.play()
		spawn_timer.start(trigger_timeout)
	
	is_enabled = true

func destroy_terrain():
	marker_grow += 2
	Utils.game.shake(1.0, 2.0)
#	Utils.game.shake(2)
	Utils.explode_mask(global_position, mask_image, float(marker_grow) / 10.0)
	Utils.game.map.pixel_map.particle_manager.spawn_particles(positions, colors, Vector2.ZERO)

func fade():
	queue_free()

func _should_save() -> bool:
	return spawn_counter < total_monsters

func _get_save_data() -> Dictionary:
	return Save.get_properties(self, ["triggered", "spawn_counter", "opened"])

func _set_save_data(data: Dictionary):
	if data.triggered:
		connect("ready", Callable(self, "trigger").bind(false))
	spawn_counter = data.spawn_counter
	opened = data.opened

func disable_trigger():
	trigger_size = 0

func is_condition_met(condition: String, data: Dictionary) -> bool:
	match condition:
		"triggered":
			return triggered
		"all_defeated":
			## TODO
			pass
	return false

func execute_action(action: String, data: Dictionary):
	trigger(false)
