extends BaseBuilding

@onready var where = $spawn_point
@onready var stale_check = $stale_check
@onready var anim=$"Production/AnimationPlayer"
@onready var sound=$"AudioStreamPlayer2D"
@onready var default_speed = anim.playback_speed

@export var give_speed := 3.0

var vein: Node
var give_timer := 1.0
var overclock: bool

signal overclock_tick

func _ready():
	add_to_group("miner")


func add_to_tracker():
	Utils.add_to_tracker(self, Utils.game.map.mine_buildings_tracker, radius, 999999)

func build():
	super.build()
	Utils.explode_circle(global_position, 40, 5000, 10, 10,-1,false,0.0)
	if vein:
		vein.refresh_glare()

func release_resource():
	if overclock or Utils.game.map.pickables.get_pickables_in_range(stale_check.global_position, 30.0).size() < 100:
		if anim.current_animation!="Work":
			anim.play("start")
		vein.count -=1
		Utils.play_sample("res://Nodes/Buildings/Storage/bottle_pop.wav", global_position, false, 1.5)
		Utils.game.map.pickables.spawn_premium_pickable_nice(where.global_position,vein.resource, Vector2.RIGHT.rotated(where.rotation + randf_range(-0.3, 0.3)) * randf_range(80, 130))
	else:
		anim.play("Stop")

func _physics_process(delta):
	if not is_instance_valid(vein) or vein.count <= 0:
		vein = null
		anim.play("Stop")
		return
	
	if overclock:
		sprite.position = Vector2(randf_range(-1, 1), randf_range(-1, 1))
	
	give_timer -= delta
	if give_timer <= 0:
		give_timer = give_speed
		release_resource()
		
		if overclock:
			emit_signal("overclock_tick")

func set_overclock(enabled: bool):
	overclock = enabled
	if enabled:
		give_timer = 0
		give_speed = 0.1
		anim.playback_speed = 20
	else:
		give_speed = 3.0
		give_timer = give_speed
		anim.playback_speed = default_speed
		sprite.position = Vector2()

func set_disabled(disabled: bool, force := false):
	if disabled:
		$LightsAnimator.play("PowerOFF")
	else:
		$LightsAnimator.play("PowerON")
	if force:
		$LightsAnimator.advance(99999)
	super.set_disabled(disabled,force)
	if disabled:
		set_physics_process(false)
		anim.play("Stop")
	else:
		set_physics_process(true)
	
func _get_save_data() -> Dictionary:
	if not vein:
		return super._get_save_data()
	return Utils.merge_dicts(super._get_save_data(), {vein = get_path_to(vein)})

func _set_save_data(data: Dictionary):
	super._set_save_data(data)
	if not "vein" in data:
		return
	
	await self.tree_entered
	if not has_node(data.vein):
		queue_free()
		return
	
	vein = get_node(data.vein)
	vein.miner = self
