extends BaseBuilding

const BELT_TIME = 2.1

@onready var stands := $Sprite2D/Stands
@onready var belt_animator := find_child("BeltAnimator") as AnimationPlayer

var screen_highlight: Sprite2D
var stand_idx: int
var make_cost: Array
var make_tech: Array

var busy: bool
#var block_queue: bool
var make_queue: Array
var current_make_item: QueuedItem
var speed_modifier := 1.0

var conveyoring: bool
var conveyor_seq: Tween

signal new_item
signal full_complete

func _ready() -> void:
	initialize()
	
	assert(make_cost.is_empty())
	
	for stand in stands.get_children():
		stand.connect("make", Callable(self, "make_item").bind(stand))
	on_placed()
	
	output_offset = Vector2.UP * 30
	Utils.subscribe_tech(self, "make_time")

func _tech_unlocked(tech: String):
	super._tech_unlocked(tech)
	if tech == "make_time":
		speed_modifier = 2.0

func on_placed():
	for stand in stands.get_children():
		stand.reload()

func initialize():
	pass

func special_setup(screen, stand):
	pass

func special_make(stand):
	pass

func add_cost(item: int, amount: int, data = null):
	assert(make_cost.size() < 3)
	make_cost.append({id = item, data = data, amount = amount})

func add_tech_requirement(tech: String):
	make_tech.append(tech)

func add_empty_stand():
	assert(stand_idx < stands.get_child_count())
	var stand = stands.get_child(stand_idx)
	stand.special = null
	stand.set_no_item()
	
	stand_idx += 1

func add_stand(item: int, data = null, amount := 1):
	assert(stand_idx < stands.get_child_count())
	
	var stand = stands.get_child(stand_idx)
	stand.item = item
	stand.data = data
	stand.amount = amount
	stand.cost = Utils.get_item_cost({id = item, data = data, amount = amount})
	stand.tech_requirement = make_tech
	
	if make_tech:
		Save.connect("tech_unlocked", Callable(stand, "new_tech"))
	
	make_tech = []
	stand_idx += 1

func add_special_stand(stand_special):
	assert(stand_idx < stands.get_child_count())
	
	var stand = stands.get_child(stand_idx)
	stand.tech_requirement = make_tech
	stand.special = stand_special
	
	if make_tech:
		if not Save.is_connected("tech_unlocked", Callable(stand, "new_tech")):
			Save.connect("tech_unlocked", Callable(stand, "new_tech")) ## TODO: przydałoby się odpinać
	
	make_tech = []
	stand_idx += 1

func add_upgrade(item: int, upgrade: String, level: int):
	assert(stand_idx < stands.get_child_count())
	
	if not Save.is_tech_unlocked(str(item, upgrade, level)):
		var stand = stands.get_child(stand_idx)
		var upgrade_data = {item = item, upgrade = upgrade, level = level, cost = make_cost}
		stand.upgrades.append(upgrade_data)
	
	make_cost = []

func finish_upgrade_stand():
	var stand = stands.get_child(stand_idx)
	stand.refresh_upgrades()
	stand_idx += 1

func add_custom_stand(object: PackedScene, icon: Texture2D):
	assert(stand_idx < stands.get_child_count())
	
	var stand = stands.get_child(stand_idx)
	stand.custom = object
	stand.icon = icon
	stand.cost = make_cost
	stand.tech_requirement = make_tech
	
	if make_tech:
		Save.connect("tech_unlocked", Callable(stand, "new_tech"))
	
	make_cost = []
	make_tech = []
	stand_idx += 1

func make_item(stand: Node):
#	if block_queue:
#		Utils.play_sample(preload("res://SFX/Building/InterfaceFail.wav"))
#		return
	Utils.play_sample(preload("res://SFX/Building/InterfaceAccept.wav"))
	
	var item := QueuedItem.new()
	item.stand_idx = stand.get_index()
	item.cost = stand.cost
	
	if stand.special != null:
		special_make(stand)
	elif stand.custom:
		item.custom = stand.custom
		item.data = stand.icon
	elif stand.item:
		item.item = stand.item
		item.data = stand.data
		item.amount = stand.amount
		
		if stand.upgrades:
			stand.item = 0
			stand.amount = 0
			stand.reload()
	elif stand.upgrades:
		item.upgrade = stand.pop_upgrade()
		item.cost = item.upgrade.cost
		stand.reload()
	
	make_queue.append(item)
	stand.queue += 1
	stand.reload()
	
	Utils.log_message("%s ordered: %s" % [name, Utils.get_item_name({id = stand.item, data = stand.data})] )
	next_item()

func fail_item():
	Utils.play_sample(preload("res://SFX/Building/InterfaceFail.wav"))

var finished_pickup: Node2D
var finished_item: QueuedItem

func next_item():
	if busy:
		return
	
	if make_queue.is_empty():
		Utils.game.ui.notify("Workshop done")
		done()
		for stand in stands.get_children():
			stand.reload()
		return
	
	busy = true
	current_make_item = make_queue.pop_front()
	emit_signal("new_item")
	var stand = stands.get_child(current_make_item.stand_idx)
	
	finished_item = current_make_item
	if stand.special != null or current_make_item.upgrade:
		pass
	elif current_make_item.custom:
		finished_pickup = current_make_item.custom.instantiate()
	else:
		finished_pickup = Pickup.instance(current_make_item.item)
		finished_pickup.data = current_make_item.data
		finished_pickup.amount = current_make_item.amount
	
	stand.pop_queue()
	stand.refresh()
	
	make_anim()

func done():
	pass

func make_anim():
	pass

func finish_start():
	pass

func finish_end():
	pass

