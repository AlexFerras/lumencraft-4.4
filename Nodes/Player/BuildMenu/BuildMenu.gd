extends Node2D

const CATEGORY_ICONS = {
	"Defense": "res://Resources/Anarchy/Textures/pie/pie_defense.png",
	"Utils": "res://Resources/Anarchy/Textures/pie/pie_utils.png",
	"Upgrades": "res://Resources/Anarchy/Textures/pie/pie_upgrade.png",
	"Workshop": "res://Resources/Anarchy/Textures/pie/pie_workshop.png",
}

@onready var pie := $PieMenu
@onready var tooltip := $"%PieMenuMessageBoxReq" as CanvasItem

@onready var category_buttons = [$"PieMenu/%Utils", $"PieMenu/%Workshop", $"PieMenu/%Defense", $"PieMenu/%Upgrades"]
@onready var select_player := $AudioStreamPlayer

var root: BuildCategory
var current_category: BuildCategory
var category_list: Dictionary

var build_interface: Node2D
var current_focus: Control

var pending_icons: Array

var player: PixelMapRigidBody
var ui: Node
var valid: bool
var dirty: bool = true

signal building_selected(building)

func _ready() -> void:
	set_process(false)
	get_viewport().connect("gui_focus_changed", Callable(self, "focus_changed"))
	
	Save.connect("tech_unlocked", Callable(self, "refresh_tech"))
	player.connect("inventory_changed", Callable(tooltip, "refresh").bind(), CONNECT_DEFERRED)
	player.connect("inventory_changed", Callable(pie, "refresh_buildings").bind(), CONNECT_DEFERRED)
	player.connect("inventory_changed", Callable(self, "refresh_categories").bind(), CONNECT_DEFERRED)
	
	propagate_call("set_input_player", [player])
	
	for button in category_buttons:
		button.connect("pressed", Callable(self, "select_category").bind(button.name))
		button.connect("mouse_entered", Callable(self, "hover_category").bind(button.name))
		button.connect("focus_entered", Callable(self, "hover_category").bind(button.name))
	
	for button in pie.building_row.get_children():
		button.connect("pressed", Callable(self, "select_building").bind(button.get_index()))
		button.connect("mouse_entered", Callable(self, "hover_building").bind(button.get_index()))
		button.connect("focus_entered", Callable(self, "hover_building").bind(button.get_index()))
	
	update_previews()
	update_config()
	
	Save.connect("tech_unlocked", Callable(self, "tech_refresh"))

func tech_refresh(tech):
	# TODO: można filtrować czy coś zmienia
	if is_inside_tree():
		recreate()
	else:
		dirty = true

func _process(delta: float) -> void:
	if pending_icons.is_empty():
		set_process(false)
	else:
		var pending: Array = pending_icons.pop_back()
		if pending[0]:
			pending[1].set(pending[2], load(pending[0]))

func refresh_tech(whatevs):
	if whatevs.begins_with("build"): ## TODO: chyba nie obsługuje wszystkich. Albo wcale...
		recreate()

func recreate() -> bool:
	dirty = false
	pending_icons.clear()
	valid = recreate2()
	return valid

func recreate2() -> bool:
	if build_interface:
		go_back()
	
	root = BuildCategory.new(self)
	current_category = root
	tooltip.hide()
	
	for cat_name in CATEGORY_ICONS.keys():
		category_list[cat_name] = root.add_category(cat_name, load(CATEGORY_ICONS[cat_name]) )
	
	var disabled_buildings: Array = Utils.game.map.start_config.get("disabled_buildings", [])
	for entry in Const.Buildings.values():
		if not "category" in entry or entry.name in disabled_buildings:
			continue
		
		var category := root
		if not entry.category in category_list:
			category_list[entry.category] = root.add_category(entry.category, load(CATEGORY_ICONS[entry.category]))
		category = category_list[entry.category]
		
		var data := BuildData.new()
#		data.scene = load(entry.scene)
		data.entry = entry
		category.add_item(data)
	
	refresh_categories()
	
	for category in category_list.values():
		if not category.elements.is_empty():
			return true
	
	return false

func _physics_process(delta: float) -> void:
	if player.using_joypad() and not build_interface and current_focus is BaseButton and is_ancestor_of(current_focus) and player.is_action_just_pressed("shoot"):
		current_focus.emit_signal("pressed")
	
	if build_interface or not visible:
		return
	
	if player.is_action_just_pressed("respawn"):
		emit_signal("building_selected", {cost = []})
	
	if not player.using_joypad():
		return
	
	var rot = player.get_look_angle(true)
	if rot != INF:
		rot += PI/2
		if rot < 0:
			rot += PI * 2
		pie.select_from_rotation(rad_to_deg(rot), current_category == root)

func interact():
	if build_interface:
		build_interface.interact()
		return

func interact_continuous():
	if build_interface:
		build_interface.interact_continuous()

func pay(dupa, whatevs, data):
	var cost = data.cost
	for res in cost:
		match res:
			Const.ItemIDs.METAL_SCRAP:
				player.pay_with_metal(cost[res], build_interface.blueprint.global_position)
			Const.ItemIDs.LUMEN:
				player.pay_with_lumen(cost[res], build_interface.blueprint.global_position)

func build_end():
	if not build_interface or build_interface.finished:
		disappear()
	else:
		show()

func update_previews():
	pie.clear_previews()
	
	if current_category == root:
		return
	
	for i in current_category.elements.size():
		pie.add_preview(current_category.elements[i], current_category.elements.size())
	
	pie.refresh_buildings()

