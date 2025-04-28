extends "res://Nodes/Buildings/Common/Computer/GenericComputer.gd"

const FIRST_UPGRADE_COLOR = Color.LIGHT_GRAY * 1.5
const LAST_UPGRADE_COLOR = Color.GOLD * 1.5

@onready var turret := get_parent()
@onready var upgrade_stars := $"%UpgradeStars" as Node2D

var upgrades: Array
var upgrade_levels: Dictionary
var upgrade_max_levels: Dictionary

var current_upgrade: int
var restricted := false

var full: bool

func _ready() -> void:
	upgrades = turret.building_data.upgrades
	for upgrade in upgrades:
		upgrade_levels[upgrade.name] = turret.start_upgrades.get(upgrade.name, 0)
		upgrade_max_levels[upgrade.name] = upgrade_max_levels.get(upgrade.name, 0) + 1
	
	assert(not upgrades.is_empty())
	assert(upgrade_stars.get_child_count() == upgrade_levels.size(), "Zła liczba gwiazdek, ma być %s" % upgrade_levels.size())
	
	refresh_stars()
	
	turret.connect("ready", Callable(self, "refresh_turret").bind(), CONNECT_ONE_SHOT)

func _setup():
	if current_upgrade == upgrades.size():
		return
	
	var upgrade: Dictionary = upgrades[current_upgrade]
	while upgrade.level < upgrade_levels[upgrade.name] or restricted and upgrade.level > 0:
		current_upgrade += 1
		if current_upgrade < upgrades.size():
			upgrade = upgrades[current_upgrade]
		else:
			break
	
	if current_upgrade == upgrades.size():
		full = true
		set_disabled(true)
		return

	if active and screen.active:
		var attack_range_visual=get_node_or_null("../attack_range_visual")
		if attack_range_visual and not screen.hiding:
			attack_range_visual.visible=true
			Utils.game.map.post_process.range_dirty = true
			Utils.game.map.post_process.start_build_mode(global_position)
			var attack_range_upgrade_visual=get_node_or_null("../attack_range_upgrade_visual")
			if attack_range_upgrade_visual:
				if upgrade.name=="range":
					attack_range_upgrade_visual.visible=true
				else:
					attack_range_upgrade_visual.visible=false
		var upgrade_data: Array = Const.UPGRADES[upgrade.name].split("|")
		screen.set_title(str(tr(upgrade_data[0]), " ", upgrade.level + 1))
		
		var description = PackedStringArray()
		description.append(tr(upgrade_data[1]))
		var requirements: Array = upgrade.get("requirements", [])
		if not requirements.is_empty():
			description.append("")
			description.append("[center]%s[/center]" % tr("Requirements"))
			for req in requirements:
				if BaseBuilding.is_requirement_met(req):
					description.append("[color=#00ff00]%s[/color]" % BaseBuilding.get_requirement_text(req))
				else:
					description.append("[color=red]%s[/color]" % BaseBuilding.get_requirement_text(req))
		screen."\n".join(set_description(description))
		
		for cost in upgrade.cost:
			screen.add_cost(cost.id, cost.amount)
		
		screen.set_interact_action("Upgrade")

func refresh_turret():
	turret._refresh_upgrades(upgrade_levels)
	reload()

func _make():
	upgrade_levels[upgrades[current_upgrade].name] += 1
	refresh_stars()
	reload()
	refresh_turret()
	get_parent().emit_signal("upgraded")
	#Utils.game.map.post_process.range_dirty = true
	if current_upgrade == upgrades.size():
		var turret_type = turret.building_data.name
		if not turret_type in SteamAPI.achievements.turrets:
			SteamAPI.achievements.turrets.append(turret_type)
		
		if SteamAPI.achievements.turrets.size() == 3:
			SteamAPI.unlock_achievement("UPGRADE_ALL_TURRETS")

func _uninstall():
	if screen.active:
		var attack_range_visual=get_node_or_null("../attack_range_visual")
		if attack_range_visual:
			Utils.game.map.post_process.stop_build_mode(global_position)
			attack_range_visual.visible = false
			var attack_range_upgrade_visual=get_node_or_null("../attack_range_upgrade_visual")
			if attack_range_upgrade_visual:
				attack_range_upgrade_visual.visible = false
			Utils.game.map.post_process.range_dirty = true

func _can_use() -> bool:
	if current_upgrade >= upgrades.size():
		return false
	
	var upgrade: Dictionary = upgrades[current_upgrade]
	for requirement in upgrade.get("requirements", []):
		if not BaseBuilding.is_requirement_met(requirement):
			return false
	
	if screen.current_player:
		for cost in upgrade.cost:
			if screen.current_player.get_item_count(cost.id) < cost.amount:
				return false
	
	return true

func get_upgrade_dict() -> Dictionary:
	return upgrade_levels

func refresh_stars():
	turret.cost = turret.building_data.cost.duplicate()
	
	for upgrade in upgrades:
		if upgrade.level < upgrade_levels[upgrade.name]:
			for cost in upgrade.cost:
				turret.cost[cost.id] = turret.cost.get(cost.id, 0) + cost.amount
	var all=true
	for i in upgrade_levels.size():
		var upgrade = upgrade_levels.keys()[i]
		upgrade_stars.get_child(i).visible = upgrade_levels[upgrade] > 0
		var is_last=upgrade_levels[upgrade] == upgrade_max_levels[upgrade]
		all=all && is_last
		upgrade_stars.get_child(i).modulate = LAST_UPGRADE_COLOR if is_last else FIRST_UPGRADE_COLOR
	if all:
		turret.modulate.r=1.5
		turret.modulate.g=0.8
		turret.modulate.b=0.8

