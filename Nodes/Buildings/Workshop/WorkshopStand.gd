extends "res://Nodes/Buildings/Common/Computer/GenericComputer.gd"

@onready var queue_panel := $"%QueuePanel" as Control
@onready var queue_label := $"%QueueLabel" as Label
@onready var upgrade_label := $"%UpgradeLabel" as Label
@onready var status_light := $LightSprite as LightSprite
@onready var workshop := get_parent().get_parent().get_parent()

var item: int
var data
var amount: int
var cost: Array

var custom: PackedScene
var icon: Texture2D
var empty: bool

var upgrades: Array
var current_upgrade: int
var tech_requirement: Array

var special = null
var had_upgrades: bool
var initial_upgrades := -1

var queue: int
var queued_upgrades: Array

signal make

func _setup():
	if can_use():
		set_disabled(false)
		if special != null:
			workshop.special_setup(screen, self)
			return
		elif item:
			set_display_icon(Utils.get_item_icon(item, data))
			
			if active:
				screen.add_item_with_cost(item, amount, data, get_cost(0), get_cost(1), get_cost(2))
				if workshop.current_make_item:
					screen.set_interact_action("Queue")
				else:
					screen.set_interact_action("Create")
		elif custom:
			set_display_icon(icon)
			
			if active:
				screen.set_icon(display_icon)
				screen.set_title(custom.resource_path.get_file().get_basename().capitalize())
				screen.set_interact_action("Create")
				var cost2 := get_cost(0)
				screen.add_cost(cost2[0], cost2[1])
		elif upgrades:
			var upgrade: Dictionary = upgrades[current_upgrade]
			var name_data: PackedStringArray = Const.UPGRADES[upgrade.upgrade].split("|")
			
			if active:
				screen.add_item_with_cost(upgrade.item, 0, null, get_cost(0, upgrade), get_cost(1, upgrade))
			
			if name_data.size() == 3:
				if active:
					screen.set_icon(load(name_data[2]))
				set_display_icon(load(name_data[2]))
			else:
				if active:
					screen.set_icon(preload("res://Nodes/Buildings/Workshop/Sprites/Upgrade.png"))
				set_display_icon(preload("res://Nodes/Buildings/Workshop/Sprites/Upgrade.png"))
			
			if active:
				screen.set_title(str(tr(name_data[0]), " ", tr("lv"), upgrade.level))
				if workshop.current_make_item:
					screen.set_interact_action("Queue")
				else:
					screen.set_interact_action("Upgrade")
			
			upgrade_label.show()
			upgrade_label.text = "%s/%s" % [initial_upgrades - upgrades.size(), initial_upgrades]
		else:
			empty = true
			_setup()
			return
		
		if active:
			screen.set_description(get_description())
			
			if workshop.current_make_item:
				screen.set_display_progress(workshop)
				if not workshop.make_queue.is_empty():
					screen.set_long_action("Cancel Queue") ## to chyba nie działa?
		
		set_icon_tint(Color.WHITE)
	else:
		if had_upgrades:
			upgrade_label.hide()
			set_finished_item()
		else:
			set_no_item()
	refresh()

func get_description() -> String:
	if custom:
		if custom == preload("res://Nodes/Objects/Explosive/ExplosiveBarrel.tscn"):
			return "Movable barrel that explodes on impact."
	elif item:
		return Const.Items[item].get("description", "Error 404 no description")
	elif upgrades:
		var upgrade: Dictionary = upgrades[current_upgrade]
		var name_data: PackedStringArray = Const.UPGRADES[upgrade.upgrade].split("|")
		
		var lines = PackedStringArray([tr(name_data[1])])
		if not upgrade.requirements.is_empty():
			lines.append("")
			lines.append("[center]%s[/center]" % tr("Requirements"))
			for req in upgrade.requirements:
				if BaseBuilding.is_requirement_met(req):
					lines.append("[color=#00ff00]%s[/color]" % BaseBuilding.get_requirement_text(req))
				else:
					lines.append("[color=red]%s[/color]" % BaseBuilding.get_requirement_text(req))
		
		return "\n".join(lines)
	
	return "error 404. Add me in WorkshopStand.gd"

