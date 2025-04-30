extends Node2D

@onready var main_window := $BuyUpgradeWindow as Control
@onready var name_label := main_window.get_node("%HeaderTitle") as Label
@onready var description_label := main_window.get_node("%Description") as RichTextLabel
@onready var icon_panel := main_window.get_node("%IconPanel") as Control
@onready var icon := main_window.get_node("%MainIcon") as TextureRect
@onready var controls := main_window.get_node("%Actions")
@onready var costs := main_window.get_node("%Costs")

@onready var progress_container := main_window.get_node("%ProgressContainer")
@onready var progress_panel := main_window.get_node("%ProgressPanel")
@onready var progress_icon := main_window.get_node("%ProgressIcon") as TextureRect
@onready var progress_bar := main_window.get_node("%ProgressBar")
@onready var queue_panel := main_window.get_node("%QueuePanel")
@onready var queue_container := main_window.get_node("%QueueContainer")

@onready var cant_use := main_window.get_node("%CantUse")

@export var vertical_controls: bool
@export var centered_description: bool
@export var hide_header: bool
@export var hide_icon_hbox: bool
@export var can_use_long_override: bool

var owned_computers: Array
var current_computer: Node2D
var long_make_computer: Node2D

var players_inside: Array
var current_player: Player
var disable_delay: float
var pressing_interact: float
var force_close: bool

var current_action: int
var current_cost: int

var active: bool
var hiding: bool
var can_use: bool
var cost_data: Array

var progress_owner: Object
var last_progress_queue_size := -1
var preferred_rect: Rect2
var available_positions: Array
var available_positions2: Array
var original_scale: Vector2

func _enter_tree() -> void:
	if has_node("PreferredSize"):
		await get_tree().idle_frame
		
		$PreferredSize.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 100:
			var pos := get_node_or_null("Position" + str(i + 1))
			if pos:
				pos.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		if is_inside_tree():
			global_rotation = 0
			preferred_rect = Rect2($PreferredSize.global_position, $PreferredSize.size)
	else:
		global_rotation = 0

func _ready() -> void:
	main_window.connect("disappeared", Callable(self, "ui_hidden"))
	cost_data.resize(costs.get_child_count())
	set_process(false)
	
	if vertical_controls:
		main_window.get_node("%Actions").columns = 1
	
	if hide_header:
		main_window.get_node("%Header").hide()
	
	if hide_icon_hbox:
		main_window.get_node("%IconHBox").hide()
		main_window.size.y -= main_window.get_node("%IconHBox").size.y
	
	for i in 100:
		var node = get_node_or_null(str("Position", i + 1))
		if node:
			available_positions.append(node)
			node = get_node_or_null(str("Position", i + 1, "Pos"))
			if node:
				available_positions2.append(position + (node.global_position - global_position))
			else:
				available_positions2.append(position)
		else:
			break
	
	original_scale = scale
	update_config()

func add_player(player: Player):
	players_inside.append(player)
	if not current_player:
		current_player = player
	
	set_process(true)

func remove_player(player: Player):
	players_inside.erase(player)
	if not active and players_inside.is_empty():
		set_process(false)
		if current_computer:
			computer_exit(current_computer)
			current_computer = null
		
		if player == current_player:
			current_player = null
			reset_computer_interactions()

func computer_enter(computer: Node2D):
	cant_use.hide()
	computer.reload()
	if active:
		if computer.get("target_zoom"):
			Utils.game.camera.target_zoom = computer.target_zoom
		else:
			Utils.game.camera.target_zoom = Vector2.ONE / Const.CAMERA_ZOOM
		
		if main_window.showme():
			Utils.play_sample(preload("res://SFX/Building/InterfaceOpen.wav"), self)

func computer_exit(computer: Node2D):
	computer._uninstall()

func _process(delta: float) -> void:
	var player_invalid := not is_instance_valid(current_player)
	
	if not current_player in players_inside or player_invalid:
		disable_delay += delta
	else:
		disable_delay = 0
		
		if active and current_computer:
			if current_player.is_action_pressed("interact"):
				pressing_interact += delta
			elif current_player.is_action_just_released("interact"):
				if pressing_interact >= 0:
					if can_use_computer():
						make_item()
					else:
						fail_item()
				
				if long_make_computer and can_use_computer_long():
					long_make_computer._release_long_make()
			
			if pressing_interact >= 0.5 and can_use_computer_long():
				pressing_interact = -99999
				long_make_computer = current_computer
				long_make_computer._long_make()
	
	if not player_invalid and current_player.is_action_just_pressed("cancel"):
		disable_delay = 1
	
	if disable_delay >= 0.2 or force_close:
		if force_close:
			pressing_interact = -99999
			force_close = false
		hide_ui()
	
	if player_invalid:
		return
	
	var prev_computer := current_computer
	current_computer = null
	
	for computer in owned_computers:
		if current_player.current_interactable == computer.detector:
			current_computer = computer
			break
	
	if current_computer != prev_computer:
		pressing_interact = -99999
		if long_make_computer:
			long_make_computer._release_long_make()
			long_make_computer = null
		
		if prev_computer:
			if current_computer and active:
				Utils.play_sample(preload("res://SFX/Building/InterfaceSelect.wav"), self)
				
			computer_exit(prev_computer)
		
		if current_computer:
			computer_enter(current_computer)
			if active:
				Utils.log_message("P%s change screen: %s" % [current_player.player_id+1, current_computer.screen.name_label.text] )
	
	if is_instance_valid(progress_owner) and active:
		update_progress()

