extends Control

@export var mirrored: bool

@onready var hp_label := $"TopLeft/%Status/Hp/Value" as Label
@onready var health_bar := $"TopLeft/%Status/Hp" as ProgressBar
@onready var healing_label := $"TopLeft/%Status/%HealValue" as Label
@onready var healing_bar := $"TopLeft/%Status/%Heal" as ProgressBar
@onready var stamina_label := $"TopLeft/%Status/Stamina/Value" as Label
@onready var stamina_bar := $"TopLeft/%Status/Stamina" as ProgressBar

@onready var health_animator := $"%HealthAnimator" as AnimationPlayer

@onready var current_item := $"TopLeft/%CurrentItem"
@onready var current_ammo := $"TopLeft/%CurrentAmmo"
@onready var secondary_item := $"TopLeft/%SecondaryItem"
@onready var quick_binds := $"TopLeft/%QuickBinds"
@onready var inventory := $"Inventory/%InventoryGrid" as GridContainer
@onready var description := $"Inventory/%ItemName" as Label
@onready var description_panel := $"Inventory/%DescriptionPanel" as Control
@onready var inventory_help := $"Inventory/%InventoryButton" as Control
#onready var shift_help := $ItemDescription/ShiftHelp as Control
@onready var key_help := $"Inventory/%Controls" as Control
@onready var controls := $"Inventory/%ActionTooltips" as Control
#onready var select_help := $ItemDescription/ShiftHelp/Select

@onready var resources = [$"TopLeft/%Status/%Lumen", $"TopLeft/%Status/%Metal"]

@onready var description_pos := description.offset_right

var description_top: float
var inventory_spacing: float
var inventory_visible: bool
var inventory_dirty: bool
var slot_index: int

var healed: float
var heal_delay: float

var player: Player
var inventory_animator: Tween

func _ready() -> void:
	get_viewport().connect("size_changed", Callable(self, "refresh_spacing"))
	refresh_spacing()
	inventory.hide()
	description_panel.hide()
	
	if mirrored:
		inventory.raise()
	
	for slot in inventory.get_children():
		slot.can_drag = Callable(self, "can_drag")
		slot.connect("clicked", Callable(self, "on_slot_clicked").bind(slot))
		slot.connect("right_clicked", Callable(self, "on_slot_right_clicked").bind(slot))
		slot.connect("swap", Callable(self, "swap_slots").bind(slot))
		
		if slot.get_index() < Player.QUICKBIND_SLOTS:
			slot.set_bind(slot.get_index() + 1)
	
	for i in Player.QUICKBIND_SLOTS:
		quick_binds.get_child(i).hide_amount()
		quick_binds.get_child(i).set_bind(i + 1)
	
	current_item.set_primary(true)
	secondary_item.set_secondary(true)
	
	if Music.is_mobile_build():
		$Inventory.position.y += 50
	
#	key_help.connect("visibility_changed", self, "on_key_help_toggled")

func set_player(p: Player):
	player = p
	
	if not player:
		if Utils.is_connected("joypad_updated", Callable(self, "on_joypad_update")):
			Utils.disconnect("joypad_updated", Callable(self, "on_joypad_update"))
		
		hide()
		return
	else:
		Utils.connect("joypad_updated", Callable(self, "on_joypad_update"))
		on_joypad_update()
	
	$Indicator.frame = player.player_id
	propagate_call("set_input_player", [player])
	
	player.connect("hp_changed", Callable(self, "refresh_hp"))
	player.connect("stamina_changed", Callable(self, "refresh_stamina"))
	player.connect("max_changed", Callable(self, "refresh_max"))
	player.connect("modifier_toggled", Callable(self, "toggle_modifier"))
	player.connect("inventory_toggled", Callable(self, "toggle_inventory"))
	player.connect("inventory_changed", Callable(self, "queue_refresh_inventory"))
	player.connect("inventory_select_changed", Callable(self, "refresh_select2"))
	player.connect("secondary_select_changed", Callable(self, "refresh_secondary"))
	player.connect("secondary_select_changed", Callable(self, "queue_refresh_inventory"))
	player.connect("orb_used", Callable(self, "play_use_orb"))
	player.connect("update_secondary", Callable(self, "update_secondary"))
	Utils.call_super_deferred(self, "update_secondary")
	
	inventory_dirty = true
	refresh_inventory()
	call_deferred("refresh_max")
	show()

