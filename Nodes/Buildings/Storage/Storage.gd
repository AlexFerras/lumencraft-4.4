extends BaseBuilding

@onready var fullness_anim := $AnimationPlayer as AnimationPlayer
@onready var throw_lumen_point := $throw_lumen
@onready var throw_metal_point := $throw_metal
@onready var lumen_count_label := $"Lumen_Computer/Label"
@onready var metal_count_label := $"Metal_Computer/Label"
@onready var pickable_detector := $Pickable_detector

@export var cap_increased: bool
@export var max_storage:int=600
@export var stored_lumen:int=0 
@export var stored_metal:int=0

var lumen_on_computer:int=0
var metal_on_computer:int=0
var release_delay := 0.0
var magnet_enabled: bool
var block_excess: bool
var update_queued: bool

func update_gui():
	for i in Utils.game.players:
		i.emit_signal("inventory_changed")

func update_fullness():
	lumen_count_label.text=str(lumen_on_computer)
	metal_count_label.text=str(metal_on_computer)
	fullness_anim.seek(float(stored_lumen+stored_metal)/max_storage,true)

func open_door():
	$open_door_anim.play("open")
	
func _ready() -> void:
	Utils.set_collisions(self, Const.BUILDING_COLLISION_LAYER | Const.PLAYER_COLLISION_LAYER, Utils.PASSIVE)
	update_fullness()
	
	Utils.subscribe_tech(self, "storage_cap")
	Utils.subscribe_tech(self, "storage_magnet")

func _tech_unlocked(tech: String):
	if not cap_increased and tech == "storage_cap":
		cap_increased = true # dla save
		max_storage += 400
	elif tech == "storage_magnet":
		magnet_enabled = true
	else:
		super._tech_unlocked(tech)

func release_resource(what,where):
	if randi() %2==0:
		Utils.play_sample("res://Nodes/Buildings/Storage/bottle_pop.wav",global_position,false, 1.5)
	release_delay = 0.5
	Utils.game.map.pickables.spawn_pickable_nice(where.global_position, what, Vector2.RIGHT.rotated(where.rotation + randf_range(-1.0, 1.0)) * randf_range(50, 130))

func release_metal():
	if stored_metal>0:
		use_metal(1)
		release_resource(Const.ItemIDs.METAL_SCRAP,throw_metal_point)

func release_lumen():
	if stored_lumen>0:
		use_lumen(1)
		release_resource(Const.ItemIDs.LUMEN,throw_lumen_point)

func get_free_storage():
	return max_storage-(stored_lumen+stored_metal)

func use_lumen(amount):
	var used_lumen=min(stored_lumen,amount)
	stored_lumen-=used_lumen
	update_fullness()
	update_gui()
	return used_lumen

func use_metal(amount):
	var used_metal=min(stored_metal,amount)
	stored_metal-=used_metal
	update_fullness()
	update_gui()
	return used_metal

func store_metal(amount):
	store("stored_metal",amount)

func store_lumen(amount):
	store("stored_lumen",amount)

func store(what,amount):
	var new_amount=stored_lumen+stored_metal+amount
	if get_free_storage() <= 0:
		SteamAPI.unlock_achievement("STORAGE_FULL")
	var real_stored=min(amount,get_free_storage())
	
	if real_stored <= 0:
		return amount
	
	set(what,get(what)+real_stored)
	queue_update()
	return amount-real_stored
	
func _physics_process(delta):
	release_delay -= delta
	if lumen_on_computer!=stored_lumen || metal_on_computer!=stored_metal:
		var lerped_lumen=lerp(lumen_on_computer,stored_lumen,0.05)
		lumen_on_computer= lerped_lumen if abs(int(lerped_lumen)-int(lumen_on_computer))>0 else (lumen_on_computer+sign(stored_lumen-lerped_lumen))

		var lerped_metal=lerp(metal_on_computer,stored_metal,0.05)
		metal_on_computer= lerped_metal if abs(int(lerped_metal)-int(metal_on_computer))>0 else (metal_on_computer+sign(stored_metal-lerped_metal))
		update_fullness()
		
	var near_pickables=Utils.game.map.pickables.get_pickables_in_oriented_rect(Rect2(pickable_detector.global_position, Vector2(pickable_detector.width,pickable_detector.height)),0.0)
	for i in near_pickables:
		resource_input(i, Utils.game.map.pickables.get_pickable_type(i))
	
	if magnet_enabled and get_free_storage() > 0:
		pickables.add_attraction_velocity_to_pickables(global_position, 100, 100 * delta, 3)

func resource_input(pickable_id: int, type: int):
	if not block_excess and release_delay <= 0:
		if type == Const.ItemIDs.LUMEN:
			if get_free_storage() <= 0:
				release_any()
			store_lumen(1)
			Utils.game.map.pickables.remove_pickable(pickable_id)
		elif type ==Const.ItemIDs.METAL_SCRAP:
			if get_free_storage() <= 0:
				release_any()
			store_metal(1)
			Utils.game.map.pickables.remove_pickable(pickable_id)
		else:
			reject_pickable(pickable_id)
	else:
		reject_pickable(pickable_id)

func set_disabled(disabled: bool, force := false):
	if disabled:
		$LightsAnimator.play("PowerOFF")
	else:
		$LightsAnimator.play("PowerON")
	if force:
		$LightsAnimator.advance(99999)
	super.set_disabled(disabled)
	$Lumen_Computer.set_disabled(disabled)
	$Metal_Computer.set_disabled(disabled)
	
	lumen_count_label.visible = not disabled
	metal_count_label.visible = not disabled
	
	if !disabled:
		lumen_count_label.modulate = Color(0.0, 1.3, 2.5)
		metal_count_label.modulate = Color(0.0, 1.3, 2.5)
		update_fullness()
		update_gui()
	else:
		lumen_count_label.modulate = Color(0.5, 0.5, 0.5)
		metal_count_label.modulate = Color(0.5, 0.5, 0.5)
		$Sprite2D/StorageContainerT001Emissive.modulate = Color(0.5, 0.5, 0.5)
		update_gui()

func destroy(explode := true):
	super.destroy(explode)
	for i in stored_lumen:
		Utils.game.map.pickables.spawn_pickable_nice(global_position, Const.ItemIDs.LUMEN)
	for i in stored_metal:
		Utils.game.map.pickables.spawn_pickable_nice(global_position, Const.ItemIDs.METAL_SCRAP)

func release_any():
	if stored_metal > 0:
		release_metal()
	elif stored_lumen > 0:
		release_lumen()

func queue_update():
	if update_queued:
		return
	call_deferred("update_all")
	update_queued = true

func update_all():
	update_queued = false
	update_fullness()
	update_gui()
