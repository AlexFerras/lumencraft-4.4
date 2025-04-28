extends PixelMapRigidBody
class_name Player

const MAGNET_RANGE = 25
const THROW_VARIATION = Vector2(2, 2.5)
const DASH_STAMINA = 25
const TIRED_STAMINA = 10

const QUICKBIND_SLOTS = 4
const MODIFIER_ACTIONS = ["auto_walk", "slot1", "slot2", "slot3", "slot4"]
const ASSIGNABLE = ["shoot2", "slot1", "slot2", "slot3", "slot4"]

enum StackPolicy { ANY, CURRENT, MINIMUM, MAXIMUM, FORCE_STACK }
const INVENTORY_COLUMNS = 2
const EMPTY_STACK = {id = -1, amount = 0}

enum Controls { MIXED = 1, KEYBOARD, JOYPAD1, JOYPAD2 }
enum { ACTION_DISCARD, ACTION_ACCEPT, ACTION_PASS }

@export var max_speed: float = 500
@export var max_stacks: int
@export var threat: float

@onready var torso := $Torso as Sprite2D
@onready var topso := $Torso/Topso as Sprite2D
@onready var torso_scale := torso.scale
@onready var legs := $Legs as Sprite2D
@onready var hold_point := $Torso/HoldPoint as Node2D
@onready var throwing_sprite := $Torso/Throwing as Sprite2D
@onready var collider := Utils.get_node_by_type(self, Area2D) as Area2D

@onready var canvas_center := $CanvasLayer/CanvasCenter
@onready var interactable_icon: Node2D = canvas_center.get_node("CanInteract")
@onready var interactable_label = interactable_icon.get_node("UltimateTooltip")
@onready var cursor := $"%Cursor" as Sprite2D
@onready var player_indicator: Sprite2D = canvas_center.get_node("Indicator")
@onready var death_label: Label = canvas_center.get_node("Death/Label")
@onready var revive_sfx: AudioStreamPlayer2D = $"%ReviveSFX"

@onready var revive_area := $Reviver as Area2D
@onready var legs_animator  := $Legs/AnimatorLegs as AnimationPlayer
@onready var torso_animator := $AnimationPlayer as AnimationPlayer
@onready var hurt_audio := $HurtAudio
@onready var run_debris := $RunDebris
@onready var radar_animator := $Radar/AnimationPlayer as AnimationPlayer
@onready var stand_particles: GPUParticles2D = $StandParticles

@onready var respawn_timer := $Respawn as Range

enum {NONE, THROW, SHOOT, DASH, DASH_TAIL, DEAD}
var animation_state: int = NONE

var map: Map: set = set_map

var dead: bool
var super_dead: bool
var dead_timer: float
var revive_timer: float
var reviver: Player
var respawning: bool

var is_fear_enabled:bool = false
var is_dash_enabled:bool = true

var time_from_last_shoot: = 0.0
var recoil_stability: = 0.0

var force_position: Vector2
var force_rotation: float = -1
var is_dashing: bool
var dash_move: Vector2
var dash_initial_velocity:Vector2
#var dash_distance: = 0.0
var is_directional_key_pressed:bool = false
var block_scroll: bool
var block_controls: bool
var prev_angle: float
var assisted: bool
var modifier_press_time: int

var luck: float
var hp: float
var max_hp: float = 100
var max_stamina: float = 100
var stamina: float
var stamina_regen: float = 0.75
var stamina_delay: float
var stamina_delay_value: float = 1.00
var tired: bool
var speed_bonus: float
var regen_delay: float
var heal_delay: float
var passive_heal_delay: float
var just_healed: bool
var just_damaged_by_lava: bool
var just_damaged_by_gate: bool

var inventory_full: Sprite2D
var pickup_level: int
var pickup_timer: Timer
var throw_timer: float
var trying_dash: float

var interactables: Array
var current_interactable: Node2D
var prev_interactable: Node2D

@export var inventory: Array
var inventory_select: int
var inventory_secondary: int = -1: set = set_inventory_secondary
var inventory_secondary_id: int = -1
var inventory_quick: Array
var inventory_quick_id: Array
var refresh_full_resources_pending: bool

var counters: Array
var shooting: bool
var queued_shot: int

var throwing: float
var throwing_power: float
var thrown_item: Dictionary
var in_vehicle: bool
var on_stand: int
var after_build: bool
var last_build_angle: float

var melee: Node2D
var throwing_melee: bool
var build_menu: Node2D
var build_menu_cached: Node2D
var gun_audio: AudioStreamPlayer2D
var gun_sprite: Node2D
var inventory_sfx: AudioStreamPlayer

var held_item: Dictionary
var using_secondary: bool
var block_shoot: bool
var full_resources: Dictionary

var player_id := 0
var control_id := 1
var inventory_visible: bool
var inventory_visible2: bool
var position_on_screen: Vector2
var using_computer: Node2D
var auto_walk: bool
var assign_timer: float = -1
var cancel_tap: bool

var magnet_upgrade: int
var health_regen_upgrade: int
var auto_heal_upgrade: int
var stamina_regen_upgrade: int
var item_detector_upgrade: bool
var item_pool:Dictionary

var squeezer:Tween

var cancel_override: FuncRef
var minimap_toggle: float

signal inventory_toggled
signal inventory_changed
signal inventory_select_changed(show_inventory)
signal secondary_select_changed
signal hp_changed
signal stamina_changed
signal max_changed
signal modifier_toggled
signal full_inventory
signal orb_used
signal update_secondary

func _init() -> void:
	inventory_quick.resize(QUICKBIND_SLOTS)
	inventory_quick_id.resize(QUICKBIND_SLOTS)
	
	for i in QUICKBIND_SLOTS:
		inventory_quick[i] = i
		inventory_quick_id[i] = -1
	
	if Utils.game:
		await Utils.get_tree().idle_frame
	else:
		return
	
	inventory.resize(get_max_stacks())
	for i in inventory.size():
		inventory[i] = EMPTY_STACK.duplicate()
	refresh_indices()

func _ready() -> void:
	load_item_pool()
	Utils.add_to_tracker($Torso/FlashLight, Utils.game.map.lights_tracker, $Torso/FlashLight.radius, 999999)
	torso_animator.play(get_current_item_data().get("animation", "Carry"))
	pickup_timer = Timer.new()
	pickup_timer.one_shot = true
	pickup_timer.connect("timeout", Callable(self, "set").bind("pickup_level", 0))
	add_child(pickup_timer)
	
	inventory_sfx = AudioStreamPlayer.new()
	inventory_sfx.bus = "SFX"
	inventory_sfx.volume_db = -15
	inventory_sfx.stream = preload("res://SFX/UI/InventoryChange.wav")
	
	add_child(inventory_sfx)
	
	force_position = global_position
	
	Utils.get_node_by_type(self, Area2D).set_meta("player", true)
	add_to_group("player")
	set_map(Utils.game.get("map")) # jakiś błąd
	
	if position == Vector2():
		position = Vector2(1, 1)
	Utils.add_to_tracker(self, map.player_tracker, radius, 999999)
	
	Utils.subscribe_tech(self, "magnet_upgrade")
	Utils.subscribe_tech(self, "hp_regeneration")
	Utils.subscribe_tech(self, "auto_heal")
	Utils.subscribe_tech(self, "stamina_regeneration")
	Utils.subscribe_tech(self, "item_detector")
	Utils.subscribe_tech(self, "light_upgrade")
	
	$LavaChecks.connect("lava_touching", Callable(self, "damage").bind({damage = 10, is_lava = true}))
	interactable_icon.get_child(0).set_input_player(self)
	revive_area.exceptions.append(self)
	
	collider.collision_layer = Const.PLAYER_COLLISION_LAYER
	collider.collision_mask = 0
	
	if hp == 0:
		hp = get_max_hp()
	
	if stamina == 0:
		stamina = get_max_stamina()
	
	cursor.self_modulate = Const.PLAYER_COLORS[player_id].lightened(0.2)
#	is_fear_enabled = has_node("Fear")
#	if is_fear_enabled:
#		is_dash_enabled = false
	
	update_listener(Utils.game.players.size() > 1)
	Utils.connect("coop_toggled", Callable(self, "update_listener"))
	
	refresh_full_resources()
	Utils.call_super_deferred(self, "check_hp")
	
	if not Utils.game.initialized:
		await get_tree().idle_frame
	
	build_menu_cached = preload("res://Nodes/Player/BuildMenu/BuildMenu.tscn").instantiate()
	build_menu_cached.player = self
	if Utils.game.get_second_viewport() and player_id == 1:
		build_menu_cached.ui = Utils.game.ui2
	else:
		build_menu_cached.ui = Utils.game.ui
	build_menu_cached.connect("building_selected", Callable(self, "start_building"))
	build_menu_cached.connect("tree_exited", Callable(self, "exit_build").bind(), CONNECT_DEFERRED)
	
	build_menu_cached.ui.add_child(build_menu_cached)
	if build_menu_cached.appear(true):
		build_menu_cached.disappear()
	else:
		build_menu_cached.hide()
	
	if is_secondary_disabled():
		var i := -1
		for item in inventory:
			i += 1
			if item.get("id", -1) == Const.ItemIDs.DRILL:
				inventory_secondary = i
				inventory_secondary_id = Const.ItemIDs.DRILL
				break

func load_item_pool():
#	print(Const.Items)
	for item in Const.Items:
		var data: Dictionary = Const.Items[item]
		if "sprite" in data:
			item_pool[item] = load(data.sprite)
		if "melee_scene" in data:
			item_pool[item] = load(data.melee_scene)
#
func _process(delta: float) -> void:
	if player_id == 1 and Utils.game.get_second_viewport():
		position_on_screen = Utils.game.get_second_viewport().canvas_transform * (global_position)
	else:
		position_on_screen = get_viewport().canvas_transform * (global_position)
	canvas_center.position = Vector2(clamp(position_on_screen.x, 60, get_viewport_rect().size.x - 40), clamp(position_on_screen.y, 60, get_viewport_rect().size.y))
#	canvas_center.position = Vector2(clamp(position_on_screen.x, 60, Const.RESOLUTION.x - 40), clamp(position_on_screen.y, 60, Const.RESOLUTION.y))

	var cursor_shake = Vector2.ZERO
	if is_fear_enabled:
		cursor_shake = Vector2.RIGHT.rotated(randf()*TAU) * $Fear.fear_amount_current * 0.05
		
	if using_joypad():
		cursor.position = canvas_center.position + Vector2.RIGHT.rotated(torso.rotation) * 200 + cursor_shake
	else:
		if Utils.game.get_second_viewport():
			cursor.global_position = get_viewport().get_parent().get_local_mouse_position()
		else:
			cursor.global_position = get_viewport().get_mouse_position() + cursor_shake
	
	if dead:
		var death_parent: Sprite2D = death_label.get_parent()
		if Utils.game.players.size() > 1 and (not super_dead or reviver) and not respawning:
			death_parent.show()
		
		if not super_dead:
			if not reviver:
				dead_timer -= delta
				death_parent.frame = 0
				death_label.text = str(int(dead_timer))
			
			if dead_timer <= 0:
				revive_area.can_interact = false
				death_parent.hide()
				super_dead = true
				died()
		
		if reviver:
			death_parent.frame = 1
			if not revive_sfx.playing:
				revive_sfx.playing = true
			death_label.text = str(ceil(3 - revive_timer))
			revive_timer += delta
			if revive_timer >= 3:
				revive_area.can_interact = false
				revive_timer  = 0
				SteamAPI.unlock_achievement("CO_OP_REVIVE")
				revive()
			elif not reviver.is_action_pressed("interact") or reviver.dead or global_position.distance_squared_to(reviver.global_position) > 400:
				revive_timer  = 0
				reviver = null
		else:
			revive_sfx.playing = false
		
		return
	else:
		reviver = null
	
	if hp < 25:
		passive_heal_delay -= delta
		if passive_heal_delay <= 0:
			heal(1)
	
	if auto_heal_upgrade > 0 and hp < get_max_hp() * auto_heal_upgrade * 0.3:
		heal_delay -= delta
		
		if heal_delay <= 0:
			heal(1)
			heal_delay = 0.2
	
	if health_regen_upgrade > 0:
		regen_delay -= delta
		
		if regen_delay <= 0:
			heal(health_regen_upgrade)
			regen_delay = 2
	
	if in_vehicle:
		return
	
	throwing -= delta
	
	process_building()
	process_controls(delta)
	process_shooting(delta)
	process_interactables()
	process_throwing(delta)
	process_inventory(delta)
	process_animation()
	
	for counter in counters:
		counter.timer += delta * 1000