func _process(delta: float) -> void:
	if not player or healed <= 0:
		healing_bar.value = 0
		healing_label.text = ""
		set_process(false)
		return
	
	if heal_delay > 0:
		heal_delay -= delta
		return
	
	healed -= 1
	refresh_hp()

func queue_refresh_inventory(nothing = null):
	inventory_dirty = true
	call_deferred("refresh_inventory")

func refresh_spacing():
	description_top = inventory.get_child(0).global_position.y
	inventory_spacing = (inventory.get_child(inventory.columns).position.y - inventory.get_child(0).position.y) * scale.y

func refresh_hp():
	var health = player.hp
	if player.just_healed:
		healed = player.hp - health_bar.value
		heal_delay = 0.5
		set_process(true)
	
	if healed > 0:
		healing_label.text = "+%s" % ceil(healed)
		health -= healed
		healing_bar.value = player.hp
	
	hp_label.text = str(int(health), "/", int(player.get_max_hp()))
	health_bar.value = health
	hp_label.modulate = Color.RED if player.hp <= 10 else Color.WHITE
	
	if player.hp <= 10 and player.hp > 0:
		health_animator.play("Heartbeat", -1, 4)
	elif player.hp <= 15 and player.hp > 0:
		health_animator.play("Heartbeat", -1, 2)
	elif player.hp <= 20 and player.hp > 0:
		health_animator.play("Heartbeat")
	else:
		health_animator.play("RESET")

func refresh_stamina():
	stamina_label.text = str(int(player.stamina), "/", int(player.get_max_stamina()))
	stamina_bar.value = player.stamina
	
	if player.get_max_stamina() > 100:
		var plus_fract: float = float(player.stamina - 100) / 20
		var plus_count: int = ceil(plus_fract)
#		for plus in stamina_plus.get_children():
#			plus.modulate.a = 0.2 + int(plus.get_index() < plus_count) * 0.8 * (fmod(plus_fract, 1.0) if plus.get_index() == plus_count - 1 and player.stamina < player.get_max_stamina() else 1.0)
	
	if player.tired:
		stamina_bar.modulate = Color.ORANGE_RED
	else:
		stamina_bar.modulate = Color.WHITE

func refresh_max():
	health_bar.max_value = player.get_max_hp()
	healing_bar.max_value = player.get_max_hp()
	refresh_hp()
	
	stamina_bar.max_value = player.get_max_stamina()
	refresh_stamina()

func refresh_inventory():
	if not inventory_dirty:
		return
	inventory_dirty = false
	
	var max_slot: Control
	
	for slot in inventory.get_children():
		var item: Dictionary
		
		if slot.get_index() < player.get_max_stacks():
			slot.show()
			slot.set_secondary(player.inventory_secondary == slot.get_index())
			slot.set_quick(-1)
			for i in Player.QUICKBIND_SLOTS:
				if player.inventory_quick[i] == slot.get_index():
					slot.set_quick(i)
					break
			max_slot = slot
			
			if slot.get_index() < player.inventory.size():
				item = player.inventory[slot.get_index()]
		else:
			slot.hide()
		
		slot.set_item(item)
	
#	for i in Player.QUICKBIND_SLOTS:
#		var idx = player.inventory_quick[i]
#		if idx < player.inventory.size():
#			quick_binds.get_child(i).show()
#			quick_binds.get_child(i).set_item(player.inventory[idx])
#		else:
#			quick_binds.get_child(i).hide()
	
#	key_help.rect_global_position.y = max_slot.rect_global_position.y + 66 * rect_scale.y
	
	refresh_global_available_resources()
	refresh_inventory_colors()
	refresh_secondary()
	
func refresh_global_available_resources():
	resources[0].get_node("%Value").text = str(player.get_item_count(Const.ItemIDs.LUMEN))
	resources[1].get_node("%Value").text = str(player.get_item_count(Const.ItemIDs.METAL_SCRAP))
	
	Utils.game.ui.refresh_global_resources()