func interact():
	if active:
		if current_player.is_action_just_pressed("interact"):
			pressing_interact = 0
	else:
		if not is_instance_valid(current_computer):
			push_error(str("CRASH! Czy istnieje komputer? ", current_computer != null))
			return
		
		active = true
		current_player.using_computer = self
		
		propagate_call("set_input_player", [current_player])
		reset_computer_interactions()
		computer_enter(current_computer)
		Utils.log_message("P%s interacting: %s, %s" % [current_player.player_id + 1, owner.name, current_computer.screen.name_label.text] )

func reset_computer_interactions():
	var focus := []
	if current_player:
		focus.append(current_player)
	
	for computer in owned_computers:
		computer.detector.focus = focus
		computer.detector.disable_icon = active
		computer.detector.update_interact()

func reset():
	current_action = 0
	for control in controls.get_children():
		control.hide()
	
	can_use = true
	current_cost = 0
	for item in costs.get_children():
		item.hide()
	
	set_title("")
	set_description("")
	set_icon(null)
	
	progress_container.hide()
	progress_panel.hide()
	queue_panel.hide()
	progress_owner = null
	last_progress_queue_size = -1

### MAKE

func add_action(action: String, action_name: String, long := false):
	if current_computer and current_computer.locked:
		cant_use.show()
		return
	
	assert(current_action < 2)
	set_ctrl_pressed(current_action, action, action_name, long)
	current_action += 1

func set_title(title: String, resize=true):
	name_label.text = title
	if resize:
		name_label.set_deferred("size.y", 0)

func set_description(description: String):
	if centered_description:
		description_label.text = "[center]%s[/center]" % tr(description)
	else:
		description_label.text = tr(description)
	description_label.visible = not description.is_empty()
	
	if not description_label.visible and hide_header:
		main_window.get_node("%DescriptionSpacer").hide()
	elif hide_header:
		main_window.get_node("%DescriptionSpacer").show()

func set_icon(i: Texture2D):
	icon.texture = i
	icon_panel.visible = i != null

func set_interact_action(action: String):
	current_action = 0
	add_action("interact", action)

func set_long_action(action: String):
	current_action = 1
	add_action("interact", action, true)

func add_cost(item: int, amount: int, data = null):
	assert(current_cost < 3)
	set_cost(current_cost, item, amount, data)
	current_cost += 1

func add_cost_no_total(item: int, amount: int, data = null):
	assert(current_cost < 3)
	var idx=current_cost
	if not current_player:
		return
	
	var cost := costs.get_child(idx)
	cost.show()
	cost_data[idx] = [item, amount, data]
	
	var current: int = current_player.get_item_count(item, data)
	var can_use2 := current >= amount
	can_use = can_use and can_use2

	if item == Const.ItemIDs.LUMEN:
		cost.get_node("%Icon").texture = preload("res://Resources/Anarchy/Textures/Icons/lumen_64x64L.png")
		cost.get_node("%Icon").get_parent().self_modulate= Color( 0.819608, 0.109804, 0.427451, 1) 
	elif item == Const.ItemIDs.METAL_SCRAP:
		cost.get_node("%Icon").texture = preload("res://Resources/Anarchy/Textures/Icons/metal_64x64L.png")
		cost.get_node("%Icon").get_parent().self_modulate= Color( 0.337255, 0.262745, 0.188235, 1 )
	else:
		cost.get_node("%Icon").texture = Utils.get_item_icon(item, data)
	
	cost.get_node("%Value").text = str(amount)
	cost.get_node("%Value").modulate = Color.WHITE if can_use2 else Color.RED

	current_cost += 1



func add_item_with_cost(item: int, amount: int, data, cost1 := [], cost2 := [], cost3 := []):
	var title = Utils.get_item_name({id = item, data = data})
	if amount > 1:
		title = str(tr(title), " x", amount)
	set_title(title)
	set_icon(Utils.get_item_icon(item, data))
	
	for i in 3:
		var cost: Array = [cost1, cost2, cost3][i]
		
		if cost.is_empty():
			break
		else:
			if cost.size() == 2:
				add_cost(cost[0], cost[1])
			else:
				add_cost(cost[0], cost[1], cost[2])

### -- MAKE

func set_ctrl_pressed(idx: int, action: String, action_name: String, long: bool):
	var tooltip := controls.get_child(idx)
	tooltip.show()
	
	tooltip.set_hold(long)
	tooltip.set_action(action)
	tooltip.set_text(action_name)