func process_controls(delta: float):
	if is_action_just_pressed("inventory") and (not build_menu):
		emit_signal("inventory_toggled", not inventory_visible)
	
	if using_joypad() and is_action_just_pressed("modifier"):
		emit_signal("modifier_toggled", true)
		modifier_press_time = Time.get_ticks_msec()
	elif using_joypad() and is_action_just_released("modifier"):
		emit_signal("modifier_toggled", false)
		if not inventory_visible and not cancel_tap or Time.get_ticks_msec() - modifier_press_time <= 150:
			inventory_select = (inventory_select + 1) % inventory.size()
			select_changed()
		cancel_tap = false
	
	if is_action_just_pressed("auto_walk", true):
		auto_walk = not auto_walk
	
	if is_action_pressed("respawn") and (not using_joypad() or is_action_pressed("modifier")):
		respawn_timer.show()
		respawn_timer.value += delta
		
		if respawn_timer.value >= 2:
			damage({damage = 9999})
			respawn_timer.value = 0
			respawn_timer.hide()
	else:
		respawn_timer.hide()
		respawn_timer.value = 0
	
	if is_action_just_pressed("map", false, true):
		Utils.game.ui.toggle_map()
	
	if throwing <= -0.3:
		var pickables: PixelMapPickables = map.pickables
		var pickable_types_mask = int(!full_resources.get(0, false)) | int(int(!full_resources.get(1, false)) << 1)
		pickables.add_attraction_velocity_to_pickables(global_position, MAGNET_RANGE + magnet_upgrade * 30, (200 + magnet_upgrade * 200) * delta, pickable_types_mask)
	
	for i in QUICKBIND_SLOTS:
		var idx: int = inventory_quick[i]
		if idx > -1 and is_action_just_released_with_modifier(str("slot", i + 1)) and is_slot_usable(idx) and assign_timer < 0.5:
			inventory_select = idx
			cancel_tap = true
			select_changed(false)

func process_shooting(delta: float):
	time_from_last_shoot += delta
	
	if shooting and (is_just_not_shooting() or build_menu):
		SteamAPI.fail_achievement("WAVE_NO_ACTION")
		deshoot()
	
	if build_menu:
		return
	
	if block_shoot:
		if not is_action_pressed("shoot") and not is_action_pressed("shoot2"):
			block_shoot = false
		return
	
	var current_weapon: Dictionary = get_current_item()
	if inventory_secondary > -1 and is_action_pressed("shoot2") and not (inventory_visible and is_action_pressed("modifier")):
		using_secondary = true
		current_weapon = inventory[inventory_secondary]
	elif is_action_pressed("shoot"):
		set_deferred("using_secondary", false)
	elif using_secondary:
		current_weapon = inventory[inventory_secondary]
	
	if not current_weapon or current_weapon.id < Const.RESOURCE_COUNT:
		deshoot()
		return
	
	var just_shooting: bool
	if is_shooting():
		set_held_item(current_weapon)
		just_shooting = is_just_shooting()
	elif queued_shot > 0 and Time.get_ticks_msec() >= queued_shot:
		queued_shot = 0
		just_shooting = true
	else:
		recoil_stability = max(0, recoil_stability - delta * 2.0)
	

#	if is_action_just_pressed("reload") and "reload" in current_weapon:
#		reload_weapon(current_weapon)
	
	if animation_state != THROW and animation_state != DASH and animation_state != DASH_TAIL and (just_shooting or is_shooting() and current_weapon.get("autofire")):
		if not can_use(current_weapon):
			Utils.play_sample(preload("res://SFX/Player/UseFail.wav"), self)
			return
		
		var data: Dictionary = get_upgraded_data(Const.Items[current_weapon.id])
		if get_ammo(current_weapon) > 0:
			if shoot(current_weapon):
				Save.count_score("shots_fired")
				time_from_last_shoot = 0.0
				if not "infinite" in current_weapon:
					if "ammo" in data:
						skip_select = false
						subtract_item(Const.ItemIDs.AMMO, max(get_upgraded(data, "ammo_per_shot", 1) - get_upgraded(data, "ammo_reduction", 0), 1), data.ammo)
					elif "item_ammo" in data:
						skip_select = false
						subtract_item(data.item_ammo, max(get_upgraded(data, "ammo_per_shot", 1) - get_upgraded(data, "ammo_reduction", 0), 1), null)
					else:
						subtract_stack(current_weapon, 1)
		else:
			if "delay" in data:
				if not can_use_delayed(current_weapon):
					return false
				current_weapon.last_shot = Time.get_ticks_msec()
			
			Utils.play_sample(Utils.random_sound("res://SFX/Weapons/gun_revolver_pistol_dry_fire"), self)
			deshoot()

func process_interactables():
	for i in interactables.size():
		if not is_instance_valid(interactables[i]):
			interactables.remove(i)
		else:
			i += 1
	
	if interactables.is_empty() or build_menu:
		if is_instance_valid(prev_interactable):
			prev_interactable.remove_interacter(self)
		
		current_interactable = null
		prev_interactable = null
		interactable_icon.hide()
		player_indicator.visible = Utils.game.players.size() > 1
		return
	
	if interactables.size() == 1:
		current_interactable = interactables.front()
	elif interactables.size() > 1:
		if not current_interactable in interactables:
			current_interactable = null
		
		var distance_min := INF
		if current_interactable:
			distance_min = global_position.distance_squared_to(current_interactable.global_position)
		
		for interactable in interactables:
			var dot := -global_position.direction_to(interactable.global_position).dot(Vector2.RIGHT.rotated(torso.rotation) ) + 1.1
			var dist := global_position.distance_to(interactable.global_position)
			if dist * dot < distance_min:
				current_interactable = interactable
				distance_min = dist
	
	if not is_instance_valid(current_interactable) or using_computer and (not current_interactable.has_meta("computer_interactable") or using_computer != current_interactable.get_parent().screen):
		current_interactable = null
	
	if current_interactable != prev_interactable:
		if is_instance_valid(prev_interactable):
			prev_interactable.remove_interacter(self)
		
		if current_interactable:
			current_interactable.add_interacter(self)
	
	if current_interactable:
		if is_action_just_pressed("interact"):
			current_interactable.interact(self)
		
		if current_interactable != prev_interactable:
			if current_interactable.has_method("get_interact_text"):
				interactable_label.text = current_interactable.get_interact_text()
			else:
				interactable_label.text = ""
		
		if current_interactable.get("refresh_text"):
			interactable_label.text = current_interactable.get_interact_text()
			current_interactable.set_deferred("refresh_text", false)
		
	interactable_icon.visible = current_interactable and not current_interactable.disable_icon
	prev_interactable = current_interactable
	
	player_indicator.visible = not interactable_icon.visible and Utils.game.players.size() > 1

func process_throwing(delta: float):
	if thrown_item:
		throwing_power = min(throwing_power + delta, 1)
		throwing_sprite.show()
		throwing_sprite.region_rect.size.x = 160 * (throwing_power / 1.0)
		
		if is_just_not_shooting(true) or build_menu:
			torso_animator.seek(28, true)
			shoot(thrown_item)
			throwing_power = 0
			throwing_sprite.hide()
			thrown_item = {}
	
	if build_menu or animation_state == DASH or animation_state == DASH_TAIL:
		return
	
	if melee and melee.has_method("can_throw"):
		if is_action_just_pressed("throw_item") and melee.can_throw():
			animation_state = THROW
#			torso_animator.play("Throw_melee")
			throwing_melee = true
			throw_timer = -999
	
	if not thrown_item and (throw_timer >= 0 and is_action_just_released("throw_item") or throw_timer >= 0.5):
		var current_item: Dictionary = get_current_item()
		if current_item:
			throw_resource(current_item, Vector2.RIGHT.rotated(get_shoot_rotation()) * randf_range(THROW_VARIATION.x, THROW_VARIATION.y))
		throw_timer = -999
	
	if is_action_pressed("throw_item"):
		throw_timer += delta
	else:
		throw_timer = 0

func process_inventory(delta: float):
	if build_menu:
		return
	
	var scroll_allowed := not block_scroll
	if scroll_allowed and current_interactable and current_interactable.get("block_scroll"):
		scroll_allowed = false
	
	if scroll_allowed:
		if is_action_just_released("next_slot") or is_action_just_released("next_row"):
			for q in (INVENTORY_COLUMNS if is_action_just_released("next_row") else 1):
				if (inventory_visible and inventory_select < get_max_stacks() - 1) or inventory_select < inventory.size() - 1 and is_slot_usable(inventory_select + 1):
					inventory_select += 1
				else:
					inventory_select = 0
				
				select_changed()
		elif is_action_just_released("prev_slot") or is_action_just_released("prev_row"):
			for q in (INVENTORY_COLUMNS if is_action_just_released("prev_row") else 1):
				if inventory_select > 0:
					inventory_select -= 1
				elif inventory_visible:
					inventory_select = get_max_stacks() - 1
				else:
					for i in inventory.size():
						var j = inventory.size() - 1 - i
						if is_slot_usable(j):
							inventory_select = j
							break
				
				select_changed()
		
		if inventory_visible and is_action_pressed("modifier"):
			if is_action_just_pressed("look_right"):
				move_item(1)
			elif is_action_just_pressed("look_left"):
				move_item(-1)
			elif is_action_just_pressed("look_down"):
				move_item(INVENTORY_COLUMNS)
			elif is_action_just_pressed("look_up"):
				move_item(-INVENTORY_COLUMNS)
			elif is_action_just_pressed("shoot2"):
				if inventory_select < inventory.size() and inventory_secondary != inventory_select:
					inventory_secondary = inventory_select
					inventory_secondary_id = inventory[inventory_select].id
				else:
					inventory_secondary = -1
				emit_signal("secondary_select_changed")

func handle_slot_change(change: int):
	for i in 5:
		var idx: int = inventory_quick[i] if i < QUICKBIND_SLOTS else inventory_secondary
		
		if change == 1:
			if inventory_select == idx:
				idx -= 1
			elif inventory_select == idx + 1:
				idx += 1
		elif change == -1:
			if inventory_select == idx:
				idx += 1
			elif inventory_select == idx - 1:
				idx -= 1
		elif change == 0:
			idx = min(idx, inventory.size() - 1)
			if idx > -1 and not can_use(inventory[idx]):
				idx -= 1
		
		if i == QUICKBIND_SLOTS:
			inventory_secondary = idx

func process_building():
	var can_build := not using_computer
	
	if is_action_just_pressed("build") and can_build:
		if OS.has_feature("mobile") and inventory_visible:
			emit_signal("inventory_toggled", false)
		
		if not build_menu:
			await get_tree().idle_frame
			if build_menu_cached.appear():
				build_menu = build_menu_cached
		elif build_menu and not using_joypad():
			if build_menu.build_interface:
				build_menu.go_back()
				build_menu.go_back()
			else:
				build_menu.disappear()
	
	if build_menu:
		if is_action_just_pressed("interact") or is_action_just_pressed("shoot"):
			build_menu.interact()
		
		if is_action_pressed("interact"):
			build_menu.interact_continuous()
		
		if is_action_just_pressed("cancel") or is_action_just_pressed("shoot2"):
			trying_dash = 0.5
			build_menu.go_back()
		
		build_menu.global_position = position_on_screen