func refresh_select(quick := false):
	if not inventory_visible and (not quick or inventory.visible):
		player.inventory_visible2 = true
		inventory.show()
		inventory.modulate = Color.WHITE
		if not player.inventory.is_empty():
			description_panel.show()
			description.modulate = Color.WHITE
		else:
			description_panel.hide()
		
		if inventory_animator:
			inventory_animator.kill()
		
		inventory_animator = create_tween()
		if not quick:
			inventory_animator.tween_interval(1)
		inventory_animator.tween_callback(Callable(key_help, "hide"))
		inventory_animator.tween_property(inventory, "modulate:a", 0.0, 0.5)
		inventory_animator.parallel().tween_property(description, "modulate:a", 0.0, 0.5)
		inventory_animator.tween_callback(Callable(inventory, "hide"))
		inventory_animator.tween_callback(Callable(controls, "hide"))
		inventory_animator.tween_callback(Callable(description_panel, "hide"))
	#	inventory_animator.tween_callback(quick_binds, "show")
		inventory_animator.tween_callback(Callable(inventory_help, "show"))
		inventory_animator.tween_callback(Callable(player, "set").bind("inventory_visible2", false))
	
	refresh_inventory_colors()
#	var show_shift = Save.config.show_control_tooltips and player.is_slot_usable(player.inventory_select, false)
#	shift_help.get_child(1).visible = show_shift 
#	shift_help.get_child(2).visible = show_shift 
#	select_help.visible = Save.config.show_control_tooltips
	key_help.visible = inventory.visible and Save.config.control_tooltips_visible()

func refresh_select2(show_inventory: bool):
	if show_inventory:
		refresh_select(false)
	else:
		refresh_inventory_colors()

func refresh_secondary(nothing = null):
	if player.inventory_secondary == -1 or player.is_secondary_disabled():
		secondary_item.hide()
	else:
		secondary_item.set_item(player.inventory[player.inventory_secondary])
		secondary_item.show()

func refresh_inventory_colors():
	if player.inventory_select == -1 and inventory_visible:
		player.inventory_select = 0
	
	description.text = ""
	var selected_item: Dictionary
	if not player.inventory.is_empty() and player.inventory_select < player.inventory.size():
		selected_item = player.inventory[player.inventory_select]
	
	for slot in inventory.get_children():
		var item: Dictionary = slot.stack
		var item_data: Dictionary
		
#		if false and inventory_visible and player.is_action_pressed("inventory"):
#			slot.set_group(selected_item)
#		else:
#			slot.set_group({})
		
		if player.inventory_select == slot.get_index():
			slot_index = slot.get_index()
			slot.set_selected(true)
			if slot.get_index()!= player.inventory_secondary:
				slot.set_primary(true)
			current_item.set_item(slot.stack)
			
			if not item.is_empty():
				description.text = Utils.get_item_name(item)
		else:
			if slot.get_index()!= player.inventory_secondary:
				slot.set_primary(false)
			slot.set_selected(false)
	
	if description.text.is_empty():
		current_item.set_item({})
		description.text = "Empty"
	
	current_ammo.set_item({})
	
	inventory.get_node("%Use").hide()
	if selected_item:
		if not player.is_inside_tree():
			await player.ready
		
		player.cursor.texture = Utils.get_item_cursor(selected_item.id)
		
		if selected_item.id >= Const.RESOURCE_COUNT:
			var item_data: Dictionary = Const.Items[selected_item.id]
			if "ammo" in item_data:
				var ammo: int = item_data.ammo
				var count := player.get_item_count(Const.ItemIDs.AMMO, item_data.ammo)
				current_ammo.set_item({id = Const.ItemIDs.AMMO, data = ammo, amount = count})
			elif "item_ammo" in item_data:
				var ammo: int =item_data.item_ammo
				var count := player.get_item_count(ammo, null, false)
				current_ammo.set_item({id = ammo, amount = count})
			
			inventory.get_node("%Use").visible = item_data.id != Const.ItemIDs.DRILL and item_data.get("usable", false) and not item_data.get("weapon", false)
	
#	yield(get_tree(), "idle_frame")
#	if mirrored:
#		description.margin_right = description_pos
#		description.margin_left = description_pos
#	else:
#		description.rect_size = Vector2()
#	description.minimum_size_changed()

