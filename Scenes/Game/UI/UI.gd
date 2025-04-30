extends CanvasLayer
class_name GameUI

@onready var notifications_panel := $NotificationPanel
@onready var notifications := $"NotificationPanel/%NotificationContainer"
@onready var objective := $"%Objective"
@onready var info_labels := $InfoLabels

@onready var minimap_panel := $MinimapPanel as Control
@onready var minimap := $"%Minimap" as TextureRect
@onready var info_menu := $InfoMenu as CanvasItem
@onready var full_map := $"%FullMap" as Control
@onready var menu := $PauseMenu as Control

@onready var wave_name_upper := find_child("WaveNameUpper") as Label
@onready var wave_name_lower := find_child("WaveNameLower") as Label
@onready var wave_animator := find_child("WaveAnimator") as AnimationPlayer

@onready var global_turrets := $"%Towers"
@onready var global_resources := [$"TopPanel/%GlobalLumen", $"TopPanel/%GlobalMetal"]
@onready var global_resources_panel := $"TopPanel/%ResourcesPanel"
@onready var minimap_pos := minimap_panel.position

@onready var on_screen_message: PanelContainer = $"%OnScreenMessage"

var disconnected: bool
var fake_joypads = false ## debug
var first_adjust: bool

func _ready() -> void:
	Input.connect("joy_connection_changed", Callable(self, "refresh_buttons"))
	Utils.connect("coop_toggled", Callable(self, "on_toggle_coop"))
	
	if not Music.is_mobile_build():
		$MobileControls.hide()
	
	if Music.is_switch_build():
		$MinimapToggle.set_joypad(JOY_BUTTON_LEFT_SHOULDER, -1)
		minimap_panel.hide()
	else:
		minimap_panel.show()
	
	objective.hide()
#	refresh_buttons()
	
	if not Utils.game.map:
		await Utils.game.map_changed
	
	Utils.game.map.wave_manager.setup_ui($"%WaveTimer", $"%WaveCounter")
	$"TopPanel/%PlayerScore".hide()
	update_notification_panel()
	
	info_labels.hide()
	for node in objective.get_parent().get_children():
		if node != objective:
			node.hide()
			node.connect("visibility_changed", Callable(self, "try_show_info").bind(node))
	
	if Utils.editor and not Save.data.ranked:
		add_child(load("res://Nodes/Editor/EditorConsole.tscn").instantiate())
	
	for res in global_resources:
		res.hide()
	
	create_tween().set_loops().tween_callback(Callable(self, "refresh_global_turrets")).set_delay(0.5)
	Utils.connect_to_lazy(minimap.overlay, "update")

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		refresh_objective()
	
	if what == NOTIFICATION_UNPAUSED:
		if not first_adjust:
			first_adjust = true
			Utils.call_super_deferred(self, "on_toggle_coop", ["nice", true])

func display_wave_name(wave_number: int, wave_name: String):
	wave_name_upper.text = tr("Wave %s") % wave_number
	wave_name_lower.text = tr(wave_name)
	wave_animator.play("ShowWave")

func refresh_buttons(a=null, b=null):
	return ## TODO coś tam
	for button in menu.get_node("Main").get_children():
		if button.name == "Coop":
			button.disabled = menu.no_joypads()
	
	menu.no_controller.visible = menu.no_joypads()
	menu.why.hide()

var block_menu: bool

func _physics_process(delta: float) -> void:
	if not Utils.game.map or Save.is_saving:
		return
	
#	minimap.screen_center_position = Utils.game.camera.get_camera_screen_center()
	minimap.screen_center_position = Utils.game.camera_target.global_position
	
	if block_menu or menu.is_confirm_quit_dialog_open:
		return
	
	var joypads_only := true
	
	for player in Utils.game.players:
		if player.control_id == Player.Controls.MIXED or player.control_id == Player.Controls.KEYBOARD:
			joypads_only = false
		
		var canceling = player.is_action_just_pressed("cancel")
		if player.after_build or player.using_computer or (player.build_menu and canceling) or player.dead:
			continue
		
		if not info_menu.visible and player.is_action_just_pressed("menu") or (menu.visible and canceling):
			player.block_controls_temp()
			menu.toggle(menu.visible and player.is_action_just_pressed("cancel"))
			break
		
		if info_menu.visible and player.is_action_just_pressed("cancel", false, true):
			player.block_controls_temp()
			toggle_map()
			break
	
	if joypads_only and Input.is_action_just_pressed("p2_menu"):
		menu.toggle(false)