func start_building(data):
	if build_menu.build_interface:
		return
	
	var blueprint: Node2D
	if data is Dictionary:
		Utils.log_message("P%s started demolishing" % (player_id + 1))
		blueprint = preload("res://Nodes/Buildings/Common/Demolish.tscn").instantiate()
	else:
		Utils.log_message("P%s started building" % (player_id + 1))
		blueprint = data.get_blueprint()
	
	var build_interface := preload("res://Nodes/Player/BuildMenu/BuildInterface.tscn").instantiate() as Node2D
	build_interface.player = self
	build_interface.blueprint = blueprint
	if player_id == 1 and Utils.game.get_second_viewport():
		Utils.game.ui2.add_child(build_interface)
	else:
		Utils.game.ui.add_child(build_interface)
	
	build_interface.global_position = position_on_screen
	build_interface.connect("place", Callable(Utils.game, "place_building"))
	build_interface.connect("place", Callable(build_menu, "pay").bind(data))
	build_interface.connect("tree_exiting", Callable(build_menu, "set").bind("build_interface", null))
	build_interface.connect("tree_exiting", Callable(build_menu, "build_end").bind(), CONNECT_DEFERRED)
	
	map.post_process.start_build_mode(global_position)
	
	build_menu.build_interface = build_interface
	build_menu.hide()

func exit_build():
	build_menu = null
	after_build = true
	if is_inside_tree():
		Utils.call_super_deferred(self, "set", ["after_build", false])

func single_pixel_removed(pos: Vector2, mat: int, value: int):
	if not Utils.explosion_accum.has(mat):
		Utils.explosion_accum[mat] = 0
	Utils.explosion_accum[mat] += 1
	
var next_beep_modulate=60

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	
	Utils.game.map.pixel_map.set_destruction_callback(1, self, "single_pixel_removed")
	Utils.game.map.pixel_map.update_damage_for_pixels_in_circle_surrounded_mostly_by_empty_material(global_position,8, 100000,10,Utils.walkable_collision_mask,12)
	Utils.game.map.restore_pickable_callback()
	
	if throwing <= 0 and not dead:
		var pickup_radius = radius * 0.6
		for pickable_type in Const.RESOURCE_COUNT:
			var near_premium_pickables = Utils.game.map.pickables.get_premium_pickables_in_range(global_position, pickup_radius, 1 << pickable_type)
			if !near_premium_pickables.is_empty() && not can_add(pickable_type):
				indicate_full()
				continue
			
			var add_non_premium_pickables = true
			if !near_premium_pickables.is_empty():
				var num_of_not_added_pickables = add_item(pickable_type, near_premium_pickables.size())
				var num_of_added_pickables = near_premium_pickables.size() - num_of_not_added_pickables
				for i in range(num_of_added_pickables):
					map.pickables.remove_pickable(near_premium_pickables[i])

				if num_of_not_added_pickables > 0:
					add_non_premium_pickables = false

				match pickable_type:
					Const.ItemIDs.METAL_SCRAP:
						Save.count_score("metal_collected")
						Utils.game.scraps_collected_per_second += num_of_added_pickables
						play_pickup(Utils.random_sound("res://SFX/Pickups/metal_small_movement_"))
					Const.ItemIDs.LUMEN:
						Save.count_score("lumen_collected")
						Utils.game.lumens_collected_per_second += num_of_added_pickables
						play_pickup(Utils.random_sound("res://SFX/Pickups/Collect star "))
					_:
						play_pickup(preload("res://SFX/Pickups/422709__niamhd00145229__inspect-item.wav"))

			if add_non_premium_pickables:
				var near_non_premium_pickables = Utils.game.map.pickables.get_non_premium_pickables_in_range(global_position, pickup_radius, 1 << pickable_type)
				if not near_non_premium_pickables.is_empty() and not can_add(pickable_type):
					indicate_full()
					continue

				if !near_non_premium_pickables.is_empty():
					var num_of_not_added_pickables = add_item(pickable_type, near_non_premium_pickables.size())
					var num_of_added_pickables = near_non_premium_pickables.size() - num_of_not_added_pickables
					for i in range(num_of_added_pickables):
						map.pickables.remove_pickable(near_non_premium_pickables[i])

					match pickable_type:
						Const.ItemIDs.METAL_SCRAP:
							play_pickup(Utils.random_sound("res://SFX/Pickups/metal_small_movement_"))
						Const.ItemIDs.LUMEN:
							play_pickup(Utils.random_sound("res://SFX/Pickups/Collect star "))
						_:
							play_pickup(preload("res://SFX/Pickups/422709__niamhd00145229__inspect-item.wav"))


	if item_detector_upgrade:
		if Utils.game.frame_from_start > next_beep_modulate:
			next_beep_modulate = Utils.game.frame_from_start + 60
			
			var close_pickups: Array = Utils.game.map.pickup_tracker.getTrackingNodes2DInCircle(global_position, 100, true)
			var closest_pickup: Node2D
			var closest_dist := INF
			
			for i in close_pickups:
				if not i.get("buried"):
					continue
				
				var dist: float = i.global_position.distance_squared_to(global_position)
				if dist < closest_dist:
					closest_dist = dist
					closest_pickup = i
			
			if closest_pickup:
				closest_dist = sqrt(closest_dist)
				next_beep_modulate = Utils.game.frame_from_start + clamp(int(closest_dist * 0.6), 10, 60)
				Utils.play_sample(preload("res://SFX/Player/beep.wav"), false, false, 1.0, 0.5 + (0.5 * (100.0 - closest_dist)) / 100.0).volume_db = -5
				radar_animator.stop()
				radar_animator.play("Blink")
	
	if force_position:
		state.transform.origin = force_position
		force_position = Vector2()
		return
	
	var angle := 0.0
	if is_dashing:
		angle = torso.rotation
	else:
		angle = get_look_angle()
	
	if angle != INF and not dead:
		var rot := lerp_angle(torso.rotation, angle, 0.5 if using_joypad() else 0.2)
		legs.rotation = rot
		torso.rotation = rot + (randf_range(-recoil_stability, recoil_stability) * randf_range(-recoil_stability, recoil_stability)) * 0.1
		
	if in_vehicle or dead:
		linear_velocity = Vector2()
		applied_force = Vector2()
		applied_torque = 0
		legs_animator.stop()
		return
	
	var move := Vector2.ZERO
#	var move := Input.get_vector(get_p_action("left"), get_p_action("right"), get_p_action("up"), get_p_action("down"))
	is_directional_key_pressed = Input.is_action_pressed(get_p_action("left")) or Input.is_action_pressed(get_p_action("right")) or Input.is_action_pressed(get_p_action("up")) or Input.is_action_pressed(get_p_action("down"))
	
	if is_directional_key_pressed:
		if is_action_pressed("run"):
			move = Vector2(Input.get_axis(get_p_action("left"), get_p_action("right")), Input.get_axis(get_p_action("up"), get_p_action("down"))).normalized()
		else:
			move = Vector2(Input.get_action_strength(get_p_action("right")) - Input.get_action_strength(get_p_action("left")), Input.get_action_strength(get_p_action("down")) - Input.get_action_strength(get_p_action("up"))).normalized()
		
	if Save.config.alternate_movement:
		if not using_joypad():
			move = move.rotated(torso.rotation + PI/2)
	
	if move == Vector2() and auto_walk:
		move = Vector2.RIGHT.rotated(torso.rotation)
	elif move != Vector2():
		auto_walk = false
	
	if should_block_controls():
		move = Vector2()
	
	if dash_move:
		move = dash_move
	
#	var speed := 600.0 + get_buff(Const.Buffs.SPEED_BUFF) * 200 + speed_bonus
	var move_relative_to_shoot_rotation = move.dot(Vector2.RIGHT.rotated(torso.rotation))
	var move_cross_to_shoot_rotation = move.cross(Vector2.RIGHT.rotated(torso.rotation))
	var speed := 0.0
	if is_fear_enabled:
		var influence_on_speed = ($Fear.fear_amount_current/$Fear.fear_amount_max)
		speed = get_velocity() * min(move_relative_to_shoot_rotation * (0.2 + 0.4 * influence_on_speed) + 1.0, 1.0 + 0.2 * influence_on_speed)
	else:
		speed = get_velocity() * min(move_relative_to_shoot_rotation * 0.8 + 1.5, 1)
	var can_dash := not tired and not thrown_item and animation_state != DASH and animation_state != DASH_TAIL and is_dash_enabled
	
	var do_dash: bool
	do_dash = can_dash and is_action_just_released("run") and trying_dash < 0.4
	
	if do_dash:
		if move == Vector2():
			move = Vector2.RIGHT.rotated(torso.rotation)
#			move_relative_to_shoot_rotation = 1
		
		animation_state = DASH
		if move_relative_to_shoot_rotation >= -0.7 and move_relative_to_shoot_rotation <= 0.7:
			expend_stamina(DASH_STAMINA)
			if move_cross_to_shoot_rotation > 0:
				torso_animator.play("Slide_Right")
			else:
				torso_animator.play("Slide_Left")
		else:
			expend_stamina(DASH_STAMINA)
			torso_animator.play("Slide_Foreward")
	
	if is_action_pressed("run"):
		trying_dash += get_physics_process_delta_time()
	else:
		trying_dash = 0
	
	if is_dashing:
		if animation_state != DASH or animation_state != DASH_TAIL:
			speed = 0
			linear_velocity = dash_initial_velocity
		
		match torso_animator.current_animation:
			"Slide_Foreward":
#				print(move_relative_to_shoot_rotation)
				if can_dash:
					if move_relative_to_shoot_rotation >= 0:
						torso.rotation = dash_initial_velocity.angle()
					else:
						torso.rotation = -dash_initial_velocity.angle()
			"Slide_Right":
				torso.rotation = dash_initial_velocity.rotated(PI*0.5).angle()
			"Slide_Left":
				torso.rotation = dash_initial_velocity.rotated(-PI*0.5).angle()
	else:
		if animation_state == DASH:
			Utils.play_sample(Utils.random_sound("res://SFX/Player/Dash/Dash Heavy Armor 1_"), self)
		dash_initial_velocity = linear_velocity
	
	is_dashing = animation_state == DASH
#	print(torso_animator.current_animation)
	
	var is_running: bool
	if is_action_pressed("run") and can_dash and time_from_last_shoot >= 0.2 and move.length_squared() > 0.02 and not is_dashing:
		run_debris.emitting = true
		speed *= 1.5
		is_running = true
		expend_stamina(0.4)
	elif is_dashing:
		run_debris.emitting = true
	else:
		run_debris.emitting = false
		
		stamina_delay -= get_physics_process_delta_time()
		if stamina < get_max_stamina() and stamina_delay <= 0:
			stamina = min(stamina + stamina_regen + stamina_regen_upgrade * 0.5, get_max_stamina())
			emit_signal("stamina_changed")
			
			if stamina > TIRED_STAMINA:
				tired = false
	
	if is_nan(Utils.game.camera.get_camera_screen_center().y) or is_nan(Utils.game.resolution_of_visible_rect.y) :
		return
	
	if Utils.game.players.size() > 1 and not Utils.game.get_second_viewport():
		if global_position.x < Utils.game.camera.get_camera_screen_center().x - Utils.game.resolution_of_visible_rect.x * Utils.game.camera.zoom.x * 0.5:
			move.x = max(0, move.x)
		elif global_position.x > Utils.game.camera.get_camera_screen_center().x + Utils.game.resolution_of_visible_rect.x * Utils.game.camera.zoom.x * 0.5:
			move.x = min(0, move.x)
		
		if global_position.y < Utils.game.camera.get_camera_screen_center().y - Utils.game.resolution_of_visible_rect.y * Utils.game.camera.zoom.y * 0.5:
			move.y = max(0, move.y)
		elif global_position.y > Utils.game.camera.get_camera_screen_center().y + Utils.game.resolution_of_visible_rect.y * Utils.game.camera.zoom.y * 0.5:
			move.y = min(0, move.y)
	
	if is_dashing:
		dash_move = move
		speed = 200
		linear_velocity = move * speed
	else:
		dash_move = Vector2()
		applied_force = move * speed
		
	if is_stuck:
		is_dashing = false
		applied_force=Vector2.ZERO
		state.linear_velocity=Vector2.ZERO
		linear_velocity=Vector2.ZERO
	
	pixel_map_physics(state, Utils.walkable_collision_mask)
	if is_dashing:
		if state.linear_velocity.dot(linear_velocity) <= 0:
			state.linear_velocity = linear_velocity * 0.5
			if squeezer:
				squeezer.kill()
			squeezer = create_tween()
			squeezer.tween_property(self, "radius", 4, 0.1)
			squeezer.tween_interval(0.5)
			squeezer.tween_property(self, "radius", 6, 0.5)
			is_dashing = false
			animation_state = DASH_TAIL
			torso_animator.advance(9999)
			Utils.play_sample(Utils.random_sound("res://SFX/Weapons/BodyFlesh/Body Flesh "), self, false, 1.0, 0.8)
	rotation = 0

