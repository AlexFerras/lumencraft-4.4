extends BaseBuilding

@onready var shoot_point: Marker2D = $"%ShootPoint"
@onready var body: RigidBody2D = $Body
@onready var computer: Node2D = $Computer
@onready var sound_rotate: Node2D = $beam_rotate
@onready var sound_active: Node2D = $beam_active
@onready var laser: Node2D = $Body/Top/ShootPoint/Laser
@onready var light: Node2D = $Body/Top/light
@onready var anim=$"AnimationPlayer" as AnimationPlayer
@export var shoot_time: float
@export var start_time: float =0.0

@export var locked: bool

func _ready():
	if shoot_time>0.0:
		anim.play("shoot")
		anim.advance(10.0)
	
	toggle_lock(true)
	
	
func prelong():
	if shoot_time<=0:
		Utils.play_sample("res://SFX/Turret/laser_start.wav",global_position,false,1.2,0.7)
		anim.play("shoot")
	shoot_time += 10
	sound_active.pitch_scale=1.8
	sound_active.volume_db=0.0
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	var vel=abs(body.angular_velocity)
	light.dirty=true
	if vel>0.01:
		if !sound_rotate.playing:
			sound_rotate.playing=true
		sound_rotate.volume_db=min(0,linear_to_db(vel*0.5))
		sound_rotate.pitch_scale=vel*0.1+0.5
	else:
		sound_rotate.playing=false
	if shoot_time > 0:
		start_time+=delta
		computer.reload()
		if start_time>1.0:
			if !sound_active.playing:
				sound_active.pitch_scale=1.8
				sound_active.playing=true
				sound_active.volume_db=0.0
			shoot_time -= delta
			if !laser.working:
				laser.set_working(true)
				SteamAPI.unlock_achievement("FIRE_LASER")
			if shoot_time<3.0:
				sound_active.pitch_scale=1.8*(shoot_time+3.0)/6.0
				sound_active.volume_db=linear_to_db(shoot_time/3.0)
	else:
		if laser.working:
			start_time=0.0
			sound_active.playing=false
			anim.play_backwards("shoot")
			laser.set_working(false)
			set_physics_process(false)


func _get_save_data() -> Dictionary:

	return Utils.merge_dicts(_get_save_data(), {head_rotation = body.global_rotation})


func _set_save_data(data: Dictionary):
	super._set_save_data(data)
	await self.ready
	body.global_rotation = data.get("head_rotation", 0.0)
	


func set_disabled(disabled: bool, force := false):
	super.set_disabled(disabled, force)
	if disabled and shoot_time>3.0:
		shoot_time=3.0
		
	if computer:
		computer.set_disabled(disabled)

func update_angle():
	if not body:
		await self.ready
	body.rotation = angle

func is_condition_met(condition: String, data: Dictionary) -> bool:
	if condition == "is_shooting":
		return shoot_time > 0
	else:
		return super.is_condition_met(condition, data)

func toggle_lock(update_only := false):
	if not update_only:
		locked = not locked
	
	if locked:
		$Body.mode = RigidBody2D.FREEZE_MODE_STATIC
	else:
		$Body.mode = RigidBody2D.MODE_RIGID
