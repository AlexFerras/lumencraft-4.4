@tool
extends "res://Nodes/Buildings/Common/Computer/GenericComputer.gd"

@onready var hero_center := get_parent() as BaseBuilding
@onready var lvl_label = $Label

@export var title: String
@export var upgrade_name: String
@export var get_callback: String
@export var get_display_callback: String
@export var upgrade_callback: String
@export var action_name: String = "Upgrade"
@export var base_upgrade_cost: int = 30
@export var level_cost: int = 5

func _ready() -> void:
	if get_display_callback.is_empty() and not Engine.is_editor_hint():
		get_display_callback = get_callback

func set_disabled(disabled: bool, force := false):
	super.set_disabled(disabled)
	
	var upgrade_number=Save.get_unclocked_tech("player"+str(hero_center.owning_player_id) + upgrade_name)
	lvl_label.text=str(upgrade_number)

	if not disabled:
		lvl_label.modulate = Color(0.0, 1.3, 2.5)
	else:
		lvl_label.modulate = Color(0.5, 0.5, 0.5)
	
	lvl_label.visible= not disabled

func _can_use() -> bool:
	return hero_center.get_owning_player() and Save.get_unclocked_tech("player" + str(hero_center.owning_player_id) + upgrade_name) <= 9

func _setup():
	if hero_center.owning_player_id == -1:
		hero_center.owning_player_id = screen.players_inside.front().player_id
		hero_center.update_player_text()
	
	var upgrade_number: int = Save.get_unclocked_tech("player" + str(hero_center.owning_player_id) + upgrade_name)
	lvl_label.text = str(upgrade_number)
	
	if active:
		screen.set_title(str(tr(title), " ", tr("lv"), upgrade_number + 1), false)
		
		var player_indicator := preload("res://Nodes/Buildings/HeroCenter/PlayerIndicator.tscn").instantiate() as Control
		player_indicator.get_node("%Sprite2D").frame = hero_center.owning_player_id
#		screen.set_custom_control(player_indicator) ## TODO
	
	if not hero_center.get_owning_player():
		if active:
			screen.set_description("Player not found")
		return
	
	if not active:
		return
	
	var current_value: int = hero_center.get_owning_player().call(get_callback, upgrade_number)
	var current_value_display = hero_center.get_owning_player().call(get_display_callback, upgrade_number)
	var next_value = hero_center.get_owning_player().call(get_display_callback, upgrade_number + 1)
	if is_finished(upgrade_number, current_value):
		screen.set_description(str(current_value_display, " ", tr("maxed")))
		screen.set_icon(icon_node.texture)
	else:
		screen.set_description(str(current_value_display, " -> ", next_value))
		screen.set_icon(icon_node.texture)
		screen.set_interact_action(action_name)
		screen.add_cost_no_total(Const.ItemIDs.LUMEN, base_upgrade_cost + upgrade_number * level_cost)

func _make():
	Utils.log_message("P%s bought: %s %s" % [screen.current_player.player_id + 1, title, lvl_label.text ] )
	var particles = preload("res://Nodes/Effects/upgrade_particles.tscn").instantiate()
	particles.global_position=hero_center.get_owning_player().global_position
	Utils.game.map.add_child(particles)
	hero_center.get_owning_player().call(upgrade_callback)
	reload()
	get_parent().emit_signal("upgraded")

func is_finished(upgrade_number, current_value) -> bool:
	return upgrade_number > 9