var assist_timeout: float
var last_assist_angle: float

const ASSIST_STEPS = 5
const ASSIST_RADIUS = 10.0
const ASSIST_INITIAL = 40.0
const ASSIST_SPACING = 28.0

func get_look_angle(ignore_alternate := false) -> float:
	var angle := get_look_angle2(ignore_alternate)
	if angle == INF:
		angle = torso.rotation
	
	assisted = false
	var steps := ASSIST_STEPS
	if not Save.config.aim_hack:
		steps = 0
	
	for i in steps:
		var min_enemy_pos: Vector2
		var min_dist := INF
		
		var enemies = Utils.game.map.enemy_tracker.getTrackingNodes2DInCircle(global_position + Vector2.RIGHT.rotated(angle) * (ASSIST_INITIAL + ASSIST_SPACING * i), ASSIST_RADIUS + i * 2, true)
		for enemy in enemies:
			if Utils.game.map.pixel_map.rayCastQTFromTo(global_position, enemy.global_position, Utils.turret_bullet_collision_mask):
				continue
			
			var dist = enemy.global_position.distance_squared_to(global_position)
			if dist < min_dist:
				min_dist = dist
				min_enemy_pos = enemy.global_position
				var enemy_vel= enemy.get("velocity")
				if enemy_vel != null:
					var distn=clamp(min_enemy_pos.distance_to(global_position)*0.02,0.0,1.0)
					min_enemy_pos += enemy_vel*0.2*distn
		
		var found_target_data_result = Utils.game.map.enemies_group.get_closest_swarm_unit_in_circle_that_pass_raycast_test_on_pixel_map(global_position + Vector2.RIGHT.rotated(angle) * (ASSIST_INITIAL + ASSIST_SPACING * i), ASSIST_RADIUS, true, true, Utils.turret_bullet_collision_mask, true, 0)
		if found_target_data_result and found_target_data_result.swarm_unit_id != -1:
			if found_target_data_result.node.getUnitPosition(found_target_data_result.swarm_unit_id).distance_squared_to(global_position) < min_dist:
				min_enemy_pos = found_target_data_result.node.getUnitPosition(found_target_data_result.swarm_unit_id)
				var distn=clamp(min_enemy_pos.distance_to(global_position)*0.02,0.0,1.0)
				min_enemy_pos += found_target_data_result.node.getUnitVelocity(found_target_data_result.swarm_unit_id)*0.2*distn
		
		if min_enemy_pos != Vector2():
			angle = global_position.direction_to(min_enemy_pos).angle()
			assisted = true
			break
	
	if assisted:
		assist_timeout = 0
		last_assist_angle = angle
	elif assist_timeout < 4:
		assist_timeout += 1
		angle = last_assist_angle
	
	return angle

func get_look_angle2(ignore_alternate := false) -> float:
	if is_nan(get_mouse_pos().x) or is_nan(get_mouse_pos().y):
		prints("NaN invasion!", "Mouse:", get_viewport().get_mouse_position(), "SubViewport:", get_viewport().size)
		return INF
		
	if force_rotation >= 0:
		return force_rotation
	
	if using_joypad():
		var joylook := Input.get_vector(get_p_action("look_left"), get_p_action("look_right"), get_p_action("look_up"), get_p_action("look_down"))
		if not ignore_alternate and not Save.config.alternate_movement and is_zero_approx(joylook.length_squared()):
			joylook = Input.get_vector(get_p_action("left"), get_p_action("right"), get_p_action("up"), get_p_action("down"))
		
		if joylook == Vector2() and OS.has_feature("mobile"):
			joylook = Vector2(Input.get_action_strength(get_p_action("right")) - Input.get_action_strength(get_p_action("left")), Input.get_action_strength(get_p_action("down")) - Input.get_action_strength(get_p_action("up"))).normalized()
		
		if joylook.length_squared() > 0:
			return joylook.angle()
	else:
		return global_position.direction_to(get_mouse_pos()).angle()
	return INF

func shoot(weapon: Dictionary) -> bool:
	shooting = true
	
	var data: Dictionary = get_upgraded_data(Const.Items[weapon.id])
	
	if "variable_throw" in data and throwing_power == 0 and animation_state != DASH and animation_state != DASH_TAIL:
		set_held_item(weapon, true)
		thrown_item = weapon
		animation_state = THROW
		return false
	
	if "item_ammo" in data:
		if get_item_count(data.item_ammo, null, false) == 0:
			return false
		elif not "infinite" in data:
			subtract_item(data.item_ammo)
	
	if "delay" in data:
		if not can_use_delayed(weapon):
			return false
		
		if "last_shot" in weapon:
			weapon.last_shot = Time.get_ticks_msec()
		else:
			var delay: int = get_upgraded(data, "delay")
			weapon.timer = min(weapon.timer, delay * data.delay_uses) - delay
	
	if "reload" in data and is_reload_active(weapon.id):
		if Time.get_ticks_msec() - weapon.reload_time < get_upgraded(data, "reload_time"):
			return false
		
		weapon.reload -= 1
		if weapon.reload == 0:
			reload_weapon(weapon)
	
	if "recoil" in data:
		var recoil = get_upgraded(data, "recoil")
#		var rot: float = recoil
#		torso.set_deferred("rotation", torso.rotation + rot)
		Utils.vibrate(recoil * 2, recoil * 2, 0.1)
		Utils.game.shake_in_direction(recoil * 10, - Vector2.RIGHT.rotated(get_shoot_rotation()), 0.1, 20, 0.25 + recoil_stability)
	
	if "drop_shells" in data:
		map.pixel_map.flesh_manager.spawn_shell(position, -Vector2.RIGHT.rotated(get_shoot_rotation()) * 20)
		get_tree().create_timer(0.3).connect("timeout", Callable(Utils, "play_sample").bind(Utils.random_sound("res://SFX/Bullets/bullet_shell_bounce_concrete1"), self))
	
	if gun_audio:
		gun_audio.shoot()
	
	if "use_vibration" in data:
		Utils.vibrate(data.use_vibration.x, data.use_vibration.y, data.use_vibration.z)
	
	if "shoot_scene" in data:
		if data.has("damage"):
			var mod := 0.0 if on_stand else 2.0
			linear_velocity -= Vector2.RIGHT.rotated(get_shoot_rotation()) * data.damage * mod
		shoot_attack(weapon, data.shoot_scene, get_shoot_rotation(), randf_range(-0.01, 0.01) + randf_range(-0.01, 0.01))
		recoil_stability = min (0.7, recoil_stability + 0.1)
		return true
	
	if "melee_scene" in data:
		var scene = data.melee_scene
		if is_fear_enabled and "melee_scene.fear" in data:
			scene = data["melee_scene.fear"]
		melee_attack(weapon, scene)
		return true
	
	if "throwable_scene" in data:
		set_held_item({id = 0}, true)
		throw_attack(weapon, data.throwable_scene)
		return true
	
	match weapon.id:
		Const.ItemIDs.PLASMA_GUN:
			check_hp()
			shoot_energy_ball(weapon.data)
		Const.ItemIDs.SHOTGUN:
			linear_velocity -= Vector2.RIGHT.rotated(get_shoot_rotation()) * data.damage*10
			Utils.play_sample(Utils.random_sound("res://SFX/Weapons/gun_shotgun_shot"), self).volume_db=-5.0
			create_tween().tween_interval(0.5).connect("finished", Callable(Utils, "play_sample").bind(Utils.random_sound("res://SFX/Weapons/gun_shotgun_cock"), self))
			for i in min(get_item_count(Const.ItemIDs.AMMO, Const.Ammo.BULLETS) + get_upgraded(data, "ammo_reduction"), get_upgraded(data, "ammo_per_shot")):
				shoot_attack(weapon, "res://Nodes/Player/Weapons/Ranged/ShotgunBullet.tscn", get_shoot_rotation(), randf_range(-0.1, 0.1) + randf_range(-0.1, 0.1))
		Const.ItemIDs.FLAMETHROWER:
			torso_animator.play("Shoot")
			torso_animator.seek(0, true)
			animation_state = SHOOT
			if gun_sprite and gun_sprite.has_method("shoot"):
				gun_sprite.shoot()
			
#			for i in get_upgraded(data, "flame_amount"):
#				var flame := shoot_attack(weapon, "res://Nodes/Player/Weapons/Ranged/Flame.tscn", get_shoot_rotation())
#				flame.damping += get_upgraded(data, "weapon_range") * 0.01
		Const.ItemIDs.MEDPACK:
			if min(hp + 59, get_max_hp()) >= 0.95*get_max_hp():
				SteamAPI.unlock_achievement("THE_CURE")
			heal(50 if Save.is_tech_unlocked("better_healing") else 20)
		Const.ItemIDs.TECHNOLOGY_ORB:
			Utils.play_sample(preload("res://SFX/Pickups/orb_use.wav"))
			emit_signal("orb_used", inventory_select)
			var particles = preload("res://Nodes/Effects/upgrade_particles.tscn").instantiate()
			particles.position=position
			Utils.game.map.add_child(particles)
			
			SteamAPI.increment_stat("Orbs")
			if "technology" in weapon.data:
				Save.unlock_tech(weapon.data.technology)
			elif "weapon_upgrade" in weapon.data:
				var id := Const.ItemIDs.keys().find(weapon.data.weapon_upgrade.get_slice("/", 0))
				var upgrade: String = weapon.data.weapon_upgrade.get_slice("/", 1)
				var upgrade_data: Dictionary = Utils.get_weapon_upgrade_data(id, upgrade)
				Save.set_unlocked_tech(str(id, upgrade), min(Save.get_unclocked_tech(str(id, upgrade)) + weapon.data.upgrade_level, upgrade_data.costs.size()))
			elif "player_upgrade" in weapon.data:
				for i in weapon.data.level:
					call({health = "upgrade_max_hp", speed = "upgrade_speed", luck = "upgrade_luck", stamina = "upgrade_max_stamina", backpack = "upgrade_max_stacks"}[weapon.data.player_upgrade])
	return true

func create_energy_ball(upgrades: Dictionary, dir: Vector2) -> Node2D:
	var ball := preload("res://Nodes/Player/Weapons/Ranged/PlasmaGun/EnergyBall.tscn").instantiate() as Node2D
	ball.direction = dir
	ball.position = get_shoot_point()
	
	ball.size = 1 + upgrades.get("size", 0)
	ball.dig = upgrades.get("dig", 0)
	ball.bounce = upgrades.get("bounce", 0)
	ball.explosion = upgrades.get("explosion", 0)
	
	map.call_deferred("add_child", ball)
	return ball

