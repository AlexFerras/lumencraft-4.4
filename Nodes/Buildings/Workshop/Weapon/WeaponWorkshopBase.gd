extends "res://Nodes/Buildings/Workshop/Workshop.gd"

@onready var production_root := $Production

@onready var maker := $"%Print" as Sprite2D
@onready var arm_animator := production_root.get_node("ArmAnimator") as AnimationPlayer
@onready var circle_animator := production_root.get_node("CircleAnimator") as AnimationPlayer
@onready var circle := $Sprite2D/Circle as Node2D
@onready var welding_player := $Sprite2D/Arm/Grapple/AudioStreamPlayer2D as AudioStreamPlayer2D

@onready var sparkle_fx := $Sprite2D/Arm/Grapple/Sparkles as GPUParticles2D
@onready var smoke_fx := $Sprite2D/Smoke as GPUParticles2D
@onready var mist_fx := $Sprite2D/Mist as GPUParticles2D
@onready var upgrade_fx := $Sprite2D/Arm/Grapple/Item/GPUParticles2D as GPUParticles2D

const AmmoCount = {
	Const.Ammo.BULLETS: 80,
	Const.Ammo.ROCKETS: 4,
	Const.ItemIDs.NAPALM: 30,
}

@export var weapon_name: String
var weapon: int

var making: bool
var emit_particles: bool
var weapon_make_seq: Tween

func _ready():
	arm_animator.connect("animation_finished", Callable(self, "arm_end"))
	Save.connect("unclocked_tech_number", Callable(self, "refresh_upgrades"))

func initialize():
	weapon = Const.ItemIDs.keys().find(weapon_name)
	var upgrade_list: Array = Const.Items[weapon].upgrades
	if weapon == Const.ItemIDs.DRILL and (Save.current_map == "res://Maps/TundraEscavation.lcmap" or Save.current_map == "res://Maps/DesertEscavation.lcmap" or Save.current_map == "res://Maps/Tunnels.lcmap"):
		upgrade_list = Const.Items[weapon].custom_upgrades_for_compatibility
	
	var stand = stands.get_node_or_null("WorkshopStand")
	if stand:
		stand.empty = false
		stand.item = weapon
		stand.amount = 1
		stand.cost = Utils.get_item_cost({id = stand.item, amount = stand.amount})
	
	stand = stands.get_node_or_null("WorkshopStand2")
	if stand:
		var item_data: Dictionary = Const.Items[weapon]
		if "ammo" in item_data:
			stand.item = Const.ItemIDs.AMMO
			stand.data = item_data.ammo
			stand.amount = AmmoCount[item_data.ammo]
			stand.cost = Utils.get_item_cost({id = stand.item, data = stand.data, amount = stand.amount})
		elif "item_ammo" in item_data:
			stand.item = item_data.item_ammo
			stand.amount = AmmoCount[item_data.item_ammo]
			stand.cost = Utils.get_item_cost({id = stand.item, amount = stand.amount})
		else:
			stand.set_no_item()
	
	for i in range(3, 7):
		stand = stands.get_node_or_null("WorkshopStand%s" % i)
		if stand:
			if i >= upgrade_list.size() + 3:
				stand.set_no_item()
				continue
			
			stand.had_upgrades = true
			var upgrade: Dictionary = upgrade_list[i - 3]
			for j in upgrade.costs.size():
				stand.upgrades.append({
					item = weapon,
					upgrade = upgrade.name,
					level = j + 1,
					cost = upgrade.costs[j],
					requirements = upgrade.get("requirements", {}).get(j, [])
				})
			stand.refresh_upgrades()

func refresh_upgrades(what, ever):
	for stand in stands.get_children():
		stand.refresh_upgrades()

func arm_end(anim):
	emit_signal("full_complete")

func animate_maker(value: float):
	maker.get_parent().global_position = circle.global_position
	
	var texture: Texture2D = maker.texture
	maker.region_rect.position.y = texture.get_height() * (0.5 - value * 0.5)
	maker.region_rect.size.y = texture.get_height() * value
	var v := 1.0 + (1 - value) * 4.0
	maker.modulate = Color(v, v, v)
	
	emit_particles = value > 0.1 and value < 0.95
	sparkle_fx.emitting = emit_particles
	smoke_fx.emitting = emit_particles
	mist_fx.emitting = emit_particles