func next_slot():
	while true:
		current_upgrade = (current_upgrade + 1) % upgrades.size()
		
		var upgrade: Dictionary = upgrades[current_upgrade]
		if upgrade.level == 1:
			return
		
		if Save.is_tech_unlocked(str(upgrade.item, upgrade.upgrade, upgrade.level - 1)):
			return

func new_tech(stuff):
	if workshop.is_running:
		reload()

func can_use() -> bool:
	if empty:
		return false
	
	for tech in tech_requirement:
		if not Save.is_tech_unlocked(tech):
			return false
	
	return true

func get_stand_name() -> String:
	if custom:
		return custom.resource_path.get_file().get_basename().capitalize()
	elif item:
		return Utils.get_item_name({id = item, data = data})
	elif upgrades:
		var upgrade: Dictionary = upgrades[current_upgrade]
		var name_data: PackedStringArray = Const.UPGRADES[upgrade.upgrade].split("|")
		return str(Utils.get_item_name({id = upgrade.item}), " - ", name_data[0], " lv", upgrade.level)
	else:
		return "ERROR"

func get_cost(idx: int, upgrade := {}) -> Array:
	var cost2: Array = upgrade.get("cost", cost)
	
	if idx >= cost2.size():
		return []
	var item_cost: Dictionary = cost2[idx]
	return [item_cost.id, item_cost.amount, item_cost.get("data")]

func refresh():
	if queue > 0:
		queue_panel.show()
		queue_label.text = str(queue)
	else:
		queue_panel.hide()

	var color := Color.RED
	if not can_use():
		color = Color.ORANGE_RED
	elif can_use() and item or custom:
		color = Color.GREEN
	elif upgrades:
		color = Color.GOLD
	
	status_light.modulate = color * 5
	status_light.dirty = true

func _make():
#	if not upgrades:
#		screen.force_close = true
	
	emit_signal("make")
	reload()

func _can_use() -> bool:
	if upgrades:
		var upgrade: Dictionary = upgrades[current_upgrade]
		for req in upgrade.requirements:
			if not BaseBuilding.is_requirement_met(req):
				return false
	
	return true

func refresh_upgrades():
	if upgrades.is_empty():
		return
	
	if initial_upgrades == -1:
		initial_upgrades = upgrades.size()
	
	var new_upgrades: Array
	
	for upgrade in upgrades:
		if Save.get_unclocked_tech(str(upgrade.item, upgrade.upgrade)) < upgrade.level:
			new_upgrades.append(upgrade)
	
	upgrades = new_upgrades
	
	if workshop.is_running:
		reload()

func set_disabled(dis: bool):
	super.set_disabled(dis)
	
	if dis:
		queue_panel.hide()
		upgrade_label.hide()

func set_flip_icon(f: bool):
	super.set_flip_icon(f)
	
	if not is_inside_tree():
		await self.is_ready
	
	if f:
		$Labels.rotation = PI

func _long_make():
	workshop.clear_queue()

func pop_upgrade() -> Dictionary:
	had_upgrades = true
	var upgrade: Dictionary = upgrades[current_upgrade]
	upgrades.erase(current_upgrade)
	current_upgrade = min(current_upgrade, upgrades.size() - 1)
	queued_upgrades.append(upgrade)
	return upgrade

func clear_queue():
	if not queued_upgrades.is_empty():
		empty = false
		current_upgrade += queued_upgrades.size()
	
	for upgrade in queued_upgrades:
		upgrades.append(upgrade)
	queued_upgrades.clear()
	queue = 0

func pop_queue():
	queued_upgrades.pop_front()
	queue -= 1
