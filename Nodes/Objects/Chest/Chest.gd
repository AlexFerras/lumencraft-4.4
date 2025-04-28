@tool
extends PixelMapRigidBody
var pixel_map: PixelMap
@onready var animator: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var interactable: Area2D = get_node_or_null("GenericInteractable")

var buried: bool
var player_in: bool
var pickups: Array

signal opened

func _enter_tree() -> void:
	set_meta("pickup_container", true)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	pixel_map= Utils.game.map.pixel_map as PixelMap
	set_meta("object_type", "Chest")
	
	for child in get_children():
		if child is Pickup:
			pickups.append(child.get_data())
			child.queue_free()
		elif child is BaseEnemy:
			assert(false, "Co robisz debilu")
	
	if pixel_map.is_pixel_solid(position, Utils.walkable_collision_mask):
		pixel_map.connect("pixels_modifed", Callable(self, "pixel_map_modified"))
		buried = true
	Utils.add_to_tracker(self, Utils.game.map.pickup_tracker, radius)

func pixel_map_modified():
	if not pixel_map.is_pixel_solid(position, Utils.walkable_collision_mask):
		buried = false
		pixel_map.disconnect("pixels_modifed", Callable(self, "pixel_map_modified"))

var opened: bool

func open():
	if opened:
		return
	opened = true
	collision_layer = 0
	collision_mask = 0
	
	z_index = ZIndexer.Indexes.PICKUPS - 10
	Utils.play_sample(Utils.random_sound("res://SFX/Objects/ChestOpen"), self).volume_db += 10
	animator.play("Open")
	await animator.animation_finished
	emit_signal("opened")
	queue_free()

func spawn_items():
	for pickup in pickups:
		Pickup.launch(pickup, position, Vector2.RIGHT.rotated(randf() * TAU) * 100, true, false)
	pickups.clear()

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if Utils.is_pixel_buried(global_position):
		state.linear_velocity=Vector2.ZERO
		buried=true
		if interactable and interactable.can_interact==true:
			interactable.can_interact=false
			interactable.refresh_interacters()
	else:
		pixel_map_physics(state,Utils.walkable_collision_mask)
		buried=false
		if interactable and interactable.can_interact==false:
			interactable.can_interact=true
			interactable.refresh_interacters()

func on_interact(player) -> void:
	Utils.log_message("P%s Chest opened: %s" % [player.player_id + 1, name] )
	open()

func _get_save_data() -> Dictionary:
	var data: Dictionary
	
	data.items = pickups.duplicate()
	data.static = mode == FREEZE_MODE_STATIC
	
	return data

func _set_save_data(data):
	if data is Array: # compat
		data = {items = data}
	
	for item in data.items:
		pickups.append(item)
	
	if data.get("static", false):
		mode = RigidBody2D.FREEZE_MODE_STATIC

func is_condition_met(condition: String, data: Dictionary) -> bool:
	return opened

func execute_action(action: String, data: Dictionary):
	open()