func done():
	maker.region_rect = Rect2()

func get_current_progress() -> float:
	if not making:
		return get_max_progress()
	
	var time: float
	if weapon_make_seq:
		time += weapon_make_seq.get_total_elapsed_time()
		if not weapon_make_seq.is_running():
			if arm_animator.is_playing():
				time += arm_animator.current_animation_position
			else:
				time += arm_animator.get_animation("Finished").length
	if conveyor_seq:
		time += conveyor_seq.get_total_elapsed_time()
	return time / speed_modifier

func get_max_progress() -> float:
	var time: float = arm_animator.get_animation("Build").length
	time += arm_animator.get_animation("Finished").length
	time += BELT_TIME
	return time / speed_modifier

func make_anim():
	making = true
	var texture = finished_item.get_icon()
	if not texture and finished_pickup:
		texture = finished_pickup.get_sprite_texture()
	
	maker.texture = texture
	maker.region_rect = Rect2(0, texture.get_height() / 2, texture.get_width(), 0)
	if finished_pickup:
		maker.scale = finished_pickup.get_sprite_scale() / sprite.scale * 4
	else:
		maker.scale = Vector2.ONE * min(10.0 / max(texture.get_width(), texture.get_height()), 1) / sprite.scale # Można const
	
	Utils.play_sample("res://SFX/Building/StartMake.wav", maker)
	weld = randi() % 2
	next_weld()
	arm_animator.play("Build", -1, speed_modifier)
	circle_animator.play("Start", -1, speed_modifier)
	
	weapon_make_seq = production_root.create_tween().set_speed_scale(speed_modifier)
	weapon_make_seq.tween_method(Callable(self, "animate_maker"), 0.0, 1.0, 8)
	weapon_make_seq.tween_callback(Callable(welding_player, "stop"))
	if finished_pickup:
		weapon_make_seq.tween_callback(Callable(arm_animator, "play").bind("Finished", -1, speed_modifier))
	else:
		weapon_make_seq.tween_callback(Callable(arm_animator, "stop"))
		weapon_make_seq.tween_callback(Callable(self, "upgrade_particles"))
		weapon_make_seq.tween_interval(0.75)
		weapon_make_seq.tween_callback(Callable(self, "finish_make"))
	weapon_make_seq.tween_callback(Callable(circle_animator, "play").bind("Finish", -1, speed_modifier))

func upgrade_particles():
	maker.texture = null
	upgrade_fx.emitting = true

func finish_start():
	making = false
	weapon_make_seq = null
	maker.get_parent().position = Vector2(370, 145)

func finish_end():
	maker.texture = null

func get_pickup_start() -> Vector2:
	return maker.global_position

const WELD_SFX = [preload("res://SFX/Building/Welding.wav"), preload("res://SFX/Building/Welding2.wav")]
var weld: int

func next_weld() -> void:
	welding_player.stream.audio_stream = WELD_SFX[weld]
	welding_player.play()
	weld = 1 - weld

func set_disabled(disabled: bool, force := false):
	if disabled:
		$LightAnimator.play("PowerOFF")
#		production_root.pause_mode = Node.PAUSE_MODE_STOP_ALWAYS
		if making:
			production_root.pause_pauser()
		
		if weapon_make_seq:
			weapon_make_seq.pause()
	else:
		$LightAnimator.play("PowerON")
#		production_root.pause_mode = Node.PAUSE_MODE_INHERIT
		if making:
			production_root.unpause_pauser()
		
		if weapon_make_seq:
			weapon_make_seq.play()
	
	if force:
		$LightAnimator.advance(99999)
	
	super.set_disabled(disabled, force)
	
#	$FloodLight/LightSprite3.visible = not disabled
#	$LightSprite.visible = not disabled
	$SpiralAnimator.playback_speed = int(not disabled)