func damage(data: Dictionary) -> bool:
	if dead:
		return false
	
	Utils.game.start_battle()
	var damager = data.get("owner")
	
	var dmg: int
	if damager is Node2D:
		if damager.is_in_group("enemies"):
			dmg = damager.damage
		elif "falloff" in data:
			dmg = damager.get_falloff_damage()
		else:
			dmg = damager.get_meta("data").damage
		if randf_range(0,100) < get_luck():
			dmg=0
			if Save.config.show_damage_numbers:
				Utils.game.map.add_dmg_number().miss(self)
		linear_velocity += ((global_position - damager.global_position).normalized() * dmg * 15).limit_length(1000.0)
	elif damager is int:
		dmg = 5
	else:
		dmg = data.damage
	
	if dmg == 0:
		return false
	
	if data.get("is_lava"):
		just_damaged_by_lava = true
	if data.get("is_squashed"):
		just_damaged_by_gate = true


	if is_fear_enabled:
		$Fear.add_fear(dmg*3)
	
	if not hurt_audio.playing:
		Utils.play_sample(Utils.random_sound("res://SFX/Player/Male taking damage"), hurt_audio, true, 1.1)
	if Save.config.show_damage_numbers:
		Utils.game.map.add_dmg_number().setup(self, dmg, Color.YELLOW)
	Save.count_score("damage_taken", dmg)
	hp = max(hp - dmg, 0)
	emit_signal("hp_changed")
	call_deferred("check_hp")
	heal_delay = 5
	passive_heal_delay = 10
	return true

func heal(h: float):
	just_healed = true
	set_deferred("just_healed", false)
	
	hp = min(hp + h, get_max_hp())
	emit_signal("hp_changed")

func throw_resource(item: Dictionary, dir := Vector2.RIGHT.rotated(get_shoot_rotation())):
	if item.id == Const.ItemIDs.DRILL and get_item_count(Const.ItemIDs.DRILL) == 1:
		Utils.play_sample(preload("res://SFX/Player/UseFail.wav"))
		return
	Utils.play_sample(preload("res://SFX/Player/346373__denao270__throwing-whip-effect.wav"), null, false, 1.2)
	
	throwing = 0.2
	## TODO: można użyć Pickup.launch()
	if item.id < Const.RESOURCE_COUNT:
		var tot: int = ceil(item.amount * (0.5 if is_action_pressed("run") else 1.0)) if throw_timer >= 0.5 else 1.0
		Utils.log_message("P%s drop resource: %sx%s" % [ player_id + 1 , Const.ResourceNames[item.id], tot])
		for i in tot:
			subtract_stack(item, 1)
			map.pickables.spawn_pickable_nice(global_position, item.id,  dir * 100 + linear_velocity)
			dir = Vector2.RIGHT.rotated(get_shoot_rotation()).rotated(randf_range(-0.1, 0.1)) * randf_range(THROW_VARIATION.x, THROW_VARIATION.y)
	else:
		Utils.log_message("P%s drop pickup: %s" % [ player_id + 1 , Utils.get_item_name(item)])
		throw_pickup(dir)
		dir = Vector2.RIGHT.rotated(randf() * TAU)

func throw_pickup(dir := Vector2.RIGHT.rotated(get_shoot_rotation())):
	var cur_item: Dictionary = get_current_item()
	
	var pickup := Pickup.instantiate(cur_item.id)
	#pickup.throwing_disable()
	pickup.data = cur_item.data
	
	if throw_timer >= 0.5 or Const.Items[cur_item.id].get("throw_all"):
		var amount := ceil(cur_item.amount * (0.5 if is_action_pressed("run") else 1.0))
		pickup.amount = amount
		subtract_stack(cur_item, amount)
	else:
		pickup.amount = 1
		subtract_stack(cur_item, 1)
	
	pickup.position = position
	pickup.linear_velocity = dir * 100 + linear_velocity
	map.add_child(pickup)

func get_shoot_point() -> Vector2:
	if gun_sprite and gun_sprite.get("shoot_point"):
		return gun_sprite.shoot_point.global_position
	else:
		return hold_point.global_position

func get_shoot_rotation() -> float:
	return hold_point.global_rotation

func get_shoot_forward() -> Vector2:
	return Vector2.RIGHT.rotated(get_shoot_rotation())

func set_map(m: Map):
	map = m
	assign_pixel_map(map.pixel_map)

func get_current_item() -> Dictionary:
	if inventory_select < 0 or inventory_select >= inventory.size() or inventory[inventory_select].id == -1:
		return {}
	return inventory[inventory_select]

func get_current_item_data() -> Dictionary:
	return Const.Items.get(get_current_item().get("id", -1), {})

func _on_Area2D_body_entered(body):
	area_collided(body)

func area_collided(area) -> void:
	if area is Pickup:
		if throwing > 0 or dead:
			return
		
		if not can_add(area.id, area.data):
			indicate_full()
			return
		
		var remaining := add_item(area.id, area.amount, area.data)
		if remaining > 0:
			area.amount = remaining
			indicate_full()
		else:
			area.collect()
		
		match area.id:
			Const.ItemIDs.LUMEN_CLUMP, Const.ItemIDs.METAL_NUGGET:
				play_pickup(preload("res://SFX/Pickups/clump_collect.wav"))
			Const.ItemIDs.TECHNOLOGY_ORB:
				play_pickup(preload("res://SFX/Pickups/techorb.wav"))
			_:
				play_pickup(preload("res://SFX/Pickups/422709__niamhd00145229__inspect-item.wav"))
		Utils.log_message("P%s get pickup: %s" % [ player_id + 1 , Utils.get_item_name(area.get_data())])
		
	elif area.is_in_group("enemy_projectile"):
		area.set_meta("last_attacked", self)
		Utils.on_hit(area)
		damage(area.get_meta("data"))

func validate_item(item):
	if item.id < Const.RESOURCE_COUNT:
		return
	
	var item_data: Dictionary = Const.Items[item.id]
	if "autofire" in item_data:
		item.autofire = item_data.autofire
	if "infinite" in item_data:
		item.infinite = item_data.infinite
	if "delay" in item_data:
		if "delay_uses" in item_data:
			item.timer = INF
			counters.append(item)
		else:
			item.last_shot = -INF
	if "reload" in item_data:
		item.reload = get_upgraded(item_data, "reload")
		item.reload_time = -INF

func enter_vehicle():
	in_vehicle = true
	hide()

func exit_vehicle():
	in_vehicle = false
	show()

func should_block_controls():
	return block_controls or Utils.game.ui.info_menu.visible

func get_p_action(action: String) -> String:
	return str("p", control_id , "_", action)

func is_action_pressed(action: String, unblockable := false) -> bool:
	if not unblockable and should_block_controls():
		return false
	
	return Input.is_action_pressed(get_p_action(action))

func is_action_just_pressed(action: String, need_modifier := false, unblockable := false) -> bool:
	if not unblockable and should_block_controls():
		return false
	
	if need_modifier and using_joypad() and not is_action_pressed("modifier"):
		return false
	
	if not need_modifier and using_joypad() and is_action_pressed("modifier") and is_modifier_action_pressed():
		return false
	
	var pressed := Input.is_action_just_pressed(get_p_action(action))
	if cancel_override and pressed and action != "cancel" and Input.is_action_just_pressed(get_p_action("cancel")):
		cancel_override.call_func(self)
		return false
	
	return pressed

func is_action_just_released(action: String, ignore_modifier := false) -> bool:
	if should_block_controls():
		return false
	
	if using_joypad() and not ignore_modifier and is_action_pressed("modifier") and is_modifier_action_released():
		return false
	
	return Input.is_action_just_released(get_p_action(action))

func is_action_just_released_with_modifier(action: String) -> bool:
	if using_joypad() and not is_action_pressed("modifier"):
		return false
	
	return is_action_just_released(action, true)

func is_modifier_action_pressed() -> bool:
	for action in MODIFIER_ACTIONS:
		if is_action_pressed(action) or is_action_just_pressed(action, true):
			return true
	return false

func is_modifier_action_released() -> bool:
	for action in MODIFIER_ACTIONS:
		if is_action_just_released(action, true):
			return true
	return false

func get_shoot_action() -> String:
	if using_secondary and not is_action_pressed("modifier"):
		return "shoot2"
	else:
		return "shoot"
	
func is_shooting() -> bool:
	if block_shoot or build_menu:
		return false
	return is_action_pressed(get_shoot_action())

func is_just_shooting() -> bool:
	if block_shoot or build_menu:
		return false
	return is_action_just_pressed(get_shoot_action())

func is_just_not_shooting(strict := false) -> bool:
	if block_shoot:
		return false
	
	if strict:
		return is_action_just_released(get_shoot_action())
	else:
		return is_action_just_released("shoot") or is_action_just_released("shoot2")

func check_hp():
	if dead:
		return
	if hp <= 0:
		inventory_select = 0
		if just_damaged_by_lava:
			SteamAPI.unlock_achievement("DIE_GOLD_LAVA")
		if just_damaged_by_gate:
			SteamAPI.unlock_achievement("DIE_GATE_CRUSH")
		died()
	just_damaged_by_lava = false
	just_damaged_by_gate = false

func expend_stamina(amount: float):
	stamina -= amount
	stamina_delay = stamina_delay_value
	
	if stamina <= 0:
		tired = true
		stamina = 0.0
	elif stamina > get_max_stamina():
		stamina = get_max_stamina()
		stamina_delay = 0
		
	emit_signal("stamina_changed")

func add_item(id: int, amount := 1, data = null, notify := true, rule: int = StackPolicy.MAXIMUM, ignore_stack_size := false) -> int:
	ensure_inventory_size()
	var total_added: int
	
	if rule == StackPolicy.CURRENT:
		var stack := get_current_item()
		if not stack.is_empty() and stack.id == id and stack.data == data:
			var to_add := add_to_stack(stack, amount, id, data, ignore_stack_size)
			amount -= to_add
			total_added += to_add
	elif rule == StackPolicy.MINIMUM:
		var stack := get_min_stack(id, data)
		if not stack.is_empty():
			var to_add := add_to_stack(stack, amount, id, data, ignore_stack_size)
			amount -= to_add
			total_added += to_add
	elif rule == StackPolicy.MAXIMUM:
		var stack := get_max_stack(id, data)
		if not stack.is_empty():
			var to_add := add_to_stack(stack, amount, id, data, ignore_stack_size)
			amount -= to_add
			total_added += to_add
	
	var force: bool
	for k in 2:
		for i in get_max_stacks():
			if amount == 0:
				break
			
			if not force and i < QUICKBIND_SLOTS and inventory_quick_id[i] > -1 and inventory_quick_id[i] != id:
				continue
			
			if i < QUICKBIND_SLOTS:
				inventory_quick_id[i] = -1
			
			var item: Dictionary = inventory[i]
			if item.id == -1 or rule == StackPolicy.FORCE_STACK:
				item = {id = id, amount = 0, data = data, index = i}
				validate_item(item)
				inventory[i] = item
			elif item.id != id or item.data != data:
				continue
			
			var to_add := add_to_stack(item, amount, id, data, ignore_stack_size)
			amount -= to_add
			total_added += to_add
		
		force = true
		
	if inventory_select < 0:
		inventory_select = 0
	
	if notify and total_added > 0:
		Utils.game.ui.itemify(id, total_added, data, self)
	
	call_deferred("restore_binds_from_id", id)
	
	emit_inventory_changed()
	refresh_select()
	return amount

func add_to_stack(stack: Dictionary, amount: int, id: int, data = null, ignore_stack_size := false) -> int:
	var to_add := min(amount, 9223372036854775807 if ignore_stack_size else Utils.get_stack_size(id, data) - stack.amount) as int
	stack.amount += to_add
	return to_add

var skip_select: bool

func subtract_item(id: int, amount := 1, data = null, rule: int = StackPolicy.MINIMUM) -> int:
	while amount > 0:
		var item: Dictionary
		if rule == StackPolicy.CURRENT:
			item = get_current_item()
		elif rule == StackPolicy.MINIMUM:
			item = get_min_stack(id, data)
		elif rule == StackPolicy.MAXIMUM:
			item = get_max_stack(id, data)
		rule = StackPolicy.ANY
		
		if item.is_empty() or item.amount == 0 or item.id != id or item.data != data:
			item = get_item(id, data, true)
		
		if not item.is_empty():
			amount = subtract_stack(item, amount)
		else:
			break
	return amount