func finish_make():
	finish_start()
	var no_wait := (finished_pickup == null)
	
	if finished_pickup:
		finished_pickup.position = get_pickup_start() + get_pickup_flow_direction()
		Utils.game.map.add_child(finished_pickup)
		conveyor_pickups[last_pickup_id] = finished_pickup
		if finished_pickup is RigidBody2D:
			finished_pickup.mode = RigidBody2D.FREEZE_MODE_STATIC
		SteamAPI2.increment_stat("FabricatedItems")
	elif finished_item:
		Save.set_unlocked_tech(str(finished_item.upgrade.item, finished_item.upgrade.upgrade), finished_item.upgrade.level)
		if finished_item.upgrade.item == Const.ItemIDs.DRILL:
			get_tree().call_group("player", "emit_signal", "inventory_changed")
	
	conveyoring = true
	conveyor_seq = belt_animator.create_tween().set_speed_scale(speed_modifier)
	conveyor_seq.tween_method(Callable(self, "move_pickup"), last_pickup_id, last_pickup_id, BELT_TIME)
	conveyor_seq.connect("finished", Callable(self, "remove_pickup").bind(last_pickup_id))
	
	last_pickup_id += 1
	finished_pickup = null
	finished_item = null
	finish_end()
	
	belt_animator.play("Finish_construction", -1, speed_modifier)
	if not no_wait:
		await self.full_complete
	
	conveyoring = false
	conveyor_seq = null
	busy = false
	current_make_item = null
	next_item()

var last_pickup_id: int
var conveyor_pickups: Dictionary

func move_pickup(id: int):
	if not is_instance_valid(conveyor_pickups.get(id)):
		conveyor_pickups.erase(id)
		return
	
	conveyor_pickups[id].position += get_pickup_flow_direction() * 11 * get_process_delta_time() * speed_modifier

func remove_pickup(id: int):
	if not id in conveyor_pickups:
		return
	
	if not is_instance_valid(conveyor_pickups.get(id)):
		conveyor_pickups.erase(id)
		return
	
	var pickup: Node2D = conveyor_pickups[id]
	if pickup is Pickup:
		pickup.lock_rotation = true
		pickup.linear_velocity = get_pickup_flow_direction() * 20
	elif pickup is RigidBody2D:
		pickup.lock_rotation = true
		pickup.linear_velocity = get_pickup_flow_direction() * 20
	
	conveyor_pickups.erase(id)

func get_current_progress() -> float:
	return 0.0

func get_max_progress() -> float:
	return 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and screen_highlight:
		screen_highlight.queue_free()

func get_pickup_start() -> Vector2:
	return global_position
	
func get_pickup_flow_direction() -> Vector2:
	return Vector2.LEFT

func set_disabled(disabled: bool, force := false):
	if disabled and is_running and not force:
		Utils.play_sample("res://SFX/Building/StopMake.wav", self)
	elif not disabled and not is_running and not force:
		Utils.play_sample("res://SFX/Building/StartMake.wav", self)
	super.set_disabled(disabled, force)
	
	for stand in stands.get_children():
		stand.status_light.visible = not disabled
		stand.set_disabled(disabled)
		if disabled:
			stand.set_display_icon(null)
		else:
			stand.reload()
	
	if conveyoring:
		if disabled:
			conveyor_seq.pause()
		else:
			conveyor_seq.resume()

class QueuedItem:
	var stand_idx: int
	var item: int
	var data
	var amount: int
	var custom
	var upgrade: Dictionary
	var cost: Array
	
	func get_icon() -> Texture2D:
		if custom:
			return data
		elif upgrade:
			var icon_path: String = Const.UPGRADES[upgrade.upgrade].get_slice("|", 2)
			if icon_path.is_empty():
				return preload("res://Nodes/Buildings/Workshop/Sprites/Upgrade.png")
			else:
				return load(icon_path) as Texture2D
		else:
			return Utils.get_item_icon(item, data)

func _get_save_data() -> Dictionary:
	var data: Dictionary
	var dict_queue: Array
	
	for item in make_queue:
		dict_queue.append(Save.get_properties(item, ["stand_idx", "item", "data", "amount", "custom", "upgrade", "cost"]))
	
	if current_make_item:
		dict_queue.append(Save.get_properties(current_make_item, ["stand_idx", "item", "data", "amount", "custom", "upgrade", "cost"]))
	
	data.make_queue = dict_queue
	
	return Utils.merge_dicts(super._get_save_data(), data)

func _set_save_data(data: Dictionary):
	super._set_save_data(data)
	await self.ready
	
	var dict_queue: Array = data.get("make_queue", {}) # compat
	if dict_queue.is_empty():
		return
	
	for dict in dict_queue:
		var item = QueuedItem.new()
		Save.set_properties(item, dict)
		stands.get_child(item.stand_idx).queue += 1
		make_queue.append(item)
	
	for stand in stands.get_children():
		stand.refresh()
	
	next_item()

func clear_queue():
	if make_queue.is_empty():
		return
	
	for item in make_queue:
		for cost in item.cost:
			Pickup.launch(cost, stands.get_child(0).screen.current_player.global_position, Vector2())
	
	make_queue.clear()
	
	for stand in stands.get_children():
		stand.clear_queue()
		stand.reload()

func has_queue() -> bool:
	return true

func get_queue() -> Array:
	return make_queue

func get_queue_item_icon(item: QueuedItem) -> Texture2D:
	return item.get_icon()

func get_current_item_icon() -> Texture2D:
	return get_queue_item_icon(current_make_item)

func get_queue_icon(idx: int) -> Texture2D:
	return get_queue_item_icon(make_queue[idx])