func evil_notify(text: String, time := 4.5, color :Color= Const.UI_MAIN_COLOR):
	notify(text, time, color, true)

func notify(text: String, time := 4.5, color :Color= Const.UI_MAIN_COLOR, evil := false):
	if evil:
		Utils.play_sample(preload("res://SFX/Misc/EvilNotification.wav"))
	else:
		Utils.play_sample(preload("res://SFX/Misc/Notification.wav"))
	
	var notlabel = preload("res://Resources/Anarchy/Scenes/UIElements/hud_messages_left_message.tscn").instantiate()
	notlabel.set_text(text)
	notifications.add_child(notlabel)
	update_notification_panel()
	
	var seq := create_tween()
	for i in 2:
		seq.tween_property(notlabel, "modulate", color, 0.1)
		seq.tween_property(notlabel, "modulate", Color.WHITE, 0.1)
	seq.tween_interval(time)
	seq.tween_property(notlabel, "modulate:a", 0.0, 0.5)
	seq.tween_callback(Callable(notlabel, "free"))
	seq.tween_callback(Callable(self, "update_notification_panel"))

func itemify(id: int, amount: int, data, player):
	var last_notif: Control
	var notlabel: Control
	var item_meta: Dictionary
	
	if notifications.get_child_count() > 0:
		last_notif = notifications.get_child(notifications.get_child_count() - 1)
		if last_notif.has_meta("item"):
			item_meta = last_notif.get_meta("item")
	
	if (item_meta.is_empty() or item_meta.id != id or item_meta.data != data) and notifications.get_child_count() > 1:
		last_notif = notifications.get_child(notifications.get_child_count() - 2)
		if last_notif.has_meta("item"):
			item_meta = last_notif.get_meta("item")
	
	if item_meta.is_empty() or item_meta.id != id or item_meta.data != data or item_meta.player != player:
		notlabel = preload("res://Resources/Anarchy/Scenes/UIElements/hud_messages_left_message.tscn").instantiate()
		notifications.add_child(notlabel)
		
		if Utils.game.players.size() > 1: ## TODO
			notlabel.set_player_color(Const.PLAYER_COLORS[player.player_id])
	else:
		item_meta.tween.kill()
		amount += item_meta.amount
		notlabel = last_notif
		notlabel.modulate.a = 1
	
	var seq := create_tween()
	seq.tween_property(notlabel, "position:x", -30.0, 0.05)
	seq.parallel().tween_property(notlabel, "modulate", Const.UI_MAIN_COLOR, 0.05)
	seq.tween_property(notlabel, "position:x", 0.0, 0.1)
	seq.parallel().tween_property(notlabel, "modulate", Color.WHITE, 0.1)
	seq.tween_interval(2)
	seq.tween_property(notlabel, "modulate:a", 0.0, 0.5)
	seq.tween_callback(Callable(notlabel, "remove_meta").bind("item"))
	seq.tween_callback(Callable(notlabel, "free"))
	seq.tween_callback(Callable(self, "update_notification_panel"))
	
	update_notification_panel()
	notlabel.set_icon(Utils.get_item_icon(id, data))
	notlabel.set_text(str(tr(Utils.get_item_name({id = id, data = data})), " +", amount, " (", player.get_item_count(id, data, false), ")"))
	notlabel.set_meta("item", {id = id, amount = amount, data = data, tween = seq, player = player})

var cutscene_memo: Array

func start_cutscene():
	cutscene_memo.resize(get_child_count())
	for control in get_children():
		cutscene_memo[control.get_index()] = control.visible
		control.hide()
	
	$Bars.show()
	$Bars/AnimationPlayer.play("Bars")
	for player in Utils.game.players:
		player.force_rotation = player.get_look_angle()
		player.torso_animator.playback_speed = 0
		player.in_vehicle = true

func finish_cutscene():
	$Bars/AnimationPlayer.play_backwards("Bars")
	await $Bars/AnimationPlayer.animation_finished
	
	for control in get_children():
		if control.get_index() < cutscene_memo.size():
			control.visible = cutscene_memo[control.get_index()]
	cutscene_memo.clear()
	for player in Utils.game.players:
		player.force_rotation = -1
		player.in_vehicle = false ## Jak będą pojazdy to może zepsuć.