func subtract_stack(item: Dictionary, amount: int) -> int:
	if not item.is_empty():
		var sub: int = min(item.amount, amount)
		item.amount -= sub
		
		if item.amount <= 0:
			if is_shooting() and item == held_item:
				block_shoot = true
			call_deferred("erase_stack", item)
		else:
			if not skip_select:
				emit_inventory_changed() # TODO: można lepiej (tylko 1 slot zmieniać)
		return amount - sub
	return amount

func erase_stack(item: Dictionary):
	var slot_to_remove := inventory.find(item)
	inventory[slot_to_remove] = EMPTY_STACK.duplicate()
	inventory[slot_to_remove].index = slot_to_remove
	counters.erase(item)
	var prev_select := inventory_select
	inventory_select = min(inventory_select, inventory.size() - 1)
	handle_slot_change(0)
	
	call_deferred("restore_binds_from_id", item.id)
	
	#	if not inventory_visible and not get_current_item().empty() and not can_use(get_current_item()):
	#		inventory_select -= 1
	
	emit_inventory_changed()
	select_changed(inventory_select != prev_select)

func get_item(id: int, data = null, ignore_empty := false) -> Dictionary:
	for item in inventory:
		if item.id == id and item.get("data") == data and (not ignore_empty or item.amount > 0):
			return item
	return {}

func get_items(id: int) -> Array:
	var items: Array
	for item in inventory:
		if item.id == id:
			items.append(item)
	return items

class DistanceSort:
	var point: Vector2
	func sort_by_distance(a, b):
		if a.global_position.distance_squared_to(point) < b.global_position.distance_squared_to(point):
			return true
		return false

func pay_with(what: int, how_many: int ,build_position: Vector2):
	how_many = subtract_item(what, how_many)
	
	if how_many <= 0:
		return
	
	var running_storages: Array = Utils.game.get_all_running_storages()
	var sorter := DistanceSort.new()
	sorter.point = build_position
	running_storages.sort_custom(Callable(sorter, "sort_by_distance"))

	for storage in running_storages:
		if what == Const.ItemIDs.LUMEN:
			how_many -= storage.use_lumen(how_many)
		else:
			how_many -= storage.use_metal(how_many)
		
		if how_many <= 0:
			return

func pay_with_lumen(how_many: int, build_position: Vector2):
	pay_with(Const.ItemIDs.LUMEN, how_many, build_position)

func pay_with_metal(how_many: int, build_position: Vector2):
	pay_with(Const.ItemIDs.METAL_SCRAP, how_many, build_position)

func get_item_count(id: int, data = null, include_storages := true) -> int:
	var count := 0
	for item in inventory:
		if item.id == id and item.get("data") == data:
			count += item.amount
	
	if include_storages:
		if id == Const.ItemIDs.LUMEN:
			for storage in Utils.game.get_all_running_storages():
				count += storage.stored_lumen
		elif id == Const.ItemIDs.METAL_SCRAP:
			for storage in Utils.game.get_all_running_storages():
				count += storage.stored_metal
	
	return count

func can_add(id: int, data = null) -> bool:
	for item in inventory:
		if item.id == -1:
			return true
		
		if item.id == id and item.get("data") == data and item.amount < Utils.get_stack_size(id, data):
			return true
	
	return false

func get_max_hp(lvl := -1) -> float:
	if lvl < 0:
		lvl = Save.get_unclocked_tech("player" + str(player_id) + "hp_upgrade")
	return max_hp + 10 * lvl
	
func upgrade_max_hp():
	var upgrade_number = Save.get_unclocked_tech("player" + str(player_id) + "hp_upgrade")
	Save.set_unlocked_tech("player" + str(player_id) + "hp_upgrade", upgrade_number + 1)
	heal(get_max_hp(upgrade_number + 1) - get_max_hp(upgrade_number))
	emit_signal("max_changed")
	test_max_upgrade()

func get_velocity(lvl := -1) -> float:
	if lvl < 0:
		lvl = Save.get_unclocked_tech("player"+str(player_id)+"speed_upgrade")
	return max_speed + 25.0 * lvl

func get_speed_display(lvl := -1) -> String:
	if lvl < 0:
		lvl = Save.get_unclocked_tech("player"+str(player_id)+"speed_upgrade")
	return str("+", lvl * 5, "%")

func upgrade_speed():
	var upgrade_number = Save.get_unclocked_tech("player" + str(player_id) + "speed_upgrade")
	Save.set_unlocked_tech("player" + str(player_id) + "speed_upgrade", upgrade_number + 1)
	if upgrade_number == 10:
		SteamAPI.unlock_achievement("UPGRADE_SPEED_11")
	test_max_upgrade()

func get_max_stamina(lvl := -1) -> float:
	if lvl < 0:
		lvl = Save.get_unclocked_tech("player"+str(player_id)+"stamina_upgrade")
	return max_stamina + 20 * lvl
	
func upgrade_max_stamina():
	var upgrade_number = Save.get_unclocked_tech("player"+str(player_id)+"stamina_upgrade")
	Save.set_unlocked_tech("player"+str(player_id)+"stamina_upgrade",upgrade_number+1)
	emit_signal("max_changed")
	test_max_upgrade()

func get_luck(lvl := -1) -> float:
	if lvl < 0:
		lvl = Save.get_unclocked_tech("player" + str(player_id) + "luck_upgrade")
	return luck + 2 * lvl

func get_luck_display(lvl := -1) -> String:
	return "%s%%" % get_luck(lvl)

func upgrade_luck():
	var upgrade_number = Save.get_unclocked_tech("player" + str(player_id) + "luck_upgrade")
	Save.set_unlocked_tech("player" + str(player_id) + "luck_upgrade", upgrade_number + 1)
	test_max_upgrade()

func get_max_stacks(lvl := -1) -> int:
	if lvl < 0:
		lvl = Save.get_unclocked_tech("player" + str(player_id) + "backpack_upgrade")
	return min(max_stacks + lvl, 14) as int
	
func upgrade_max_stacks():
	var upgrade_number = Save.get_unclocked_tech("player" + str(player_id) + "backpack_upgrade")
	Save.set_unlocked_tech("player" + str(player_id) + "backpack_upgrade", upgrade_number + 1)
	
	for i in get_max_stacks() - inventory.size():
		inventory.append(EMPTY_STACK)
	refresh_indices()
	
func test_max_upgrade():
	if Save.get_unclocked_tech("player" + str(player_id) + "luck_upgrade") >= 10:
		if Save.get_unclocked_tech("player" + str(player_id)+"stamina_upgrade") >= 10:
			if Save.get_unclocked_tech("player" + str(player_id) + "speed_upgrade") >= 10:
				if Save.get_unclocked_tech("player" + str(player_id) + "hp_upgrade") >= 10:
					SteamAPI.unlock_achievement("UPGRADE_STATS_MAX")

func can_use(item: Dictionary) -> bool:
	if item.id < Const.RESOURCE_COUNT:
		return false
	
	if not Const.Items[item.id].usable:
		return false
	
	match item.id:
		Const.ItemIDs.MEDPACK:
			return hp < get_max_hp()
		Const.ItemIDs.TECHNOLOGY_ORB:
			if "technology" in item.data:
				return not Save.is_tech_unlocked(item.data.technology)
			elif "weapon_upgrade" in item.data:
				var weapon_id: int = Const.ItemIDs.keys().find(item.data.weapon_upgrade.get_slice("/", 0))
				var upgrade: String = item.data.weapon_upgrade.get_slice("/", 1)
				var data: Dictionary = Utils.get_weapon_upgrade_data(weapon_id, upgrade)
				return Save.get_unclocked_tech(str(weapon_id, upgrade)) < data.costs.size()
			elif "player_upgrade" in item.data:
				return true
#				for i in weapon.data.level:
#					call({health = "upgrade_max_hp", speed = "upgrade_speed", luck = "upgrade_luck", stamina = "upgrade_max_stamina", backpack = "upgrade_max_stacks"}[weapon.data.player_upgrade])
	
	return true

func died():
	if not super_dead:
		Utils.play_sample(preload("res://SFX/Player/Die.wav"), hurt_audio)
		Save.count_score("deaths")
		if Utils.game.players.size() == 1:
			SteamAPI.increment_stat("Deaths")
		
		linear_velocity = Vector2()
		torso_animator.play("Dead")
		torso_animator.playback_speed = 30
		thrown_item = {}
		throwing_power = 0
		throwing_sprite.hide()
		animation_state = DEAD
		deshoot()
		emit_signal("inventory_toggled", false)
		
		dead = true
		dead_timer = 10
		revive_area.can_interact = true
		
		if not get_tree().get_nodes_in_group("player_died_here").is_empty():
			get_tree().get_nodes_in_group("player_died_here").front().queue_free()
		
		var marker := preload("res://Nodes/Player/DeathMarker.tscn").instantiate() as Node2D
		marker.position = global_position
		Utils.game.map.add_child(marker)
	
	if build_menu:
		if build_menu.build_interface: ## multiplayer
			map.post_process.range_dirty = true
			map.post_process.stop_build_mode(global_position)
		build_menu.disappear()
	
	set_held_item({})
	interactable_icon.hide()
	
	if super_dead:
		SteamAPI.increment_stat("Deaths")
		var seq := create_tween()
		seq.tween_property(torso, "modulate:a", 0.0, 1)
		await seq.finished
	else:
		await get_tree().create_timer(torso_animator.get_animation("Dead").length / torso_animator.playback_speed).timeout
	
	var is_any_alive: bool
	for player in Utils.game.players:
		if not player.dead:
			is_any_alive = true
			break
	
	if not is_any_alive or super_dead:
		if Utils.game.sandbox_options.get("drop_items", true):
			var new_inventory: Array
			for i in get_max_stacks():
				new_inventory.append(EMPTY_STACK.duplicate())
			
			var new_secondary := -1
			var new_select := -1
			
			for i in QUICKBIND_SLOTS:
				inventory_quick_id[i] = inventory[i].id
			
			for i in inventory.size():
				if inventory[i].id == Const.ItemIDs.DRILL:
					var j = i
					if i < QUICKBIND_SLOTS:
						new_inventory[i] = inventory[i]
						inventory_quick_id[i] = -1
					else:
						j = QUICKBIND_SLOTS
						new_inventory[j] = inventory[i]
					inventory.remove(i)
					if inventory_secondary == i:
						new_secondary = j
					new_select = j
					break
			
			var dumper: Node2D = preload("res://Nodes/Player/InventoryDumper.tscn").instantiate()
			dumper.position = global_position
			dumper.inventory = inventory
			map.add_child(dumper)
			inventory = new_inventory
			refresh_indices()
			
			inventory_select = new_select
			inventory_secondary = new_secondary
			
			emit_inventory_changed()
		
		var where_revive: Node2D
		
		if Save.clones > 0:
			for reviver_coffin in get_tree().get_nodes_in_group("revivers"):
				where_revive = reviver_coffin
				break
			
			if where_revive:
				Save.clones -= 1
		
		if not where_revive and Utils.game.sandbox_options.get("infinite_lives"):
			where_revive = Utils.game.get_start()
		
		if where_revive and (not Utils.get_meta("debug_active", false) or not Input.is_key_pressed(KEY_F4)):
			if not super_dead:
				Utils.game.add_child(preload("res://Nodes/Effects/Fade.tscn").instantiate())
				await get_tree().create_timer(1).timeout
			
			if where_revive.is_in_group("revivers"):
				where_revive.spawn_player(self, not is_any_alive)
			else:
				if not super_dead:
					revive()
				global_position = where_revive.global_position
		elif not is_any_alive:
			Utils.game.game_over("You died")