func set_cost(idx: int, item: int, amount: int, data, p: Player = null):
	if not current_player:
		return
	
	var cost := costs.get_child(idx)
	cost.show()
	cost_data[idx] = [item, amount, data]
	
	var current: int = current_player.get_item_count(item, data)
	var can_use2 := current >= amount
	can_use = can_use and can_use2
	
	if item == Const.ItemIDs.LUMEN:
		cost.get_node("%Icon").texture = preload("res://Resources/Anarchy/Textures/Icons/lumen_64x64L.png")
		cost.get_node("%Icon").get_parent().self_modulate=Color( 0.819608, 0.109804, 0.427451, 1) 
	elif item == Const.ItemIDs.METAL_SCRAP:
		cost.get_node("%Icon").texture = preload("res://Resources/Anarchy/Textures/Icons/metal_64x64L.png")
		cost.get_node("%Icon").get_parent().self_modulate=Color( 0.337255, 0.262745, 0.188235, 1 )
	else:
		cost.get_node("%Icon").texture = Utils.get_item_icon(item, data)
	
	cost.get_node("%Value").text = str(current, "/", amount)
	cost.get_node("%Value").modulate = Color.WHITE if can_use2 else Color.RED

func hide_ui():
	hiding = true
	Utils.game.camera.target_zoom = Vector2.ONE / Const.CAMERA_ZOOM
	if main_window.hideme() and current_player:
		Utils.play_sample(preload("res://SFX/Building/InterfaceHide.wav"), self)
	if current_computer:
		current_computer._uninstall()

func ui_hidden():
	active = false
	hiding = false
	
	if is_instance_valid(current_player):
		current_player.using_computer = null
	
	if current_player:
		Utils.log_message("P%s interact end: %s" % [current_player.player_id + 1, owner.name] )
	current_player = null
	current_computer = null
	
	if players_inside.is_empty():
		set_process(false)
	
	reset_computer_interactions()
	
	if not players_inside.is_empty():
		current_player = players_inside.front()

func make_item():
	Utils.play_sample(preload("res://SFX/Building/InterfaceAccept.wav"), self)
	for i in current_cost:
		var cost: Array = cost_data[i]
		if cost[0] == Const.ItemIDs.LUMEN:
			current_player.pay_with_lumen(cost[1], current_player.global_position)
		elif cost[0] == Const.ItemIDs.METAL_SCRAP:
			current_player.pay_with_metal(cost[1], current_player.global_position)
		else:
			current_player.subtract_item(cost[0], cost[1], cost[2])
#		set_cost(i, cost[0], cost[1], cost[2])
	
	current_computer._make()

func fail_item():
	Utils.play_sample(preload("res://SFX/Building/InterfaceFail.wav"), self)
	current_computer._fail()

func can_use_computer() -> bool:
	if not current_computer or not current_computer.active or current_computer.locked:
		return false
	return can_use and current_computer._can_use()

func can_use_computer_long() -> bool:
	if not current_computer or not current_computer.active or current_computer.locked:
		return false
	return (can_use or can_use_long_override) and current_computer._can_use_long()

func reload_current_computer():
	if current_computer:
		current_computer.reload()

func set_display_progress(p: Object):
	progress_owner = p
	assert(progress_owner.has_method("get_max_progress"))
	assert(progress_owner.has_method("has_queue"))
	
	progress_container.show()
	update_progress()

func update_progress():
	if progress_owner.get_max_progress() > 0:
		progress_panel.show()
		progress_bar.max_value = progress_owner.get_max_progress()
		progress_bar.value = progress_owner.get_current_progress()
		progress_icon.texture = progress_owner.get_current_item_icon()
	
	if progress_owner.has_queue():
		queue_panel.show()
		
		var queue: Array = progress_owner.get_queue()
		if queue.size() != last_progress_queue_size:
			for i in queue_container.get_child_count():
				if i < queue.size():
					queue_container.get_child(i).show()
					if i < queue_container.get_child_count() - 1:
						queue_container.get_child(i).texture = progress_owner.get_queue_icon(i)
				else:
					queue_container.get_child(i).hide()
		
		last_progress_queue_size = queue.size()

func _exit_tree() -> void:
	if active:
		Utils.game.camera.target_zoom = Vector2.ONE / Const.CAMERA_ZOOM
	
	if current_player:
		current_player.using_computer = null

func reset_window(override_position := 0):
	main_window.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	
	if preferred_rect.has_area():
		if override_position > 0:
			assert(override_position < available_positions.size() + 1)
			main_window.global_position = available_positions[override_position - 1].global_position
			position = available_positions2[override_position - 1]
		else:
			main_window.global_position = preferred_rect.position
		main_window.custom_minimum_size = preferred_rect.size
		
		if not Music.is_game_build():
			await get_tree().idle_frame
			await get_tree().idle_frame
			if main_window.size != Vector2() and main_window.size != preferred_rect.size:
				push_error("Za mały ustawiony rozmiar okna dla %s! Minimalny rozmiar to %s." % [Utils.game.map.get_path_to(self), main_window.size])

func add_custom_control(control: Control):
	if control.get_parent():
		control.get_parent().remove_child(control)
	
	main_window.get_node("%ControlContainer").add_child(control)

func update_config():
	scale = original_scale * Save.config.ui_scale
	if has_node("$PreferredSize"):
		preferred_rect = Rect2($PreferredSize.global_position, $PreferredSize.size)