func toggle_map():
	# $InfoMenu.set_active(not $InfoMenu.visible)
#	$"%MinimapPanel".visible = not info_menu.visible
	if not info_menu.visible:
		for player in Utils.game.players:
			if player.using_joypad():
				player.cursor.modulate.a = 0
	else:
		for player in Utils.game.players:
			player.cursor.modulate.a = 1
	
	info_menu.set_active(not info_menu.visible)

var objective_id: int = -1
var objective_text: String

func set_objective(id: int, o: String, allow_repeat := false, won := false):
	if Utils.game.sandbox_options.get("sandbox_mode", false):
		return
	
	if id < objective_id or id == objective_id and not allow_repeat:
		return
	objective_id = id
	objective_text = o
	
	objective.show()
	info_labels.show()
	refresh_objective()
	
	Utils.play_sample(preload("res://SFX/Misc/NewObjective.wav"))
	var seq := create_tween()
	for i in 8:
		seq.tween_property(objective.icon_node, "modulate", Color.WHITE, 0.1)
		seq.parallel().tween_callback(Callable(objective, "set_modulate").bind(Const.UI_MAIN_COLOR))
		seq.tween_property(objective.icon_node, "modulate", Color.GOLD, 0.1)
		seq.parallel().tween_callback(Callable(objective, "set_modulate").bind(Color.WHITE))
	seq.tween_property(objective.icon_node, "modulate", Color.WHITE, 0.1)
	if won:
		seq.parallel().tween_property(objective, "self_modulate", Color.CYAN, 0.1)

func refresh_objective():
#	objective.text = str("  ", tr(objective_text))
	objective.text = objective_text

func get_player_ui(idx: int) -> Node:
	return get_node_or_null(str("Player", idx))

var resulted: bool

func show_result(win: bool):
	if resulted:
		return
	Utils.game.endgame_log()
	resulted = true
	block_menu = true
	
	for control in get_children():
		control.hide()
	
	if win:
		SteamAPI2.achievements.end_map()
	
	var result := preload("res://Nodes/UI/Result.tscn").instantiate()
	result.win = win
	get_tree().root.call_deferred("add_child", result)
	return result

func on_toggle_coop(enable, refresh := false):
	if enable is String: # nice
		enable = Utils.game.is_coop_active()
	
	$"%MinimapVisibler".visible = not enable
	$"%MinimapVisibler2".visible = enable
	global_resources_panel.visible = enable
	if Save.campaign and not refresh:
		Save.campaign.coop = enable
	
	if enable:
		minimap_panel.position.y = Utils.game.resolution_of_visible_rect.y - minimap_panel.size.y - minimap_pos.y
#		info_labels.set_anchors_and_margins_preset(Control.PRESET_BOTTOM_WIDE)
#		info_labels.grow_horizontal = Control.GROW_DIRECTION_BOTH
		for res in global_resources:
			res.show()
		refresh_global_resources()
	else:
		minimap_panel.position.y = minimap_pos.y
		for res in global_resources:
			res.hide()
#		info_labels.set_anchors_and_margins_preset(Control.PRESET_BOTTOM_RIGHT)
#		info_labels.grow_horizontal = Control.GROW_DIRECTION_BEGIN

func refresh_global_resources():
#	if not global_resources.is_visible_in_tree():
#		return
	
	var count := 0
	for storage in Utils.game.get_all_running_storages():
		count += storage.stored_lumen
	global_resources[0].get_node("%Value").text = str(count)

	count = 0
	for storage in Utils.game.get_all_running_storages():
		count += storage.stored_metal
	global_resources[1].get_node("%Value").text = str(count)

func refresh_global_turrets():
	global_turrets.get_node("%Value").text = "%s/%s" % [BaseBuilding.get_turret_count(), BaseBuilding.get_max_turrets()]

func is_ui_hidden() -> bool:
	return not cutscene_memo.is_empty()

func update_notification_panel():
	notifications_panel.visible = notifications.get_child_count() > 0
	on_toggle_coop(Utils.game.is_coop_active(), true)

func try_show_info(for_node: CanvasItem):
	if disconnected:
		return
	disconnected = true
	
	if for_node.visible:
		info_labels.show()
		for node in objective.get_parent().get_children():
			if node != objective:
				node.disconnect("visibility_changed", Callable(self, "try_show_info"))