func toggle_inventory(show: bool):
#	show = not inventory_visible
	inventory_visible = show
	player.inventory_visible = inventory_visible#(player.global_position if inventory_visible else Vector2())
	
	if not show:
		refresh_select(true)
		return
	
	controls.visible = inventory_visible and Save.config.control_tooltips_visible()
	key_help.visible = inventory_visible and Save.config.control_tooltips_visible()
	
	inventory.visible = inventory_visible
	inventory.modulate = Color.WHITE
	description_panel.visible = inventory_visible
	description.modulate = Color.WHITE
	
	if inventory_animator:
		inventory_animator.kill()
		inventory_animator = null
	
	#quick_binds.visible = not inventory_visible
	inventory_help.visible = not inventory_visible
	
	refresh_inventory_colors()

func inventory_visibility_changed() -> void:
	pass
#	resources.visible = not inventory.visible

func on_joypad_update():
#	key_help.get_node("Modifier").visible = player.using_joypad()
#	select_help.get_node("Keyboard").visible = not player.using_joypad()1
#	select_help.get_node("Joypad").visible = player.using_joypad()
	if player.using_joypad():
		toggle_modifier(player.is_action_pressed("modifier"))
	
	inventory.get_node("%Mouse").visible = not player.using_joypad()
	inventory.get_node("%Joy").visible = player.using_joypad()
	inventory.get_node("%Joy2").visible = player.using_joypad()
	$"TopLeft/%ControllerBind".visible = player.using_joypad()
	
	propagate_call("refresh_bind")

func on_key_help_toggled():
	if key_help.visible and player and player.using_joypad():
		toggle_modifier(player.is_action_pressed("modifier"))

func toggle_modifier(active: bool):
	pass
#	if not key_help.visible:
#		return
#
#	key_help.get_node("Modifier").modulate = Color.green if active else Color.white
#	key_help.get_node("AutoWalk").visible = active
	
#	for slot in inventory.get_children():
#		slot.set_quick_visible(active) ## TODO

func on_slot_clicked(slot):
	if not inventory_visible:
		return
	
	player.inventory_select = slot.get_index()
	player.select_changed(true)
	player.block_shoot = true

func on_slot_right_clicked(slot):
	if not inventory_visible:
		return
	
	if slot.get_index() < player.inventory.size() and !player.inventory[slot.get_index()].is_empty() and player.inventory_secondary != slot.get_index():
		player.inventory_secondary = slot.get_index()
	else:
		player.inventory_secondary = -1
	player.block_shoot = true
	refresh_secondary()
	queue_refresh_inventory()

func swap_slots(slot1, slot2):
	slot1.stack.index = slot2.get_index()
	slot2.stack.index = slot1.get_index()
	
	player.refresh_select()
	player.emit_inventory_changed()

func can_drag():
	return inventory_visible

var gui_drag

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		gui_drag = get_viewport().gui_get_drag_data()
	
	if what == NOTIFICATION_DRAG_END:
		if not player or (not OS.has_feature("mobile") and player.using_joypad()):
			return
		
		if inventory.get_global_rect().has_point(get_global_mouse_position()):
			return
		
		if get_viewport().gui_is_drag_successful():
			return
			
		if not gui_drag or not gui_drag is Dictionary:
			return
		
		if gui_drag.get("type") != "stack":
			return
		
		player.throw_timer = 1
		player.throw_resource(gui_drag.from.stack)
		player.throw_timer = 0

func play_use_orb(slot):
	var slot_node = inventory.get_child(slot)
	var icon: TextureRect = slot_node.get_node("%Icon")
	
	var sprite := Sprite2D.new()
	icon.add_child(sprite)
	sprite.position = icon.size * 0.5
	sprite.scale = icon.texture.get_size() / icon.size
	sprite.texture = preload("res://Nodes/Pickups/Orb/TechnologyOrbUse.png")
	sprite.hframes = 8
	
	var tween := create_tween()
	tween.tween_property(sprite, "frame", 7, 0.5)
	tween.tween_interval(0.5 / 7)
	tween.tween_callback(Callable(sprite, "queue_free"))

func update_secondary():
	if not is_instance_valid(player):
		return
	
	if player.is_secondary_disabled():
		$"TopLeft/%SecondaryItem".hide()
		$"Inventory/%Secondary".hide()
		$"Inventory/%Joy".hide()
		$"Inventory/%Joy2".hide()
	else:
		$"TopLeft/%SecondaryItem".show()
		$"Inventory/%Secondary".show()
		$"Inventory/%Joy".show()
		$"Inventory/%Joy2".show()