func revive():
	heal(9999999)
	dead = false
	super_dead = false
	death_label.get_parent().hide()
	animation_state = NONE
	torso.modulate.a = 1
	torso_animator.play("RESET")
	torso_animator.advance(0)
	held_item = {}
	revive_area.can_interact = false
	respawning = false
	revive_sfx.playing = false
	Utils.call_super_deferred(self, "refresh_select")

var last_indicate_full=0
func indicate_full():
	if Utils.game.frame_from_start-last_indicate_full>90:
		Utils.game.map.add_dmg_number().custom(self, "Inventory Full", Color.BURLYWOOD)
		last_indicate_full=Utils.game.frame_from_start
		emit_signal("full_inventory")

func process_animation():
	var is_walking := linear_velocity.length_squared() > 0.1
	if is_walking:
		SteamAPI.fail_achievement("WAVE_NO_ACTION")
		legs_animator.play()
		legs_animator.playback_speed = linear_velocity.length() / 2.0
	else:
		legs_animator.stop()
	
	if animation_state == NONE:
		if is_walking:
			torso_animator.play()
			torso_animator.playback_speed = linear_velocity.length() / 2.0
		else:
			torso_animator.stop()
	elif animation_state == THROW:
		torso_animator.playback_speed = 30
		if thrown_item:
			torso_animator.play("Throw")
			torso_animator.seek(throwing_power * 28, true)
		else:
			if throwing_melee:
				torso_animator.playback_speed = 45
				torso_animator.play("Throw_melee")
			else:
				torso_animator.play("Throw")
	elif animation_state == SHOOT:
		torso_animator.playback_speed = 30
	elif animation_state == DASH:
		torso_animator.playback_speed = 30
	elif animation_state == DASH_TAIL:
		torso_animator.playback_speed = 30

static func init_weapon(proj: Node2D, pcollider: Area2D, weapon: int) -> Dictionary:
	var data := {}
	
	Utils.init_player_projectile(proj, pcollider, data)
	
	var item_data: Dictionary = Const.Items[weapon]
	if "aspect" in item_data:
		data.aspect = item_data.aspect
		
	if "crit_rate" in item_data:
		data.crit_rate = item_data.crit_rate
		
	data.damage = get_upgraded(item_data, "damage")
	for property in item_data:
		if property.begins_with("custom_") and property.rfind("lv") == -1:
			data[property] = get_upgraded(item_data, property)
	
	var player: Player = proj.get("player")
	if player and player.on_stand:
		proj.z_index = ZIndexer.Indexes.BUILDING_HIGH + 10
		data.good = true
		data.high = true
		if player.on_stand >= 2:
			data.damage = data.damage + ceil(data.damage * 0.2)
	
	return data

static func get_upgraded_data(data: Dictionary) -> Dictionary: ## TODO: Cache jakieś
	var new_data: Dictionary
	
	for key in data:
		if key.begins_with("upgrade") and not key.ends_with("s"):
			var upgrade_data: PackedStringArray = key.split(".")
			if Save.is_tech_unlocked(upgrade_data[1]):
				new_data[upgrade_data[2]] = data[key]
		elif not key in new_data:
			new_data[key] = get_upgraded(data, key)
	
	return new_data

static func get_upgraded(data: Dictionary, property: String, default = null):
	if str(property, ".lv1") in data:
		var level = Save.get_unclocked_tech(str(data.item_id, property))
		if level > 0:
			property += str(".lv", level)
	
	return data.get(property, default)

static func get_weapon_mask(data: Dictionary) -> int:
	return Utils.player_bullet_collision_mask & (~(Utils.walls_mask | 1 << Const.Materials.GATE| 1 << Const.Materials.LOW_BUILDING) if data.get("high") else 0xFFFFFFFF)

func get_ammo(weapon: Dictionary) -> int:
	var data: Dictionary = Const.Items[weapon.id]
	if weapon.id == Const.ItemIDs.MAGNUM and Save.is_tech_unlocked("infinite_gun"):
		return max(1, get_item_count(Const.ItemIDs.AMMO, data.ammo)) as int
	elif "ammo" in data:
		return get_item_count(Const.ItemIDs.AMMO, data.ammo)
	elif "item_ammo" in data:
		return get_item_count(data.item_ammo)
	else:
		return weapon.amount

func shoot_energy_ball(upgrades: Dictionary):
	var ball: Node2D
	
	var multi: int = 1 + upgrades.get("multi", 0)
	for i in multi:
		var offset: int = i - multi / 2
		if offset >= 0 and multi % 2 == 0:
			offset += 1
		var dir := Vector2.RIGHT.rotated(get_shoot_rotation() + offset * PI/16)
		
		if "wave" in upgrades:
			ball = create_energy_ball(upgrades, dir)
			ball.wave_offset = PI
			
			ball = create_energy_ball(upgrades, dir)
			ball.wave_offset = TAU
		else:
			ball = create_energy_ball(upgrades, dir)

func shoot_attack(weapon: Dictionary, scene: String, rot := get_shoot_rotation(), dispersion:float = 0.0) -> Node2D:
#	if apply_damage:
#		damage_item(weapon)
	if weapon.id == Const.ItemIDs.MAGNUM:
		torso_animator.play("Shoot_1h")
	else:
		torso_animator.play("Shoot_2h")
	torso_animator.seek(0, true)
	animation_state = SHOOT

	var bullet := load(scene).instantiate() as Node2D
	if bullet.get("weapon_id") != null:
		bullet.weapon_id = weapon.id
	if bullet.has_method("set_player"):
		bullet.set_player(self)
	
	if gun_sprite and gun_sprite.has_method("shoot"):
		gun_sprite.shoot(bullet)
		SteamAPI.fail_achievement("WIN_NO_GUNS")
		
	bullet.rotation = rot + dispersion
	
	if is_fear_enabled:
		bullet.rotation += randf_range(-$Fear.fear_amount_current, $Fear.fear_amount_current) * 0.005 * randf_range(-$Fear.fear_amount_current, $Fear.fear_amount_current) * 0.005
		
	bullet.position = get_shoot_point()
	map.add_child(bullet)
	if "speed" in bullet:
		bullet.speed -= abs( dispersion * 1000 )
	
	return bullet

func melee_attack(weapon: Dictionary, scene: String):
	if melee:
		return
	
	melee = load(scene).instantiate() as Node2D
#	melee.connect("attacked", self, "damage_item", [weapon], CONNECT_ONESHOT)
	if melee.has_method("set_data"):
		melee.set_data(weapon.data)
	if melee.has_method("set_player"):
		melee.set_player(self)
	
	hold_point.add_child(melee)
	
#	var remo := RemoteTransform2D.new()
#	remo.update_scale = false
#	melee_point.add_child(remo)
#	remo.remote_path = remo.get_path_to(melee)
	
	await melee.tree_exited
#	remo.queue_free()
	melee = null

func throw_attack(weapon: Dictionary, scene: String):
	Utils.play_sample(preload("res://SFX/Player/346373__denao270__throwing-whip-effect.wav"), null, false, 1.2)
	if "variable_throw" in Const.Items[weapon.id]:
		subtract_stack(weapon, 1)
	

		
	var throwable := load(scene).instantiate() as RigidBody2D
	if throwable.has_method("thrown"):
		throwable.thrown(self)
	if throwable.has_method("set_player"):
		throwable.set_player(self)
	throwable.position = position
	
	if is_fear_enabled and throwable.has_method("reduce_lifetime"):
		throwable.reduce_lifetime(1800)
	
	if using_joypad():
		throwable.linear_velocity = Vector2.RIGHT.rotated(torso.rotation) * 50 * (1 + throwing_power * 8) + linear_velocity
	else:
		throwable.linear_velocity = position.direction_to(get_mouse_pos()) * 50 * (1 + throwing_power * 8) + linear_velocity
	
	if throwable.has_method("set_data"):
		throwable.set_data(weapon.data)
	
	map.add_child(throwable)

func throw_melee():
	if throwing_melee:
		melee.throw()
		melee = null
		throwing_melee = false

func damage_item(item: Dictionary):
	if not "durability" in item: #TODO: Trzeba dodać znowu jak trzeba.
		return
#	assert("durability" in item)
	
	item.durability -= 1
	if item.durability <= 0:
		subtract_item(item.id)
		#TODO: Można dać jakiś fajny efekt jak w Zeldzie BotW

func _tech_unlocked(tech: String):
#	if tech.begins_with("Movement Upgrade"):
#		speed_bonus += 100
#		linear_damp += 0.2
	
	match tech:
		"magnet_upgrade":
			magnet_upgrade = 1
		"hp_regeneration":
			health_regen_upgrade = 1
		"auto_heal":
			auto_heal_upgrade = 1
		"stamina_regeneration":
			stamina_regen_upgrade = 1
		"item_detector":
			item_detector_upgrade = true
		"light_upgrade":
			$Torso/FlashLight.scale *= 2
			$Torso/FlashLight2.scale *= 2

func select_changed(show_inventory := true):
	queued_shot = 0
	is_same_in_2_hands()
	inventory_sfx.play()
	emit_signal("inventory_select_changed", show_inventory)
	refresh_select(false)

func refresh_select(with_sort := true):
	if with_sort:
		sort_inventory()
	
	var item := get_current_item()
	set_held_item(item)

func set_held_item(item: Dictionary, is_throwing := false):
	if item == held_item:
		return
	held_item = item
	
	if animation_state == THROW or animation_state == DASH or animation_state == DASH_TAIL or (animation_state == DEAD and not item.is_empty()):
		return
	
	if melee:
		melee.free()
		melee = null
	
	if gun_audio:
		gun_audio.free()
		gun_audio = null
	
	if gun_sprite:
		if is_instance_valid(gun_sprite) and not gun_sprite.is_queued_for_deletion():
			gun_sprite.free()
		gun_sprite = null
	
	if torso_animator and animation_state != DEAD:
		if item.get("id", -1) >= Const.RESOURCE_COUNT and (animation_state == NONE or animation_state == SHOOT):
			torso_animator.play(Const.Items[item.id].get("animation", "Carry"))
			torso_animator.advance(0)
		elif not is_throwing:
			torso_animator.play("Carry")
			torso_animator.advance(0)
	
	if item.is_empty() or item.id == -1:
		return
	
	if item.id < Const.RESOURCE_COUNT:
		set_held_whatever(item)
		return
	
	var data: Dictionary = Const.Items[item.id]
	
	if not hold_point:
		await self.ready
	
	var hold_anything: bool
	if "sprite" in data:
		gun_sprite = item_pool[item.id].instantiate()
#		gun_sprite = load(data.sprite).instance()
		gun_sprite.player = self
		hold_point.add_child(gun_sprite)
		hold_anything = true
	
	if is_throwing and "throw_sprite" in data:
		gun_sprite = Sprite2D.new()
		gun_sprite.texture = load(data.throw_sprite)
		gun_sprite.global_scale = Vector2.ONE * data.get("sprite_scale", 1)
		hold_point.add_child(gun_sprite)
		hold_anything = true
	
	if "melee_scene" in data:
		var scene = data.melee_scene
		if is_fear_enabled and "melee_scene.fear" in data:
			scene = data["melee_scene.fear"]
		melee = item_pool[item.id].instantiate()
#		melee = load(scene).instance() as Node2D
		
		if melee.has_method("set_data"):
			melee.set_data(item.data)
		if melee.has_method("set_player"):
			melee.set_player(self)
		
		if melee.has_method("put_away"):
			hold_point.call_deferred("add_child", melee)
			melee.connect("ready", Callable(melee, "put_away").bind(), CONNECT_ONE_SHOT)
			await melee.tree_exited
			melee = null
		else:
			melee.free()
			melee = null
		hold_anything = true
	
	if not hold_anything:
		set_held_whatever(item)
	
	if not "use_gun_audio" in data:
		return
	
	match item.id:
		Const.ItemIDs.MACHINE_GUN:
			gun_audio = preload("res://Nodes/Effects/Audio/GunAudioController.gd").new()
			match Save.get_unclocked_tech(str(Const.ItemIDs.MACHINE_GUN, "damage")):
				0:
					gun_audio.shot_path = "res://SFX/Turret/gun_submachine_auto_shot_"
				1:
					gun_audio.shot_path = "res://SFX/Turret/gun_semi_auto_rifle_shot_"
				2:
					gun_audio.shot_path = "res://SFX/Turret/gun_machinegun_auto_heavy_shot_"
			add_child(gun_audio)

