extends "res://Nodes/Buildings/Common/Computer/GenericComputer.gd"

@onready var lab = $"../.."
#var current_player: Player

@export var preferred_tag: String

var tech_to_make_name: String
var tech_to_make_data: Dictionary

func _ready() -> void:
	add_to_group("Lab_computer")
	
	Save.connect("tech_unlocked", Callable(self, "on_tech_unlocked").bind(), CONNECT_DEFERRED)
	lab.connect("lab_finished", Callable(self, "on_lab_finished"))
	
	var idx := get_parent().get_index() - 1
	if idx < lab.saved_tech.size():
		if lab.saved_tech[idx].is_empty():
			return
		tech_to_make_name = lab.saved_tech[idx]
		tech_to_make_data = Const.Technology[tech_to_make_name]
		reload_if_not_disabled()
	else:
		get_random_possible_tech_not_used_on_map()

func get_random_possible_tech_not_used_on_map(ignore_self := false) -> bool:
	if not Utils.game.map.started:
		await Utils.game.map.initialized
	
	for lab_computer in get_tree().get_nodes_in_group("Lab_computer"):
		if lab_computer.tech_to_make_name:
			if ignore_self and lab_computer == self:
				lab.technology_chances[tech_to_make_name] = 50
			else:
				lab.technology_chances[lab_computer.tech_to_make_name] = 0
	
	var tech_list: Dictionary
	var is_any_tech: bool
	for tech in Const.Technology:
		if not Const.Technology[tech].get("hide_in_lab", false) and not tech in Utils.game.map.blocked_technology and not Save.is_tech_unlocked(tech) and Save.is_tech_requirements_unlocked(tech):
			tech_list[tech] = lab.technology_chances.get(tech, 1000)
			if tech_list[tech] > 0:
				is_any_tech = true
	
	if is_any_tech:
		if not preferred_tag.is_empty():
			var has_tagged_tech: bool
			var new_tech: Dictionary
			
			for tech in Const.technology_by_tag[preferred_tag]:
				new_tech[tech] = tech_list.get(tech, 0)
				
				if new_tech[tech] > 0:
					has_tagged_tech = true
			
			if has_tagged_tech:
				tech_list = new_tech
			
			preferred_tag = "" # Tylko raz.
		
		tech_to_make_name = Utils.pick_random_with_chances(tech_list)
		tech_to_make_data = Const.Technology[tech_to_make_name]
		set_disabled(not lab.is_running)
	else:
		if not ignore_self:
			return await get_random_possible_tech_not_used_on_map(true)
		
		tech_to_make_name = ""
		tech_to_make_data = {}
		return false
	
	call_deferred("reload_if_not_disabled")
	return true

func reload_if_not_disabled():
	if not disabled:
		reload()

func _setup():
	if tech_to_make_name:
		set_display_icon(load(tech_to_make_data["icon"]))
		set_normal_icon_color()
		
		if not active:
			return
		
		screen.set_icon(display_icon)
		
		if lab.making:
			if tech_to_make_data.has("name"):
				screen.set_title(tech_to_make_data["name"])
			else:
				screen.set_title("")
			if tech_to_make_data.has("description"):
				screen.set_description(tech_to_make_data["description"])
			else:
				screen.set_description("")
			screen.add_cost(Const.ItemIDs.LUMEN, int(tech_to_make_data["cost"] * lab.research_cost))
			screen.set_display_progress(lab)
			screen.set_long_action("Cancel")
			return
		
		if tech_to_make_data.has("name"):
			screen.set_title(tech_to_make_data["name"])
		else:
			screen.set_title("")
			
		if tech_to_make_data.has("description"):
			screen.set_description(tech_to_make_data["description"])
		else:
			screen.set_description("")
		
		screen.add_cost(Const.ItemIDs.LUMEN, tech_to_make_data["cost"] * lab.research_cost)
		screen.set_interact_action("Research")
	else:
		set_finished_item()

func _make():
	Utils.log_message("P%s ordered: %s" % [screen.current_player.player_id + 1, tech_to_make_data["name"] ] )
	lab.start_make(tech_to_make_name, tech_to_make_data["duration"])
	reload()
	refresh_color()

func _long_make():
	if lab.making:
		lab.cancel_research()

func _can_use() -> bool:
	return tech_to_make_name and not lab.making

func _can_use_long() -> bool:
	return not lab.making.is_empty()

func on_tech_unlocked(tech: String):
	if tech == tech_to_make_name:
		get_random_possible_tech_not_used_on_map()

func on_lab_finished(tech: String):
	if tech == tech_to_make_name:
		get_random_possible_tech_not_used_on_map()

func set_disabled(d: bool):
	super.set_disabled(d)
	reload_if_not_disabled()