func go_back(silent := false):
	if not silent:
		Utils.play_sample(preload("res://SFX/UI/BuildMenuBack.wav"), select_player)
	
	if current_category != root and not build_interface:
		current_category = root
		if pie.category_group.get_pressed_button():
			pie.category_group.get_pressed_button().button_pressed = false
		update_previews()
		tooltip.hide()
	elif build_interface:
		var is_building: bool
		for p in Utils.game.players:
			if p != player and p.build_menu and p.build_menu.build_interface:
				is_building = true
				break
		
		if not is_building:
			Utils.game.map.post_process.range_dirty = true
			Utils.game.map.post_process.stop_build_mode(player.global_position)
		
		if build_interface.blueprint:
			player.last_build_angle = build_interface.blueprint.angle
		
		build_interface.free()
		build_interface = null
	else:
		disappear()

func hover_category(cat: String):
	Utils.play_sample(preload("res://SFX/UI/BuildMenuSelect.wav"), select_player)
	pie.set_category(cat)

func select_category(cat: String):
	Utils.play_sample(preload("res://SFX/UI/BuildMenuAccept.wav"), select_player)
	current_category = category_list[cat]
	update_previews()

func hover_building(idx: int):
	Utils.play_sample(preload("res://SFX/UI/BuildMenuSelect.wav"), select_player)
	var building = pie.building_row.get_child(idx).get_meta("building").entry
	tooltip.set_building(building)

func select_building(idx: int):
	var building = pie.building_row.get_child(idx).get_meta("building")
	if not is_building_available(building.entry):
		Utils.play_sample(preload("res://SFX/UI/BuildMenuFail.wav"))
		return
	
	Utils.play_sample(preload("res://SFX/UI/BuildMenuAccept.wav"), select_player)
	emit_signal("building_selected", building)

func refresh_categories():
	for i in category_buttons.size():
		var button = category_buttons[i]
		var disabled := true
		
		for element in category_list[button.name].elements:
			if is_building_available(element.entry):
				disabled = false
				break
		
		if disabled:
			button.can_afford = false
		else:
			button.can_afford = true

func is_building_available(building: Dictionary) -> bool:
	if not player.can_afford(building.cost):
		return false
	
	if "requirements" in building:
		for req in building.requirements:
			if not BaseBuilding.is_requirement_met(req):
				if req == "turret:":
					SteamAPI.unlock_achievement("MORE_PYLONS")
				return false
	return true

func add_pending_icon(path: String, target: Object, property: String):
	pending_icons.append([path, target, property])
	set_process(true)

class BuildCategory:
	var name: String
	var build_menu: Node
	
	var icon: Texture2D
	var elements: Array
	
	func _init(bm) -> void:
		build_menu = bm
	
	func add_item(item: BuildData, p_scale := Vector2.ONE):
		assert(item)
		
		elements.append(item)
		
		var i = Sprite2D.new()
		build_menu.add_pending_icon("res://Nodes/Buildings/Icons/BuildMenu".plus_file(item.entry.name) + ".png", i, "texture")
		i.scale = Vector2.ONE * 0.5
		i.material = preload("res://Resources/Anarchy/Scenes/UIElements/pie_shader.tres")
		item.icon = i

#		var cost := {Const.ItemIDs.METAL_SCRAP: item.entry.cost}
#		for c in cost:
#			cost[c] *= Utils.temp_instance(item.scene).get_cost_multiplier()
		item.cost = item.entry.cost
	
	func add_category(p_name: String, p_icon: Texture2D) -> BuildCategory:
		var cat := BuildCategory.new(build_menu)
		cat.name = p_name
		cat.icon = p_icon
		elements.append(cat)
		return cat
	
	static func get_scale_for_size(size: Vector2) -> Vector2:
		var size2 := max(size.x, size.y)
		return Vector2.ONE * (120.0 / size2)

func focus_changed(control):
	current_focus = control

func update_config():
	scale = Vector2.ONE * Save.config.ui_scale
	$Help.visible = Save.config.control_tooltips_visible()

func appear(silent := false) -> bool:
	if dirty:
		recreate()
	
	if not valid:
		if not silent:
			Utils.play_sample(preload("res://SFX/UI/BuildMenuFail.wav"))
		return false
	
	if not get_parent():
		ui.add_child(self)
	
	if not silent:
		Utils.play_sample(preload("res://SFX/UI/BuildMenuOpen.wav"))
	
	show()
	return true

func disappear():
	get_parent().remove_child(self)
	
	if build_interface:
		build_interface.queue_free()
		build_interface = null
	
	if current_category != root:
		go_back(true)

class BuildData:
	var entry: Dictionary
	var icon: Node2D
	var cost: Dictionary
	
	func get_blueprint() -> Node2D:
		var blueprint: Node2D
		var blueprint_path: String = "res://Nodes/Buildings/Icons/Icon" + entry.scene.get_file()
		blueprint = load(blueprint_path).instantiate() as Node2D
		blueprint.rotate_to_angle = entry.build_rotate
		
		blueprint.original_scale = blueprint.scale
		var source := blueprint
		if blueprint.use_sprite_for_scale:
			source = blueprint.get_node("Sprite2D")
		elif blueprint.combined_scale:
			source = blueprint.get_node("Sprite2D")
		
		if blueprint.combined_scale:
			blueprint.scale *= BuildCategory.get_scale_for_size(source.get_rect().size * blueprint.scale * source.scale)
		else:
			blueprint.scale *= BuildCategory.get_scale_for_size(source.get_rect().size * source.scale)
		
		blueprint.building_data = entry
		return blueprint
	
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			if is_instance_valid(icon):
				icon.free()