func set_held_whatever(item: Dictionary):
	melee = Sprite2D.new()
	melee.texture = Utils.get_item_held_icon(item.id, item.get("data"))
	melee.connect("tree_exited", Callable(self, "set").bind("melee", null))
	
	## TODO: usuwać, gdy dash, rzucanie itp
	if item.id >= Const.RESOURCE_COUNT and "sprite_scale" in Const.Items[item.id]:
		melee.scale = Vector2.ONE * Const.Items[item.id].sprite_scale
	else:
		var s: float = max(melee.texture.get_width(), melee.texture.get_height())
		s = min(20 / s, 1)
		melee.scale = Vector2.ONE * s
	
	if item.id < Const.RESOURCE_COUNT:
		melee.scale *= 0.6
	
	hold_point.add_child(melee)
	torso_animator.play("Carry")
	torso_animator.advance(0)

func can_use_delayed(item: Dictionary) -> bool:
	var data: Dictionary = Const.Items[item.id]
	if "timer" in item:
		return item.get("timer") > get_upgraded(data, "delay")
	else:
		var time = Time.get_ticks_msec() - item.last_shot
		var delay = get_upgraded(data, "delay")
		if time > delay:
			return true
		
		if time > delay - 300 and not data.get("autofire", false):
			queued_shot = time + delay
		return false

func is_slot_usable(idx: int, force_true := true) -> bool:
	if force_true:
		return true
	if idx < 0 or idx >= inventory.size():
		return false
	return Const.Items.get(inventory[idx].id, {}).get("usable")

func get_min_stack(id: int, data = null) -> Dictionary:
	var min_stack: Dictionary
	
	for stack in inventory:
		if stack.id != id or stack.data != data:
			continue
		
		if min_stack.is_empty() or stack.amount < min_stack.amount:
			min_stack = stack
	
	return min_stack

func get_max_stack(id: int, data = null) -> Dictionary:
	var max_stack: Dictionary
	
	for stack in inventory:
		if stack.id != id or stack.data != data:
			continue
		
		if stack.amount >= Utils.get_stack_size(stack.id, stack.data):
			continue
		
		if max_stack.is_empty() or stack.amount > max_stack.amount:
			max_stack = stack
	
	return max_stack

const WALK_SFX_FRAMES = [6, 15, 27, 40]

func _on_Legs_frame_changed():
	if legs and legs.frame in WALK_SFX_FRAMES:
		Utils.play_sample(Utils.random_sound("res://SFX/Player/Dirt footsteps"), self).bus = "Footsteps"

func play_pickup(sound: AudioStream):
	var player: AudioStreamPlayer = Utils.play_sample(sound)
	player.pitch_scale = 1.0 + pickup_level * 0.04
	pickup_level += 1
	if pickup_level>=40:
		pickup_level-= ((randi() % 30) + 20)
	pickup_timer.start()

func sort_inventory():
	inventory.sort_custom(Callable(self, "sorter"))
	refresh_indices()

func sorter(item1: Dictionary, item2: Dictionary) -> bool:
	var score1: int = -item1.index
	var score2: int = -item2.index
	return score1 > score2
	
	if item1.id >= Const.RESOURCE_COUNT:
		score1 += 10000
		var data: Dictionary = Const.Items[item1.id]
		
		if data.usable:
			score1 += 100
	
	if item2.id >= Const.RESOURCE_COUNT:
		score2 += 10000
		var data: Dictionary = Const. Items[item2.id]
		
		if data.usable:
			score2 += 100
	
	return score1 > score2

func torso_animation_finished(anim_name: String) -> void:
	if anim_name in ["Shoot_1h", "Shoot_2h"]:
		animation_state = NONE
		torso_animator.play(get_current_item_data().get("animation", "Carry"))
		if melee and melee.has_method("put_away"):
			melee.put_away()
	elif anim_name == "Throw":
		animation_state = NONE
		held_item = {}
		set_held_item(get_current_item())
	elif anim_name in ["Slide_Foreward_Tail","Slide_Left_Tail","Slide_Right_Tail"]:
		animation_state = NONE
		set_held_item(get_current_item())
		if held_item.get("id", -1) >= Const.RESOURCE_COUNT :
			torso_animator.play(Const.Items[held_item.id].get("animation", "Carry"))
			torso_animator.advance(0)
		else:
			held_item = {}



@onready var stuck_timer := $StuckTimer as Timer
var is_stuck=false
func check_stuck() -> void:
	if dead:
		return
	
	topso.visible = map.pixel_map.is_pixel_solid(global_position, Utils.walkable_collision_mask | (1 << Const.Materials.LAVA))
	
	if map.pixel_map.is_pixel_solid(global_position, Utils.walkable_collision_mask):
		topso.show()
		stuck_timer.wait_time = 0.1
		damage({damage = 10, is_squashed = true })
		is_stuck=true
	else:
		stuck_timer.wait_time = 0.5
		is_stuck=false

func deshoot():
	if not shooting:
		return
	shooting = false
	
	if gun_sprite and gun_sprite.has_method("deshoot"):
		gun_sprite.deshoot()

func using_joypad() -> bool:
	if control_id == 1:
		return Utils.is_using_joypad()
	
	if control_id == 2:
		return false
	
	return true

func is_joy_pressed(button: int):
	return Input.is_joy_button_pressed(-1, button) ## TODO: multiplayer

func emit_inventory_changed():
	emit_signal("inventory_changed")
	
	if not refresh_full_resources_pending:
		refresh_full_resources_pending = true
		call_deferred("refresh_full_resources")

func refresh_full_resources():
	refresh_full_resources_pending = false
	var full_lumen: bool
	var full_scraps: bool
	
	full_lumen = true
	full_scraps = true
	
	for stack in inventory:
		if stack.id == -1:
			full_lumen = false
			full_scraps = false
		elif stack.id == Const.ItemIDs.LUMEN and stack.amount < Utils.get_stack_size(Const.ItemIDs.LUMEN, null):
			full_lumen = false
		elif stack.id == Const.ItemIDs.METAL_SCRAP and stack.amount < Utils.get_stack_size(Const.ItemIDs.METAL_SCRAP, null):
			full_scraps = false
		
		if not full_lumen and not full_scraps:
			break
	
	full_resources[Const.ItemIDs.LUMEN] = full_lumen
	full_resources[Const.ItemIDs.METAL_SCRAP] = full_scraps

func leave_coop():
#	map.player_tracker.remove(self)
	Save.data.player_data[Utils.game.players.find(self)] = _get_save_data()
	queue_free()

func reload_weapon(weapon: Dictionary):
	weapon.reload = get_upgraded(Const.Items[weapon.id], "reload")
	weapon.reload_time = Time.get_ticks_msec()
	if gun_sprite and gun_sprite.has_method("reload"):
		gun_sprite.reload()
	
	var reload_sfx := [
		Utils.random_sound("res://SFX/Weapons/gun_revolver_pistol_cylinder_open"),
		Utils.random_sound("res://SFX/Weapons/gun_revolver_pistol_load_bullet"),
		Utils.random_sound("res://SFX/Weapons/gun_revolver_pistol_cylinder_close"),
		Utils.random_sound("res://SFX/Weapons/gun_revolver_pistol_cock")
	]
	get_tree().create_timer(0.5).connect("timeout", Callable(Utils, "play_sample").bind(reload_sfx, self, true))

static func get_from_area(area: Node2D) -> Player:
	if area is Area2D and area.has_meta("player"):
		return area.get_parent() as Player
	return area as Player

func _get_save_data() -> Dictionary:
	var data: Dictionary = Save.get_properties(self, ["position", "hp", "stamina", "inventory_select", "inventory_secondary"])
	
	data.inventory = []
	for i in inventory.size():
		var item: Dictionary = inventory[i].duplicate()
		if item.id == -1:
			item.id = "EMPTY"
		else:
			item.id = Const.ItemIDs.keys()[item.id]
		data.inventory.append(item)
	
	return data

func _set_save_data(data: Dictionary):
	data.erase("inventory_quick")
	Save.set_properties(self, data)
	
	for item in inventory:
		item.id = Const.ItemIDs.keys().find(item.id)
		validate_item(item)
	
	ensure_inventory_size()
	
	connect("ready", Callable(self, "select_changed"))

func block_controls_temp():
	if block_controls:
		return
	
	block_controls = true
	Utils.call_super_deferred(self, "set", ["block_controls", false])

func restore_binds_from_id(id: int):
	if inventory_secondary == -1 and inventory_secondary_id == id:
		for j in inventory.size():
			if inventory[j].id == id:
				inventory_secondary = j
				break

func move_item(shift: int):
	var target = clamp(inventory_select + shift, 0, inventory.size() - 1)
	
	if target == inventory_select:
		return
	
	inventory[inventory_select].index = target
	inventory[target].index = inventory_select
	inventory_select = target
	refresh_select()
	emit_inventory_changed()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		cursor.hide()
	elif what == NOTIFICATION_UNPAUSED:
		cursor.show()
	elif what == NOTIFICATION_PREDELETE:
		build_menu_cached.queue_free()

func can_afford(cost: Dictionary) -> bool:
	for res in cost:
		if cost[res] > get_item_count(res):
			return false
	return true

func is_reload_active(id: int) -> bool:
	if id == Const.ItemIDs.MAGNUM:
		return get_item_count(Const.ItemIDs.AMMO, Const.Ammo.BULLETS) == 0
	else:
		return true

func set_inventory_secondary(idx: int):
	inventory_secondary = idx
	if idx < inventory.size():
		var id = inventory[idx].id
		if id is String:
			id = Const.ItemIDs.keys().find(id)
		inventory_secondary_id = id
	else:
		inventory_secondary_id = -1

func refresh_indices():
	for i in inventory.size():
		inventory[i].index = i

func ensure_inventory_size():
	while inventory.size() < get_max_stacks():
		inventory.append(EMPTY_STACK.duplicate())
	refresh_indices()

func is_same_in_2_hands():
	if inventory_select == -1 or inventory_secondary == -1 or inventory_select == inventory_secondary:
		return
	
	var item1: Dictionary = inventory[inventory_select]
	var item2: Dictionary = inventory[inventory_secondary]
	
	if item1.is_empty() or item1.id < Const.RESOURCE_COUNT or item2.is_empty() or item2.id < Const.RESOURCE_COUNT:
		return
	
	if not Const.Items[item1.id].get("weapon", false) or not Const.Items[item2.id].get("weapon", false):
		return
	
	if item1.id == item2.id:
		SteamAPI.unlock_achievement("DUAL_WIELD")

func update_listener(coop):
	$AudioListener2D.current = Utils.game.main_player == self and not coop

func get_mouse_pos() -> Vector2:
	if Utils.game.get_second_viewport():
		return get_viewport().canvas_transform.affine_inverse() * (get_viewport().get_parent().get_local_mouse_position())
	else:
		return get_global_mouse_position()

func _exit_tree() -> void:
	if is_instance_valid(prev_interactable):
		prev_interactable.remove_interacter(self)

static func set_block_scroll_all(block: bool):
	for player in Utils.game.players:
		player.block_scroll = block

func is_secondary_disabled() -> bool:
	return OS.has_feature("mobile")

#func _draw() -> void:
#	if not Utils.spiral_of_life.is_connected("lazy_process", self, "update"):
#		Utils.spiral_of_life.connect("lazy_process", self, "update")
#
#	for i in ASSIST_STEPS:
#		draw_circle(Vector2.RIGHT.rotated(torso.rotation) * (ASSIST_INITIAL + ASSIST_SPACING * i), ASSIST_RADIUS, Color.white)
