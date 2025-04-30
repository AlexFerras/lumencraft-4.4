extends ColorRect

const is_editor = true
var dev_mode = false

const COMPAT_OBJECTS = {"Hero Center": "Scout Center"} # compat

enum {NONE, QUIT, LOAD, NEW, EXIT}

@onready var load_dialog: FileDialog = $FileDialog
@onready var exit_dialog: ConfirmationDialog = $ConfirmationDialog
@onready var wait: CanvasItem = $Wait
@onready var object_settings: Control = find_child("ObjectSettings")
#onready var object_settings_parent := object_settings.get_parent()
@onready var error_label: Label = $Error
@onready var control_help: Control = $Controls
@onready var music_player: Control = $MusicPlayer
@onready var panel_root := $HBoxContainer

@onready var publish_panel: Control = $HBoxContainer/Publishing

@onready var file_manager_panel: Control = $HBoxContainer/FileManager
@onready var placeholder: Control = $HBoxContainer/Placeholder

@onready var edit_panel := $HBoxContainer/Edit
@onready var viewport := edit_panel.get_node("SubViewportContainer/SubViewport")
@onready var pixelmap: PixelMap = viewport.get_node("PixelMap")
@onready var floormap: PixelMap = viewport.get_node("Floor")
@onready var floormap2: PixelMap = viewport.get_node("Floor2")
@onready var terrain_preview: Node2D = viewport.get_node("TerrainPreview")
@onready var camera: Camera2D = viewport.get_node("Camera2D")
@onready var overlay: CanvasItem = viewport.get_node("EditorOverlay")
@onready var current_object: CanvasItem = viewport.get_node("CurrentObject")
@onready var placed: Node = viewport.get_node("PlacedObjects")

@onready var edit_ui: Control = edit_panel.get_node("Overlay")
@onready var minimap: Control = edit_ui.get_node("Minimap")
@onready var minimap_overlay: Control = $"%MinimapOverlay"
@onready var saved_notice: Control = edit_ui.get_node("Saved")

@onready var left_panel_menu := find_child("LeftPanelMenu")
@onready var new_map_menu: Control = left_panel_menu.find_child("NewMapMenu")
@onready var create_size := new_map_menu.find_child("MapSize") as SpinBox
@onready var starting_material := new_map_menu.find_child("StartingMaterial") as OptionButton
@onready var clear_terrain_button := new_map_menu.find_child("ClearTerrain") as Button

@onready var sidebar := find_child("Sidebar")
@onready var edit_menu := left_panel_menu.find_child("MenuEdit")
@onready var edit_header: Label = edit_menu.find_child("Header")
@onready var drawing_size_text: Label = edit_menu.find_child("DrawingSizeText")
@onready var drawing_size: HSlider = edit_menu.find_child("DrawingSize")
@onready var drawing_rotation_text: Label = edit_menu.find_child("DrawingRotationText")
@onready var drawing_rotation: HSlider = edit_menu.find_child("DrawingRotation")
@onready var replace_mode: OptionButton = $"%ReplaceMode"

@onready var map_name: LineEdit = $"%MapName"
@onready var map_description: TextEdit = $"%MapDescription"
@onready var darkness_color: ColorPickerButton = $"%DarknessColor"
@onready var enable_fog: CheckBox = $"%EnableFog"
@onready var enable_salvage: CheckBox = $"%EnableDrops"
@onready var extra_turret_limit := $"%ExtraTurretLimit"
@onready var resource_rate := $"%ResourceRate"
@onready var objective_settings := $"%Objectives"

@onready var terrain_config: VBoxContainer = $"%TerrainGroup"

var some_map_active: bool
var menus: Dictionary
var edit_groups: Array
var generated_terrain: RefCounted

var view_dragging: Vector2
var view_dragging_initial_camera: Vector2
var move_vector: Vector2
var line_start := Vector2(-1, -1)
var fill_thread: Thread
var drawing: int

var buildings_buttons: ButtonGroup
var enemy_buttons: ButtonGroup
var object_buttons: ButtonGroup
var pickups_buttons: ButtonGroup
var current_edit_group: String

var drawing_enabled: bool
var circle_shape: Texture2D
var draw_cursor: Texture2D
var draw_shape: Image
var draw_scale: float = 0.5
var draw_rotation: float = 0

var prev_hovered: EditorObject
var current_hovered: EditorObject
var current_selected: EditorObject
var tooltip: Control
var can_rotate_object: bool
var range_edit_control: Range
var picking_target: Object
var locate_object: EditorObject
var is_configuring: bool

var drag_origin: Vector2
var drag_offset: Vector2
var started_drag: bool
var hide_gizmos: bool
var scan_resources := Vector2(-1, -1)
var histogram: Array

var user_settings: Dictionary
var error_animator: Tween
var unsaved: bool
var quitting: int = NONE
var is_editing_text: bool

var map_path: String
var map_uid: String
var map_size: Vector2
var map_validated: bool

func _init() -> void:
	Utils.editor = self
	var file = Utils.safe_open(Utils.FILE, "user://editor_settings.txt", FileAccess.READ)
	if file:
		user_settings = str_to_var(file.get_as_text())

func _enter_tree() -> void:
	get_tree().set_auto_accept_quit(false)
	get_tree().paused = false
	Music.stop()
#	get_viewport().connect("gui_focus_changed", self, "gfc")
#
#func gfc(c):
#	print(c)

func _ready() -> void:
	if Music.is_demo_build():
		$"%DemoNotice".show()
		$"%SaveMap".tooltip_text = "Not available in demo"
		$"%SaveAs".tooltip_text = "Not available in demo"
		$"%Load".disabled = true
		$"%Load".tooltip_text = "Not available in demo"
		$"%Manage".disabled = true
		$"%Manage".tooltip_text = "Not available in demo"
	
	if Music.is_game_build():
		$"%DevControls".hide()
	
	exit_dialog.add_button("Quit Anyway", true).connect("pressed", Callable(self, "exit_anyway"))
	exit_dialog.get_ok_button().text = "Save"
	control_help.hide()
#	$HBoxContainer/ScrollContainer.set_meta("always_show_v", true)
	
	for control in left_panel_menu.get_child(0).get_children():
		if control.name.begins_with("Menu"):
			menus[control.name] = control
	
	for button in find_child("ShapeButtons").get_children():
		button.connect("pressed", Callable(self, "set_draw_shape").bind(button.icon))
		if button.get_index() == 0:
			circle_shape = button.icon
			draw_cursor = button.icon
			draw_shape = button.icon.get_data()
	
	for button in $"%SizePresets".get_children():
		button.connect("pressed", Callable(self, "set_drawing_size_from_preset").bind(int(button.text)))
	
	for button in $"%RotationPresets".get_children():
		button.connect("pressed", Callable(self, "set_drawing_rotation_from_preset").bind(int(button.text)))
	
	load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	
	for node in edit_menu.get_children():
		if node.name.ends_with("Group"):
			add_edit_group(node.name.trim_suffix("Group"))
	
	new_map_menu.hide()
	
	set_drawing_size(drawing_size.value)
	set_drawing_rotation(0)
	
	var buildings := get_edit_group("Buildings")
	buildings_buttons = ButtonGroup.new()
	buildings_buttons.connect("pressed", Callable(self, "on_item_selected"))
	
	var building_list := Const.Buildings.values()
	building_list.sort_custom(Callable(Utils, "sorty_by_category"))
	var current_category := ""
	
	for build in building_list:
		if "description" in build:
			var first := current_category.is_empty()
			var category: String = build.get("category", "")
			if category == "":
				category = "Misc"
			elif category == "Upgrades":
				category = "Special"
			
			if category != current_category:
				current_category = category
				add_object_category(buildings, current_category, not first)
			
			var building := preload("res://Nodes/Editor/EditorItem.tscn").instantiate()
			building.set_building(build, buildings_buttons)
			buildings.add_child(building)
	
	var objects := get_edit_group("Objects")
	object_buttons = ButtonGroup.new()
	object_buttons.connect("pressed", Callable(self, "on_item_selected"))
	
	add_object_category(objects, "Basic", false)
	add_object(objects, "Start Point", "Defines start position of the map. Takes priority over Reactor.")
	add_object(objects, "Goal Point", "Target point for Reach Destination objective.")
	add_object(objects, "Wave Spawner", "Spawn point for map's waves.")
	add_object_category(objects, "Container")
	add_object(objects, "Chest", "Interactable container for pickups.")
	add_object(objects, "Rusty Chest", "Destructible container for pickups.")
	add_object(objects, "Item Placer", "Randomly places given items in the defined radius.")
	add_object_category(objects, "Misc")
	add_object(objects, "Explosive Barrel", "Movable barrel that explodes on impact.")
	add_object(objects, "Metal Vein", "A spot for placing a Miner to automatically mine metal.")
	add_object(objects, "Stone Gate", "Special gate that requires specific items to be opened.")
	add_object(objects, "Teleport Plate", "Teleports you to another teleport plate with the same color.")
	add_object(objects, "Laptop", "Interactable object that displays custom text.")
	add_object_category(objects, "Hazard")
	add_object(objects, "Monster Egg", "Destructible object that spawns Lumens and spiders.").hide()
	add_object(objects, "Monster Nest", "Infinitely spawns a set amount of monsters until destroyed.")
	add_object(objects, "Hole Trap", "Hidden trap that spawns monsters when triggered.")
	add_object(objects, "Water Source", "Infinitely makes water in the given radius. (WIP)").hide()
	add_object(objects, "Lava Source", "Infinitely makes lava in the given radius.")
	add_object_category(objects, "Decoration")
	add_object(objects, "Boulder", "Heavy rock that can be slightly pushed around.")
	add_object(objects, "Light3D", "Generic point light with custom range and color.")
	add_object(objects, "Interactive Light3D", "Small lamp with customizable blinking pattern.")
	add_object(objects, "Lumen Mushroom", "Glowing object that drops Lumen when destroyed.")
	add_object(objects, "Glowing Coral", "Underground plant that resembles coral tubes.")
	add_object(objects, "Tree", "Just a regular tree. How does it grow underground though?")
	add_object_category(objects, "Event")
	add_object(objects, "Lumen Chunk", "Solid chunk of Lumen that you can tow to a reactor slot.")
	add_object(objects, "Terrain Modifier", "Dynamically creates or removes terrain.")
	add_object(objects, "Trigger", "General-purpose object detector.")
	add_object(objects, "Timer", "Counts down time.")
	add_object(objects, "Marker", "A generic marker that marks a position and shows on minimap.")
	
	var pickups := get_edit_group("Pickups")
	pickups_buttons = ButtonGroup.new()
	pickups_buttons.connect("pressed", Callable(self, "on_item_selected"))
	
	var first_container: int
	var last_consumable: int
	for item in Const.game_data.get_editor_pickup_list(true):
		if "category" in item:
			add_object_category(pickups, item.category, not item.get("first", false))
			continue
		
		var obj := preload("res://Nodes/Editor/EditorItem.tscn").instantiate()
		obj.set_pickup(item.id, item.get("data"), object_buttons)
		if item.id >= Const.RESOURCE_COUNT:
			obj.set_tooltip(Const.Items[item.id].description)
		pickups.add_child(obj)
		
		if item.id == Const.ItemIDs.LUMEN_CLUMP:
			first_container = obj.get_index()
		elif item.id == Const.ItemIDs.REPAIR_KIT:
			last_consumable = obj.get_index() - 2
	
	var obj := add_object(pickups, "Armored Box", "Loot box that needs to be extracted with Shredder.")
	obj.get_parent().move_child(obj, first_container)
	obj = add_object(pickups, "Technology Orb", Const.Items[Const.ItemIDs.TECHNOLOGY_ORB].description)
	obj.get_parent().move_child(obj, last_consumable)
	
	var enemies := get_edit_group("Enemies")
	enemy_buttons = ButtonGroup.new()
	enemy_buttons.connect("pressed", Callable(self, "on_item_selected"))
	
	for enemy in Const.game_data.get_editor_enemy_list(true):
		if "category" in enemy:
			add_object_category(enemies, enemy.category, not enemy.get("first", false))
			continue
		
		if enemy.begins_with("Swarm"):
			add_swarm(enemies, enemy.get_slice("/", 1))
		else:
			var emem := preload("res://Nodes/Editor/EditorItem.tscn").instantiate()
			emem.set_enemy(Const.Enemies[enemy], enemy_buttons)
			enemies.add_child(emem)
	
	for enemy in Const.game_data.get_hidden_editor_enemy_list():
		if enemy.begins_with("Swarm"):
			add_swarm(enemies, enemy.get_slice("/", 1)).hide()
		else:
			var emem := preload("res://Nodes/Editor/EditorItem.tscn").instantiate()
			emem.set_enemy(Const.Enemies[enemy], enemy_buttons)
			emem.hide()
			enemies.add_child(emem)
	
	set_process(false)
	set_menu("Edit")
	set_edit_group("System")
	file_manager_panel.hide()
	file_manager_panel.connect("hide", Callable(self, "show_publish").bind(false))
	
	var publish_to_workshop = find_child("PublishToWorkshop")
	if not SteamAPI.active:
		publish_to_workshop.hide()
		$FileDialog/Control/MyWorkshop.hide()
	elif not SteamAPI.initialized and Music.is_game_build():
		publish_to_workshop.disabled = true
		publish_to_workshop.tooltip_text = "Steam failed to load. Please restart the game in online mode."
		$FileDialog/Control/MyWorkshop.disabled = true
	elif Music.is_demo_build():
		publish_to_workshop.disabled = true
		publish_to_workshop.tooltip_text = "Not available in demo"
	
	get_viewport().connect("gui_focus_changed", Callable(self, "on_change_focus"))
	set_main_panel("Placeholder")
	
	if Utils.has_meta("editor_debug"):
		# TODO
		#load_dialog.mode = FileDialog.FILE_MODE_OPEN_FILE
		on_file_selected(Utils.get_meta("editor_debug"))
	
	$"%SubViewportContainer".call_deferred("grab_focus")
	
	for preset in user_settings.get("color_presets", []):
		darkness_color.get_picker().add_preset(preset)
	
	starting_material.call_deferred("add_item", "Empty", Const.Materials.EMPTY)

func validate_map(strict: bool) -> bool:
	var errors: PackedStringArray
	var current_error: String
	
	current_error = "No spawn point. Add a Reactor or Start Point."
	for object in placed.get_children():
		if object.object_name == "Reactor" or object.object_name == "Start Point":
			current_error = ""
			break
	
	if Utils.has_meta("start_override"):
		current_error = ""
	
	if not current_error.is_empty():
		errors.append(tr(current_error))
	current_error = ""
	
	var has_waves: bool = not get_edit_group("Waves").get_data().is_empty()
	if not has_waves:
		for event in get_edit_group("Events").get_data():
			for action in event.actions:
				if action.type == "launch_custom_wave":
					has_waves = true
	
	if has_waves:
		current_error = "Waves are defined, but no Wave Spawner exists."
		for object in placed.get_children():
			if object.object_name == "Wave Spawner":
				current_error = ""
				break
	
	if not current_error.is_empty():
		errors.append(tr(current_error))
	current_error = ""
	
	var objectives: Dictionary = objective_settings.get_data()
	if strict and objectives.win.type == "waves":
		if not has_waves:
			current_error = "Clear condition is defeat waves, but no wave is defined."
	
	if not current_error.is_empty():
		errors.append(tr(current_error))
	current_error = ""
	
	if strict and objectives.win.type == "custom":
		var ok: bool
		for event in get_edit_group("Events").get_data():
			for action in event.actions:
				if action.id == -1 and action.type == "win":
					ok = true
					break
		
		if not ok:
			current_error = "Clear condition is custom, but there is no winning event."
	
	if not current_error.is_empty():
		errors.append(tr(current_error))
	current_error = ""
	
#	if strict and objective_settings.node("WinCondition") == OBJECTIVE_ITEM and objective_item.get_node("ID").get_selected_id() >= Const.RESOURCE_COUNT:
#		current_error = "Clear condition is collect item, but the item is not on map."
#		for object in placed.get_children():
#			## sprawdzać skrzynie i piksele??
#			if object.object_name == "Pickup" and object.object_data.id == objective_item.get_node("ID").get_selected_id():
#				current_error = ""
#				break
	
	if not current_error.is_empty():
		errors.append(tr(current_error))
	current_error = ""
	
	if strict and objective_settings.get_node("%WinCondition").selected == objective_settings.OBJECTIVE_FINISH:
		current_error = "Clear condition is reach goal, but there is no Goal Point object."
		for object in placed.get_children():
			if object.object_name == "Goal Point":
				current_error = ""
				break
	
	if not current_error.is_empty():
		errors.append(tr(current_error))
	
	if not errors.is_empty():
		"\n".join(display_error(errors[0]))
		return false
	
	return true

func display_error(error: String):
	error_label.text = error
	error_label.show()
	error_label.modulate.a = 1
	
	if error_animator:
		error_animator.kill()
	
	error_animator = create_tween()
	error_animator.tween_interval(5)
	error_animator.tween_property(error_label, "modulate:a", 0.0, 1)
	error_animator.tween_callback(Callable(error_label, "hide"))
	error_animator.tween_callback(Callable(self, "set").bind("error_animator", null))

func show_publish(show: bool):
	set_main_panel("Publishing" if show else "Edit")
	if show:
		clear_object_settings()

func set_main_panel(panel: String):
	for node in panel_root.get_children():
		if node.get_index() < 2:
			continue
		
		node.visible = node.name == panel

func set_draw_shape(shape: Texture2D):
	draw_cursor = shape
	draw_shape = shape.get_data()

func add_swarm(objects: Node, swarm_name: String):
	var obj := preload("res://Nodes/Editor/EditorItem.tscn").instantiate()
	obj.set_enemy_swarm(Const.Enemies[swarm_name], enemy_buttons)
	objects.add_child(obj)
	return obj

func add_object(objects: Node, object: String, description: String) -> Node:
	var obj := preload("res://Nodes/Editor/EditorItem.tscn").instantiate()
	obj.set_object(object, object_buttons)
	obj.set_tooltip(description)
	objects.add_child(obj)
	return obj

func add_object_category(objects: Node, category: String, add_separator := true):
	if add_separator:
		var separator := Control.new()
		separator.custom_minimum_size.y = 20
		objects.add_child(separator)
	
	var label := Label.new()
	label.theme_type_variation = "HeaderLabel"
	label.text = category
	objects.add_child(label)

func get_object_icon(array: String, object: String):
	var ary: Array = edit_menu.get_node(array).get_children()
	for obj in ary:
		if "data" in obj and obj.data.name == object:
			return obj.get_node("Icon").texture

func add_edit_group(group_name: String):
	edit_groups.append(group_name)
	sidebar.get_node(group_name).tooltip_text = group_name
	sidebar.get_node(group_name).connect("pressed", Callable(self, "set_edit_group").bind(group_name))

func set_edit_group(group_name: String):
	if group_name == current_edit_group:
		return
	
	current_edit_group = group_name
	edit_header.text = current_edit_group
	
	clear_selected_objects()
	drawing_enabled = current_edit_group == "Terrain"
	if some_map_active:
		show_publish(false)
	
	if drawing_enabled and terrain_config.selected_floor > -1:
		terrain_config.on_floor_selected(terrain_config.selected_floor)
	
	for group in edit_groups:
		var group_node := get_edit_group(group)
		group_node.visible = group == current_edit_group
		
		if group_node.has_method("group_entered"):
			group_node.group_entered()

func get_edit_group(group: String) -> Node:
	return edit_menu.get_node(group + "Group")

func set_menu(target: String):
	if file_manager_panel.visible:
		on_manage_maps()
	
	if target == "Edit" and some_map_active:
		pixelmap.show()
		floormap.show()
		floormap2.show()
		edit_ui.show()
		terrain_preview.hide()
		
		for node in sidebar.get_children():
			node.disabled = false
		sidebar.get_node("Terrain").button_pressed = true
		set_edit_group("Terrain")
	else:
		edit_ui.hide()
		for node in sidebar.get_children():
			if node.get_index() > 0:
				node.disabled = true
	
	for menu in menus:
		menus[menu].visible = menu == str("Menu", target)

func on_new_map() -> void:
	if unsaved and quitting == NONE:
		confirm_quit(NEW)
		return
	
	on_clear_generated()
	
	new_map_menu.visible = true
	clear_map()
	set_main_panel("Edit")
	set_map_size(Vector2.ONE * $"%MapSize".value)
	terrain_preview.show()
	edit_ui.show()
	minimap_overlay.texture = null
	
	for node in sidebar.get_children():
		$"%TestMap".disabled = true
		$"%ValidateMap".disabled = true
		$"%SaveMap".disabled = true
		$"%SaveAs".disabled = true
		node.disabled = node.get_index() > 0

func clear_map():
	pixelmap.hide()
	floormap.hide()
	floormap2.hide()
	
	for object in placed.get_children():
		object.queue_free()
	
	current_hovered = null
	current_selected = null
	picking_target = null

func on_accept_create():
	on_any_map(false)
	clear_map()
	
	wait.show()
	await get_tree().idle_frame
	await get_tree().idle_frame
	new_map_menu.hide()
	
	var is_empty = starting_material.get_selected_id() == Const.Materials.EMPTY
	pixelmap.create_texture(create_size.value, create_size.value, Color(0 if is_empty else 1, starting_material.get_selected_id() / 255.0, 255 if starting_material.get_selected_id() == Const.Materials.TAR else 0, 0 if is_empty else 1))
	floormap.create_texture(1024, 1024, Color(1, 0, 0, 0))
	floormap2.create_texture(1024, 1024, Color(0))
	
	if generated_terrain and not is_empty:
		generated_terrain.bake_terrain(starting_material.get_selected_id())
		await generated_terrain.bake_finished
		
		var source: Image = generated_terrain.final_image
		var target := pixelmap.get_texture().get_image()
		
		await get_tree().idle_frame
		
		## FIXME: jakieś errory wysrywa
		false # source.lock() # TODOConverter3To4, Image no longer requires locking, `false` helps to not break one line if/else, so it can freely be removed
		var emptolor := Color(0, Const.Materials.EMPTY / 255.0, 0, 0)
		for x in source.get_width():
			for y in source.get_width():
				if source.get_pixel(x, y).a == 0:
					source.set_pixel(x, y, emptolor)
		false # source.unlock() # TODOConverter3To4, Image no longer requires locking, `false` helps to not break one line if/else, so it can freely be removed
		
		false # target.lock() # TODOConverter3To4, Image no longer requires locking, `false` helps to not break one line if/else, so it can freely be removed
		target.blit_rect(source, Rect2(Vector2(), source.get_size()), target.get_size() * 0.5 - source.get_size() * 0.5)
		false # target.unlock() # TODOConverter3To4, Image no longer requires locking, `false` helps to not break one line if/else, so it can freely be removed
		
		pixelmap.set_pixel_data(target.get_data(), target.get_size())
		
		generated_terrain = null
		terrain_preview.hide()
	
	wait.hide()
	minimap_overlay.texture = pixelmap.get_texture()
	
	## TODO: resetować wszystko ładnie
	map_path = ""
	publish_panel.workshop_id = -1
	map_name.text = ""
	map_description.text = ""
	darkness_color.color = Color.BLACK
	enable_fog.button_pressed = true
	enable_salvage.button_pressed = true
	extra_turret_limit.value = 0
	resource_rate.value = 1.0
	objective_settings.set_data({})
	
	get_edit_group("Waves").clear_data()
	get_edit_group("Player").clear_data()
	get_edit_group("Events").clear_data()
	
	terrain_config.set_data(Const.game_data.DEFAULT_TERRAIN_CONFIG.duplicate(true))
	
	set_menu("Edit")
	set_process(true)
	set_unsaved(true)

func on_load_map() -> void:
	if unsaved and quitting == NONE:
		confirm_quit(LOAD)
		return
	
	if dev_mode:
		load_dialog.access = FileDialog.ACCESS_RESOURCES
		load_dialog.current_dir = "res://Maps"
	else:
		load_dialog.current_dir = ProjectSettings.globalize_path("user://Maps")
	# TODO
	#load_dialog.mode = FileDialog.FILE_MODE_OPEN_FILE
	load_dialog.popup_centered()

func on_save() -> void:
	if dev_mode:
		load_dialog.access = FileDialog.ACCESS_RESOURCES
		load_dialog.current_dir = "res://Maps"
	else:
		load_dialog.current_dir = ProjectSettings.globalize_path("user://Maps")
		# TODO
	#load_dialog.mode = FileDialog.FILE_MODE_SAVE_FILE
	load_dialog.current_file = map_path.get_file()
	load_dialog.popup_centered()

func try_save():
	quitting *= -1
	if map_path:
		save_map(map_path)
	else:
		on_save()

func on_file_selected(path: String) -> void:
	map_path = path
	if load_dialog.mode == FileDialog.FILE_MODE_OPEN_FILE:
		clear_map()
		
		await get_tree().idle_frame
		await get_tree().idle_frame
		
		load_map(path)
		set_menu("Edit")
		set_process(true)
	else:
		save_map(path)
		file_manager_panel.refresh_dir()

func load_map(path: String):
	on_any_map()
	
	var map_file := MapFile.new()
	map_file.load_from_file(path)
	if map_file.error:
		await get_tree().idle_frame
		exit()
		display_error("Error loading map. File invalid or corrupted.")
		return
	
	apply_map(map_file)
#	for i in placed.get_child_count(): prints(i, placed.get_child(i).object_name)

func apply_map(map_file: MapFile):
	map_name.text = map_file.map_name
	map_description.text = map_file.map_description
	publish_panel.workshop_id = map_file.workshop_id
	map_uid = map_file.uid
	if map_file.validated:
		set_validated()
		is_configuring = true
	else:
		map_validated = false
		
	var make_bedrock_frame := OS.has_feature("editor") and Input.is_action_pressed("test")
	if make_bedrock_frame:
		var pm=(map_file.pixel_data as Image)
		var new_pm= Image.new()
		new_pm.create(pm.get_width()+256,pm.get_height()+256,false,pm.get_format())
		new_pm.fill(Color8(255,2,0,255))
		new_pm.blit_rect(pm,Rect2(Vector2.ZERO,pm.get_size()),Vector2(128,128))
		map_file.pixel_data=new_pm
		
		var fm=(map_file.floor_data as Image)
		var new_fm= Image.new()
		new_fm.create(fm.get_width(),fm.get_height(),false,fm.get_format())
		new_fm.fill(Color8(255,0,0,0))
		new_fm.blit_rect(fm,Rect2(Vector2.ZERO,fm.get_size()),Vector2(128/8,128/8))
		map_file.floor_data=new_fm
		
		var fm2=(map_file.floor_data2 as Image)
		var new_fm2= Image.new()
		new_fm2.create(fm2.get_width(),fm2.get_height(),false,fm2.get_format())
		new_fm2.fill(Color8(255,0,0,0))
		new_fm2.blit_rect(fm2,Rect2(Vector2.ZERO,fm2.get_size()),Vector2(128/8,128/8))
		map_file.floor_data2=new_fm2
	
	pixelmap.set_pixel_data(map_file.pixel_data.get_data(), map_file.pixel_data.get_size())
	floormap.set_pixel_data(map_file.floor_data.get_data(), map_file.floor_data.get_size())
	floormap2.set_pixel_data(map_file.floor_data2.get_data(), map_file.floor_data2.get_size())
	minimap_overlay.texture = pixelmap.get_texture()
	terrain_config.set_data(map_file.terrain_config)
	objective_settings.set_data(map_file.objective_data)
	get_edit_group("Waves").set_data(map_file.wave_data)
	get_edit_group("Player").set_data(map_file.start_config)
	
	set_map_size(map_file.pixel_data.get_size())
	
	for object in map_file.objects:
		var editor_object: EditorObject
		editor_object = EditorObject.create_from_data(self, object)
		
		if not editor_object and COMPAT_OBJECTS.has(object.name):
			object.name = COMPAT_OBJECTS[object.name]
			editor_object = EditorObject.create_from_data(self, object)
		
		if not editor_object:
			push_error(str("Invalid object: ", object))
			continue
		
		editor_object.rotation = object.get("rotation", 0)
		editor_object.set_data(object.data)
		editor_object._refresh()
		if make_bedrock_frame: object.position += Vector2(128,128)
		place_object(editor_object, object.position)
	
	get_edit_group("Events").set_data(map_file.events)
	
	darkness_color.color = map_file.darkness_color
	enable_fog.button_pressed = map_file.enable_fog
	enable_salvage.button_pressed = map_file.buildings_drop_resources
	extra_turret_limit.value = map_file.extra_turret_limit
	resource_rate.value = map_file.resource_rate
	
	if map_file.terrain_config.get("alt_floor", false):
		floormap.material.set_shader_parameter("use_black_as_alpha", true)
		floormap.custom_material = true
#		floormap2.material.set_shader_param("black_as_empty", true)
#		floormap.custom_material = true
	
	is_configuring = false
	set_unsaved(false)

func save_map(path: String):
#	object_settings_parent.remove_child(object_settings)
	
	if exit_dialog.is_connected("popup_hide", Callable(self, "cancel_exit")):
		exit_dialog.disconnect("popup_hide", Callable(self, "cancel_exit"))
	
	var map_file := MapFile.new()
	
	map_file.map_name = map_name.text
	map_file.map_description = map_description.text
	map_file.workshop_id = publish_panel.workshop_id
	map_file.validated = map_validated
	
	map_file.pixel_data = pixelmap.get_texture().get_data()
	map_file.floor_data = floormap.get_texture().get_data()
	map_file.floor_data2 = floormap2.get_texture().get_data()
	map_file.terrain_config = terrain_config.terrain_data
	
	for placed_object in placed.get_children():
		var object := {}
		object.position = placed_object.position
		if placed_object.can_rotate:
			object.rotation = placed_object.rotation
		object.type = placed_object.object_type
		object.name = placed_object.object_name
		object.data = placed_object.get_data()
		map_file.objects.append(object)
	
	map_file.darkness_color = darkness_color.color
	# TODO
	#map_file.enable_fog = enable_fog.pressed
	#map_file.buildings_drop_resources = enable_salvage.pressed
	map_file.extra_turret_limit = extra_turret_limit.value
	map_file.resource_rate = resource_rate.value
	map_file.objective_data = objective_settings.get_data()
	map_file.wave_data = get_edit_group("Waves").get_data()
	map_file.start_config = get_edit_group("Player").get_data()
	map_file.events = get_edit_group("Events").get_data()
	
	map_file.uid = map_uid
	map_file.save_to_file(path)
	map_uid = map_file.uid
	
	if path != "user://temp.lcmap" or has_meta("debug"):
		set_unsaved(false)
	
	if quitting == NONE:
		saved_notice.show()
		saved_notice.modulate.a = 1
		var seq := get_tree().create_tween()
		seq.tween_interval(1)
		seq.tween_property(saved_notice, "modulate:a", 0.0, 0.5)
		seq.tween_callback(Callable(saved_notice, "hide"))
	else:
		exit_anyway()
	
#	object_settings_parent.add_child(object_settings)

func on_test() -> void:
	if not validate_map(false) or not pixelmap.visible:
		return
	
	clear_selected_objects()
	
	save_map("user://temp.lcmap")
	Save.new_game()
	Game.start_map("user://temp.lcmap")
	
	get_parent().call_deferred("remove_child", self)

func on_validate() -> void:
	if map_path.is_empty():
		display_error("Map needs to be saved first.")
		return
	
	if not validate_map(true) or not pixelmap.visible:
		return
	
	clear_selected_objects()
	
	save_map("user://temp.lcmap")
	Save.new_game()
	Save.data.ranked = true
	Game.start_map("user://temp.lcmap")
	
	get_parent().call_deferred("remove_child", self)

func on_publish() -> void:
	if not validate_map(true):
		return
	
	drawing_enabled = false
	publish_panel.setup()
	show_publish(true)

func try_publish() -> bool:
	if map_path.is_empty():
		on_save()
		return false
	else:
		save_map(map_path)
		return true

func refresh_terrain_data():
	for i in Const.SwappableMaterials.size():
		var mat = load("res://Resources/Terrain/TerrainTextures/%s.tres" % terrain_config.terrain_data.terrain[i])
		if pixelmap.custom_materials[i] != mat:
			pixelmap.dirty = true
			pixelmap.custom_materials[i] = mat
	
	for i in 4:
		var mat = load("res://Resources/Terrain/FloorTextures/2%s.tres" % terrain_config.terrain_data.upper_floor[i])
		if floormap2.textures[i] != mat:
			floormap2.dirty = true
			floormap2.textures[i] = mat
		
		mat = load("res://Resources/Terrain/FloorTextures/1%s.tres" % terrain_config.terrain_data.lower_floor[i])
		if floormap.textures[i] != mat:
			floormap.dirty = true
			floormap.textures[i] = mat
	
	if "bedrock_compat" in terrain_config: # compat
		pixelmap.dirty = true
		var mat = load("res://Resources/Terrain/TerrainTextures/%s.tres" % terrain_config.bedrock_compat)
		pixelmap.bedrock_compat_override = mat
	
	pixelmap.apply_custom_materials()
	floormap.apply_textures()
	floormap2.apply_textures()

func set_drawing_size_from_preset(value: int) -> void:
	drawing_size.value = value

func set_drawing_size(value: float) -> void:
	drawing_size_text.text = tr("Drawing Size: %d") % value
	draw_scale = value / 128.0

func set_drawing_rotation_from_preset(value: int) -> void:
	drawing_rotation.value = value

func set_drawing_rotation(value: float) -> void:
	drawing_rotation_text.text = tr("Drawing Rotation: %d°") % value
	draw_rotation = deg_to_rad(value)

func on_item_selected(item):
	var obj: EditorObject = item.get_parent().get_editor_object()
	set_current_object(obj)
	
	current_selected = null
	clear_object_settings()
	configure_object(obj)

func get_current_pixel_map() -> PixelMap:
	if terrain_config.selected_material > -1:
		return pixelmap
	elif terrain_config.selected_floor < 4:
		return floormap2
	else:
		return floormap

func create_object_by_name(group: ButtonGroup, obj_name: String) -> EditorObject:
	for button in group.get_buttons():
		if button.get_parent().data.name == obj_name:
			if not button.get_parent().visible:
				push_warning(str("Forbidden object: ", obj_name))
			return button.get_parent().get_editor_object()
	return null

func clear_selected_objects():
	if get_current_object():
		get_current_object().queue_free()
	clear_object_settings()
	
	for button in buildings_buttons.get_buttons():
		button.button_pressed = false
	
	for button in enemy_buttons.get_buttons():
		button.button_pressed = false
	
	for button in object_buttons.get_buttons():
		button.button_pressed = false
	
	current_selected = null
	if picking_target:
		picking_target.cancel_picking()
		picking_target = null

func set_current_object(object: EditorObject):
	var prev := get_current_object()
	if prev:
		prev.queue_free()
	current_object.add_child(object)

func get_current_object() -> EditorObject:
	if current_object.get_child_count() > 0:
		return current_object.get_child(0) as EditorObject
	return null

func clear_object_settings():
	$"%NiceSeparator".hide()
	range_edit_control = null
	object_settings.propagate_call("release_focus")
	for setting in object_settings.get_children():
		setting.queue_free()
	Utils.call_super_deferred(self, "hide_empty_settings")

func add_object_setting(setting: Control):
	object_settings.add_child(setting)
	$"%ObjectSettingsScroll".call_deferred("show")

func set_range_control(control: Control):
	range_edit_control = control

func hide_empty_settings():
	if object_settings.get_child_count() == 0:
		$"%ObjectSettingsScroll".hide()

func _process(delta: float) -> void:
	current_object.position = cursor_pos()
	overlay.update()
	
	if current_hovered:
		if current_hovered != prev_hovered or current_hovered.tooltip_dirty:
			current_hovered.tooltip_dirty = false
			if tooltip:
				tooltip.queue_free()
			
			tooltip = current_hovered._get_tooltip()
			if tooltip:
				add_child(tooltip)
	elif prev_hovered:
		if tooltip:
			tooltip.queue_free()
			tooltip = null
	prev_hovered = current_hovered
	
	if current_selected and current_selected.config_dirty:
		clear_object_settings()
		configure_object(current_selected)
		current_selected.config_dirty = false
	
	var transient_object := get_current_object()
	if transient_object and transient_object.config_dirty:
		clear_object_settings()
		configure_object(transient_object)
		transient_object.config_dirty = false
	
	if tooltip:
		tooltip.position = get_local_mouse_position() + Vector2(30, 0)
	
	if fill_thread:
		if not fill_thread.is_alive():
			fill_thread.wait_to_finish()
			fill_thread = null
	
	var move := move_vector.normalized()
#	var move := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down")).normalized()
	if move != Vector2() and not Input.is_key_pressed(KEY_CTRL):# and $"%SubViewportContainer".has_focus():
		set_camera_position(camera.position + move * (800 if Input.is_key_pressed(KEY_SHIFT) else 200) * delta)
		if drawing_enabled and drawing != 0:
			draw_on_map()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.keycode == KEY_A:
		move_vector.x = -1 * int(event.pressed)
	elif event.keycode == KEY_D:
		move_vector.x = 1 * int(event.pressed)
	elif event.keycode == KEY_W:
		move_vector.y = -1 * int(event.pressed)
	elif event.keycode == KEY_S:
		move_vector.y = 1 * int(event.pressed)
	
	if event.keycode == KEY_R and not event.is_echo():
		if event.pressed:
			scan_resources = cursor_pos()
		else:
			scan_resources = Vector2(-1, -1)
			histogram.clear()

func _viewport_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_unhandled_key_input(event)
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				if event.command:
					camera.zoom = Vector2(0.125, 0.125)
				else:
					view_dragging = event.position
					view_dragging_initial_camera = camera.position
			else:
				view_dragging = Vector2()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if drawing_enabled:
					if event.command:
						var pos := cursor_pos().floor()
						var pixmap := get_current_pixel_map()
						
						if Rect2(Vector2(), pixmap.get_texture().get_size()).has_point(pos):
							if pixmap == pixelmap:
								var mat := pixelmap.get_pixel_at_safe(pos).g8
								terrain_config.pick_material(mat)
							else:
								var col := pixmap.get_pixel_at_safe((pos / 8).floor())
								var index := -1
								if col.r > 0.99:
									index = 0
								elif col.g > 0.99:
									index = 1
								elif col.b > 0.99:
									index = 2
								elif col.a > 0.99:
									index = 3
								
								if index > -1:
									if pixmap == floormap:
										terrain_config.base_floor_textures.get_child(index).button.button_pressed = true
									elif pixmap == floormap2:
										terrain_config.surface_floor_textures.get_child(index).button.button_pressed = true
					elif event.shift:
						line_start = cursor_pos()
#					elif event.alt and not fill_thread:
#						fill_thread = Thread.new()
#						fill_thread.start(self, "flood_fill", cursor_pos())
					else:
						var pixmap := get_current_pixel_map()
						pixmap.set_meta("previous_state", pixmap.get_pixel_data())
						drawing = 1
						draw_on_map()
				elif get_current_object():
					if current_hovered and event.command:
						object_settings.propagate_call("release_focus")
						await get_tree().idle_frame
						current_hovered._push_object(get_current_object())
					else:
						object_settings.propagate_call("release_focus")
						await get_tree().idle_frame
						var to_place := get_current_object().copy()
						place_object(to_place, current_object.position)
						set_unsaved(true)
				elif current_hovered and current_hovered != current_selected:
					if picking_target:
						picking_target.pick_object(current_hovered)
						picking_target = null
						return
					
					current_selected = current_hovered
					clear_object_settings()
					configure_object(current_selected)
					
					drag_origin = cursor_pos()
					drag_offset = cursor_pos() - current_selected.position
					
					current_hovered = null
				elif is_hovering_selected():
					drag_origin = cursor_pos()
					drag_offset = cursor_pos() - current_selected.position
			else:
				if current_hovered and current_selected and event.command:
					if current_hovered._push_object(current_selected):
						current_hovered._unhover()
						current_selected.queue_free()
						current_selected = null
						clear_object_settings()
				elif line_start != Vector2(-1, -1):
					var pixmap := get_current_pixel_map()
					pixmap.set_meta("previous_state", pixmap.get_pixel_data())
					drawing = 1
					var destination := get_line_end_point()
					while not line_start.is_equal_approx(destination): 
						draw_on_map(line_start)
						line_start = line_start.move_toward(destination, 1)
					line_start = Vector2(-1, -1)
				
				if drawing != 0:
					drawing = 0
					set_unsaved(true)
				
				if started_drag or drag_origin != Vector2():
					if started_drag:
						set_unsaved(true)
					started_drag = false
					drag_origin = Vector2()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if drawing_enabled:
					if event.shift:
						line_start = cursor_pos()
					else:
						var pixmap := get_current_pixel_map()
						pixmap.set_meta("previous_state", pixmap.get_pixel_data())
						drawing = -1
						draw_on_map()
				elif get_current_object():
					clear_selected_objects()
					if current_hovered:
						current_hovered._unhover_object()
				elif current_selected:
					clear_object_settings()
					current_selected = null
				elif picking_target:
					picking_target.cancel_picking()
					picking_target = null
			else:
				if line_start != Vector2(-1, -1):
					var pixmap := get_current_pixel_map()
					pixmap.set_meta("previous_state", pixmap.get_pixel_data())
					drawing = -1
					var destination := get_line_end_point()
					while not line_start.is_equal_approx(destination): 
						draw_on_map(line_start)
						line_start = line_start.move_toward(destination, 1)
					line_start = Vector2(-1, -1)
				
				if drawing != 0:
					drawing = 0
					set_unsaved(true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if not event.pressed:
				return
			var sgn := 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
			
			if not event.command and not event.shift:
				var prev_cursor := cursor_pos()
				
				var zoom: float = max(camera.zoom.x - 0.05 * sgn, 0.1)
				if viewport.size.x * zoom > camera.limit_right:
					zoom = camera.zoom.x
				camera.zoom = Vector2.ONE * zoom
				
				camera.position += (prev_cursor - cursor_pos())
				return
			
			if event.shift:
				drawing_size.value += event.factor * 4 * sgn
			elif event.command and terrain_config.selected_material != -1:
				drawing_rotation.value = wrapi(drawing_rotation.value + event.factor * 3 * sgn, 0, 360)
			draw_on_map()
			
			if range_edit_control and event.shift:
				range_edit_control.value += sgn
			
			if get_current_object():
				get_current_object()._rotate(sgn)
			elif is_hovering_selected() and current_selected.can_rotate:
				current_selected._rotate(sgn)
				set_unsaved(true)
	if event is InputEventMouseMotion:
		if view_dragging != Vector2():
			var mouse_pos: Vector2 = edit_panel.get_local_mouse_position() + edit_panel.get_rect().position
			if not edit_panel.get_rect().has_point(mouse_pos):
				var target_mouse := get_viewport().get_mouse_position()
				
				if mouse_pos.x < edit_panel.get_rect().position.x:
					target_mouse.x += edit_panel.get_rect().size.x
				elif mouse_pos.x > edit_panel.get_rect().end.x:
					target_mouse.x -= edit_panel.get_rect().size.x
				
				if mouse_pos.y < edit_panel.get_rect().position.y:
					target_mouse.y += edit_panel.get_rect().size.y
				elif mouse_pos.y > edit_panel.get_rect().end.y:
					target_mouse.y -= edit_panel.get_rect().size.y
				
				view_dragging += target_mouse - get_viewport().get_mouse_position()
				get_viewport().warp_mouse(target_mouse)
			else:
				set_camera_position(view_dragging_initial_camera + (view_dragging - event.position) * camera.zoom)
		draw_on_map()
		
		if scan_resources != Vector2(-1, -1):
			histogram = pixelmap.get_materials_histogram_rect(Utils.make_me_rect(scan_resources, cursor_pos()))
		
		if current_selected and drag_origin != Vector2() and (started_drag or cursor_pos().distance_squared_to(drag_origin) > 10):
			current_selected.position = Utils.clamp_to_pixel_map(cursor_pos() - drag_offset, pixelmap)
			started_drag = true
		
		if not drawing_enabled:
			var hovered: Array
			
			for object in placed.get_children():
				if object != current_selected and object._has_point(cursor_pos()):
					hovered.append(object)
			
			var closest: EditorObject
			var closest_dist := INF
			
			for object in hovered:
				var dist: float = object.get_local_mouse_position().length_squared()
				if dist < closest_dist:
					closest = object
					closest_dist = dist
			
			if current_hovered and closest != current_hovered:
				current_hovered._unhover()
			
			if not closest or closest != current_selected and (not picking_target or closest.can_pick_target(picking_target.is_action)):
				current_hovered = closest
			
			if current_hovered:
				var to_hover := get_current_object()
				if not to_hover:
					to_hover = current_selected
				
				if to_hover:
					current_hovered._hover_object(to_hover)
		elif current_hovered:
			current_hovered = null
		
		var prev_rotate := can_rotate_object
		if get_current_object():
			can_rotate_object = get_current_object().can_rotate
		elif is_hovering_selected():
			can_rotate_object = current_selected.can_rotate
		else:
			can_rotate_object = false
		
		if can_rotate_object != prev_rotate:
			overlay.update()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_Z and event.pressed and event.command and drawing == 0:
			var pixmap := get_current_pixel_map()
			if pixmap.has_meta("previous_state"):
				wait.show()
				var temp_data := pixmap.get_pixel_data()
				await get_tree().idle_frame
				await get_tree().idle_frame
				pixmap.set_pixel_data(pixmap.get_meta("previous_state"), pixmap.get_texture().get_size())
				wait.hide()
				pixmap.set_meta("previous_state", temp_data)
		elif event.keycode == KEY_C and event.pressed and event.command and current_selected:
			var obj := current_selected.copy()
			obj.position = Vector2()
			set_current_object(obj)
			current_selected = null
			clear_object_settings()
			configure_object(obj)
		elif event.keycode == KEY_S and event.pressed and event.command:
			try_save()
		elif event.keycode == KEY_T and event.pressed and event.command:
			on_test()
		elif event.keycode == KEY_DELETE and current_selected and not is_editing_text:
			clear_object_settings()
			if current_hovered:
				current_hovered._unhover()
			current_selected._on_deleted()
			current_selected.destroy()
			set_unsaved(true)
			
			Utils.call_super_deferred(get_tree(), "call_group", ["event_actions", "reassign_id"])
		
		if not event.pressed:
			return
		
		if event.keycode == KEY_F2:
			Utils.set_meta("start_override", cursor_pos())
			on_test()
		if event.keycode == KEY_F3:
			music_player.visible = not music_player.visible
		if event.keycode == KEY_F9 and event.shift:
			publish_panel.workshop_id = -1
		
		if Music.is_game_build():
			return
		
		if event.keycode == KEY_F4 and event.shift:
			# TODO
			#load_dialog.mode = FileDialog.FILE_MODE_OPEN_FILE
			on_file_selected("user://temp.lcmap")
			set_meta("debug", true)
		if event.keycode == KEY_F5:
			if terrain_config.terrain_data.alt_floor:
				terrain_config.terrain_data.alt_floor = false
				floormap.material.set_shader_parameter("use_black_as_alpha", false)
				print("succ")
			
			if event.shift:
				return
			
			var noise = FastNoiseLite.new()
			noise.seed = randi()
			noise.fractal_octaves = 2
			noise.period = 20.0
			noise.persistence = 0.8
			
			var data = pixelmap.get_pixel_data()
			var image = Image.new()
			image.create(1024, 1024, false, Image.FORMAT_RGBA8)
			false # image.lock() # TODOConverter3To4, Image no longer requires locking, `false` helps to not break one line if/else, so it can freely be removed
			for x in pixelmap.get_texture().get_width()/8:
				for y in pixelmap.get_texture().get_height()/8:
					var mat = data[(x + y * pixelmap.get_texture().get_width()) * 4 * 8 + 1]
					if not data[(x + y * pixelmap.get_texture().get_width()) * 4 * 8 ]:
						mat = Const.Materials.EMPTY
					match mat:
						Const.Materials.DIRT:
							image.set_pixel(x, y, Color(0, 1, 0, 0))
						Const.Materials.CLAY:
							image.set_pixel(x, y, Color(0, 0, 1, 0))
						Const.Materials.ROCK:
							image.set_pixel(x, y, Color(0, 0, 1, 0))
						Const.Materials.WEAK_SCRAP:
							image.set_pixel(x, y, Color(0.5, 0, 0, 1))
						Const.Materials.STRONG_SCRAP:
							image.set_pixel(x, y, Color(0.25, 0, 0, 1))
						Const.Materials.ULTRA_SCRAP:
							image.set_pixel(x, y, Color(0, 0, 0, 1))
						Const.Materials.EMPTY, _:
							image.set_pixel(x, y, Color(1, abs(noise.get_noise_2d(x+512, y+512)), abs(noise.get_noise_2d(x+1024, y+1024)), abs(noise.get_noise_2d(x+2048, y+2048))))
			
			false # image.unlock() # TODOConverter3To4, Image no longer requires locking, `false` helps to not break one line if/else, so it can freely be removed
			floormap.set_pixel_data(image.get_data(), Vector2(1024, 1024))

		if event.keycode == KEY_F6:
			var noise = FastNoiseLite.new()
			noise.seed = randi()
			noise.fractal_octaves = 2
			noise.period = 20.0
			noise.persistence = 0.8
#			terrain_config.terrain_data.alt_floor = false
			floormap2.material.set_shader_parameter("use_black_as_alpha", false)
			
			var data = pixelmap.get_pixel_data()
			var image = Image.new()
			image.create(1024, 1024, false, Image.FORMAT_RGBA8)
			false # image.lock() # TODOConverter3To4, Image no longer requires locking, `false` helps to not break one line if/else, so it can freely be removed
			var tex_size = pixelmap.get_texture().get_size()/8
			for x in pixelmap.get_texture().get_width()/8:
				for y in pixelmap.get_texture().get_height()/8:
					var off = Vector2(noise.get_noise_2d(x, y), noise.get_noise_2d(x+tex_size.x, y+tex_size.y))
					off = (off*5).round()
					var coord:Vector2
					var color = Color(0,0,0,0)
					coord = Vector2(x,y) + off
					var was_empty = false
					var mat = data[(x + y * pixelmap.get_texture().get_width()) * 4 * 8 + 1]
					for i in 2:
						for j in 2:
							var ix = x + j*2 - 1 
							var iy = y + i*2 - 1 
							if ix >=0 and iy>=0 and ix<tex_size.x and iy<tex_size.y:
								if data[(ix + iy * pixelmap.get_texture().get_width()) * 4 * 8 + 1] == Const.Materials.EMPTY:
									was_empty = true
								if not data[(ix + iy * pixelmap.get_texture().get_width()) * 4 * 8 ]:
									was_empty = true

					if not data[(x + y * pixelmap.get_texture().get_width()) * 4 * 8 ]:
						mat = Const.Materials.EMPTY
					match mat:
						Const.Materials.LUMEN, Const.Materials.DEAD_LUMEN:
							image.set_pixel(x, y, Color(0, 1, 0, 0))
						_:
							if mat == Const.Materials.EMPTY or was_empty:
								var nbr_size = 7
								var sum = [INF,INF]
								var total = [0.0,0.0]
								for i in nbr_size:
									for j in nbr_size:
										coord = Vector2(x+j-nbr_size/2,y+i-nbr_size/2) + off
										if coord.x>=0 and coord.y>=0 and coord.x<tex_size.x and coord.y<tex_size.y:
											mat = data[(coord.x + coord.y * pixelmap.get_texture().get_width()) * 4 * 8 + 1]
											if not data[(coord.x + coord.y * pixelmap.get_texture().get_width()) * 4 * 8 ]:
												mat = Const.Materials.EMPTY
											var col2 = get_floor2_color(mat)
											
											match col2:
												1:
													total[0] = 2
													var lame = 1+Vector2(i-nbr_size/2,j-nbr_size/2).length()
													if sum[0] > lame:
														sum[0] = lame
												2:
													total[1] = 2
													var lame = 1+Vector2(i-nbr_size/2,j-nbr_size/2).length()
													if sum[1] > lame:
														sum[1] = lame
												_:
													pass
#											if not col2 == 0:
#												var lame = 1+Vector2(i-nbr_size/2,j-nbr_size/2).length()
#												if sum > lame:
#													sum = lame
#												total += 1
#												color += get_floor2_color(mat) / lame
								if total[0]+total[1]:
									color = Color(total[0]/sum[0],total[1]/sum[1], 0, 0)
								else:
									color = Color(noise.get_noise_2d(x+2048, y+2048), 0 ,abs(noise.get_noise_2d(x*0.5+4096, y*0.5+4096)*2), 0)
#								color /= sum
							image.set_pixel(x, y, color)
					
					
					
					
#					var mat = data[(x+3 + (y+3) * pixelmap.get_texture().get_width()) * 4 * 8 + 1]
#					if not data[(x+3 + (y+3) * pixelmap.get_texture().get_width()) * 4 * 8 ]:
#						mat = Const.Materials.EMPTY
#					match mat:
#						Const.Materials.LUMEN, Const.Materials.DEAD_LUMEN:
#							image.set_pixel(x, y, Color(0, 1, 0, 0))
#						Const.Materials.EMPTY:
#							var color = Color(0,0,0,0)
#							mat = data[(x+3 + (y+6) * pixelmap.get_texture().get_width()) * 4 * 8 + 1]
#							if not data[(x+3 + (y+6) * pixelmap.get_texture().get_width()) * 4 * 8 ]:
#								mat = Const.Materials.EMPTY
#							color += get_floor2_color(mat)
#							mat = data[(x+3 + y * pixelmap.get_texture().get_width()) * 4 * 8 + 1]
#							if not data[(x+3 + y * pixelmap.get_texture().get_width()) * 4 * 8 ]:
#								mat = Const.Materials.EMPTY
#							color += get_floor2_color(mat)
#							mat = data[(x+6 + (y+3) * pixelmap.get_texture().get_width()) * 4 * 8 + 1]
#							if not data[(x+6 + (y+3) * pixelmap.get_texture().get_width()) * 4 * 8 ]:
#								mat = Const.Materials.EMPTY
#							color += get_floor2_color(mat)
#							mat = data[(x + (y+3) * pixelmap.get_texture().get_width()) * 4 * 8 + 1]
#							if not data[(x + (y+3) * pixelmap.get_texture().get_width()) * 4 * 8 ]:
#								mat = Const.Materials.EMPTY
#							color += get_floor2_color(mat)
#							color *= 0.5
#							image.set_pixel(x+3, y+3, color)
			false # image.unlock() # TODOConverter3To4, Image no longer requires locking, `false` helps to not break one line if/else, so it can freely be removed
			floormap2.set_pixel_data(image.get_data(), Vector2(1024, 1024))
			image.save_png("test.png")
		
		if event.keycode == KEY_F7:
			if event.control:
				var png := Image.new()
				png.load("user://edit_me.png")
				pixelmap.set_pixel_data(png.get_data(), png.get_size())
			else:
				pixelmap.get_texture().get_data().save_png("user://edit_me.png")
		
		if event.keycode == KEY_F10:
			print("dev mode")
			dev_mode = true
			if load_dialog.visible:
				load_dialog.hide()
				on_load_map()
		
#		if event.scancode == KEY_KP_1:
#			var channel_podmieniacz = load("res://Tools/RandomScripts/ChannelPodmieniacz.gd")
#			channel_podmieniacz.RealPodmieniacz.podmien_channel(floormap2, 3, 0)
#		if event.scancode == KEY_KP_2:
#			var channel_podmieniacz = load("res://Tools/RandomScripts/ChannelPodmieniacz.gd")
#			channel_podmieniacz.RealPodmieniacz.podmien_channel(floormap2, 3, 1)
#		if event.scancode == KEY_KP_3:
#			var channel_podmieniacz = load("res://Tools/RandomScripts/ChannelPodmieniacz.gd")
#			channel_podmieniacz.RealPodmieniacz.podmien_channel(floormap2, 3, 2)
#		if event.scancode == KEY_KP_4:
#			var channel_podmieniacz = load("res://Tools/RandomScripts/ChannelPodmieniacz.gd")
#			channel_podmieniacz.RealPodmieniacz.podmien_channel(floormap2, 3, 3)

func get_floor2_color(mat:int)->int:
	match mat:
		Const.Materials.LUMEN, Const.Materials.DEAD_LUMEN:
			return 2
		Const.Materials.DIRT, Const.Materials.CLAY, Const.Materials.ROCK,Const.Materials.WEAK_SCRAP,Const.Materials.STRONG_SCRAP,Const.Materials.ULTRA_SCRAP:
			return 1
		_:
			return 0

func move_ui_to_corners(control: Control): ## nieużywane
	if not control.has_meta("corner_offset"):
		control.set_meta("corner_offset", control.position)
		control.set_meta("current_corner", Vector2())
	var corner_offset: Vector2 = control.get_meta("corner_offset")
	var current_corner: Vector2 = control.get_meta("current_corner")
	
	if current_corner.x == 1 and edit_panel.get_local_mouse_position().x > edit_panel.size.x * 0.8:
		current_corner.x = 0
		control.position.x = corner_offset.x
	elif current_corner.x == 0 and edit_panel.get_local_mouse_position().x < edit_panel.size.x * 0.2:
		current_corner.x = 1
		control.position.x = edit_panel.size.x - control.size.x - corner_offset.x
	
	if current_corner.y == 1 and edit_panel.get_local_mouse_position().y > edit_panel.size.y * 0.8:
		current_corner.y = 0
		control.position.y = corner_offset.y
	elif current_corner.y == 0 and edit_panel.get_local_mouse_position().y < edit_panel.size.y * 0.2:
		current_corner.y = 1
		control.position.y = edit_panel.size.y - control.size.y - corner_offset.y
	
	control.set_meta("current_corner", current_corner)

func place_object(object: EditorObject, position: Vector2):
	object.position = position
	placed.add_child(object)
	object._on_placed()
	object.connect("data_changed", Callable(self, "set_unsaved").bind(true))

func draw_on_map(where := cursor_pos()):
	if drawing == 0:
		return
	
	var pixmap := get_current_pixel_map()
	
	if pixmap == pixelmap:
		if drawing == 1:
			pixelmap.update_material_mask_rotated(where, draw_shape, terrain_config.selected_material, Vector3(draw_scale, draw_scale, draw_rotation), 1 << Const.Materials.EMPTY if replace_mode.selected == 2 else 0xFFFFFFFF, 255 if terrain_config.selected_material == Const.Materials.TAR else 0, replace_mode.selected == 1)
		elif drawing == -1:
			pixelmap.update_material_mask_rotated(where, draw_shape, -1, Vector3(draw_scale, draw_scale, draw_rotation))
	elif pixmap == floormap2 or drawing == 1:
		var floor_color := Color(0, 0, 0, 0)
		if drawing == 1:
			floor_color[terrain_config.selected_floor % 4] = 1
		
		if is_equal_approx(terrain_config.floor_hardness.value, 1):
			pixmap.update_data_raw(where / pixmap.scale, draw_scale * 64 / pixmap.scale.x, floor_color, 3, PixelMap.REPLACE)
		else:
			if drawing == 1:
				pixmap.update_data_raw(where / pixmap.scale, draw_scale * 64 / pixmap.scale.x, floor_color * terrain_config.floor_hardness.value, 3, PixelMap.ADD)
			else:
				floor_color[terrain_config.selected_floor % 4] = 1
				pixmap.update_data_raw(where / pixmap.scale, draw_scale * 64 / pixmap.scale.x, floor_color * terrain_config.floor_hardness.value, 3, PixelMap.SUBTRACT)

func flood_fill(start: Vector2):
	var to_fill: Array
	var to_check: Array
	var checked: Array
	
	var start_pixel := pixelmap.get_pixel_at(start)
	var mat := Utils.get_pixel_material(start_pixel)
	var empty := start_pixel.a == 0
	
	to_check.append(start.floor())
	while not to_check.is_empty():
		## TODO: fix crash lol
		var point: Vector2 = to_check.pop_back()
		checked.append(point)
		
		if not Rect2(Vector2(), pixelmap.get_texture().get_size()).has_point(point):
			continue
		
		var pixel := pixelmap.get_pixel_at(point)
		if empty and pixel.a > 0 or not empty and pixel.a < 0.5:
			continue
		
		if not empty and Utils.get_pixel_material(pixel) != mat:
			continue
		
		to_fill.append(point)
		add_point(point + Vector2.RIGHT, to_check, checked)
		add_point(point + Vector2.UP, to_check, checked)
		add_point(point + Vector2.LEFT, to_check, checked)
		add_point(point + Vector2.DOWN, to_check, checked)
	
	if not to_fill.is_empty():
#		previous_map_state = pixelmap.get_pixel_data()
		
		for point in to_fill:
			pixelmap.update_material_circle(point, 1, terrain_config.selected_material)

func add_point(point: Vector2, to_check: Array, checked: Array):
	if not point in to_check and not point in checked:
		to_check.append(point)

func _overlay_draw() -> void:
	if not is_processing():
		return
	
	if picking_target and not is_instance_valid(picking_target):
			picking_target = null
	elif picking_target:
		for object in placed.get_children():
			if object.can_pick_target(picking_target.is_action):
				object._draw_rect(overlay, Color.GREEN_YELLOW)
		overlay.draw_set_transform_matrix(Transform2D())
	
	if locate_object:
		locate_object._draw_rect(overlay, Color.GREEN_YELLOW)
		overlay.draw_set_transform_matrix(Transform2D())
	
	if current_hovered:
		current_hovered._draw_rect(overlay, Color.YELLOW)
		overlay.draw_set_transform_matrix(Transform2D())
	
	if current_selected:
		current_selected._draw_rect(overlay, Color.YELLOW)
		overlay.draw_set_transform_matrix(Transform2D())
	
	if can_rotate_object:
		var tex := preload("res://Nodes/Editor/Icons/Rotate.png")
		overlay.draw_texture_rect(tex, Rect2(cursor_pos() - tex.get_size() * 0.125, tex.get_size() * 0.25), false)
	
	if range_edit_control:
		var tex := preload("res://Nodes/Editor/Icons/Radius.png")
		overlay.draw_texture_rect(tex, Rect2(cursor_pos() - tex.get_size() * 0.125, tex.get_size() * 0.25), false)
	
	if scan_resources != Vector2(-1, -1):
		overlay.draw_rect(Utils.make_me_rect(scan_resources, cursor_pos()), Color.AQUAMARINE, false, 2)
		
		if not histogram.is_empty():
			var font := preload("res://Resources/Anarchy/Fonts/spacemono_regular_super_mega_micro.tres")
			
			var res: int
			res += histogram[Const.Materials.WEAK_SCRAP] / (Const.ResourceSpawnRate[Const.Materials.WEAK_SCRAP]  * resource_rate.value)
			res += histogram[Const.Materials.STRONG_SCRAP] / (Const.ResourceSpawnRate[Const.Materials.STRONG_SCRAP]  * resource_rate.value)
			res += histogram[Const.Materials.ULTRA_SCRAP] / (Const.ResourceSpawnRate[Const.Materials.ULTRA_SCRAP]  * resource_rate.value)
			if res > 0:
				overlay.draw_string(font, cursor_pos(), str(tr("Metal"), " ", res))
			
			res = 0
			res += histogram[Const.Materials.LUMEN] / (Const.ResourceSpawnRate[Const.Materials.LUMEN]  * resource_rate.value)
			res += histogram[Const.Materials.DEAD_LUMEN] / (Const.ResourceSpawnRate[Const.Materials.LUMEN]  * resource_rate.value)
			if res > 0:
				overlay.draw_string(font, cursor_pos() + Vector2.DOWN * font.get_height(), str(tr("Lumen"), " ", res))
	
	if not draw_cursor or not drawing_enabled:
		return
	
	var cursor := draw_cursor
	if terrain_config.selected_floor > -1:
		cursor = circle_shape
	
	var size := cursor.get_size() * draw_scale
	var pos := get_line_end_point() if line_start != Vector2(-1, -1) else cursor_pos()
	if get_current_pixel_map() != pixelmap:
		pos = pos.snapped(Vector2.ONE * 4) + Vector2.ONE * 4
	
	overlay.draw_set_transform(pos, draw_rotation, Vector2.ONE)
	overlay.draw_texture_rect(cursor, Rect2(-size * 0.5, size), false, Color(0, 0, 1, 0.5))
	
	if line_start != Vector2(-1, -1):
		overlay.draw_set_transform(line_start, draw_rotation, Vector2.ONE)
		overlay.draw_texture_rect(cursor, Rect2(-size * 0.5, size), false, Color(0, 0, 1, 0.5))
		overlay.draw_set_transform_matrix(Transform2D())
		overlay.draw_line(line_start, get_line_end_point(), Color.BLUE, 2)

func cursor_pos() -> Vector2:
	return overlay.get_viewport_transform().affine_inverse() * (viewport.get_parent().get_local_mouse_position())

func get_line_end_point() -> Vector2:
	var end_point := cursor_pos()
	
	if Input.is_key_pressed(KEY_CTRL):
		var line_vector := end_point - line_start
		var angle := line_vector.angle()
		angle = deg_to_rad(round(rad_to_deg(angle) / 15) * 15)
		end_point = line_start + Vector2.RIGHT.rotated(angle) * line_vector.length()
	
	return end_point

func is_hovering_selected() -> bool:
	return current_selected and current_selected._has_point(cursor_pos())

func set_camera_position(position: Vector2):
	camera.position = position
	camera.force_update_transform()
	camera.position = camera.get_camera_screen_center()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if pixelmap.visible and unsaved and quitting == NONE:
			confirm_quit(EXIT)
		else:
			get_tree().quit()
	
	if what == NOTIFICATION_PREDELETE:
		Utils.editor = null

func confirm_quit(from: int):
	quitting = from
	exit_dialog.call_deferred("popup_centered")

func exit_anyway():
	exit_dialog.hide()
	if quitting < 0:
		quitting *= -1
	
	match quitting:
		QUIT:
			exit()
		LOAD:
			on_load_map()
		NEW:
			on_new_map()
		EXIT:
			get_tree().quit()
	quitting = NONE

func exit():
	if unsaved and quitting == NONE:
		confirm_quit(QUIT)
		return
	
	get_tree().change_scene_to_file(Const.TITLE_SCENE)

func cancel_exit():
	if quitting > 0:
		quitting = NONE

func toggle_help() -> void:
	control_help.visible = not control_help.visible

func on_manage_maps() -> void:
	set_main_panel("FileManager")

func on_any_map(reset_camera := true):
	$"%TestMap".disabled = false
	$"%ValidateMap".disabled = false
	if not Music.is_demo_build():
		$"%SaveMap".disabled = false
		$"%SaveAs".disabled = false
	some_map_active = true
	
	if reset_camera:
		camera.zoom = Vector2(0.125, 0.125)
		camera.position = Vector2()
	
	$"%SaveStatus".show()
	unsaved = true
	set_unsaved(false)
	
	if not user_settings.get("helped"):
		$"%Help".button_pressed = true
		toggle_help()
		user_settings.helped = true
		save_user_settings()

func save_closed() -> void:
	exit_anyway()

func on_change_focus(control: Control):
	is_editing_text = false
	if control is LineEdit or control is TextEdit:
		is_editing_text = true

func import_image(path: String):
	var image := Image.new()
	image.load(path)
	pixelmap.set_pixel_data(image.get_data(), image.get_size())

func on_generate() -> void:
	generated_terrain = load("res://Nodes/Map/Generator/TerrainGenerator.gd").new()
	var bounds: Vector2 = (map_size / generated_terrain.Piece.PIECE_SIZE).floor()
	var start := Vector2(randi() % int(bounds.x), randi() % int(bounds.y))
	generated_terrain.bounds = bounds
	generated_terrain.generate(start, 50)
	terrain_preview.set_generated_terrain(generated_terrain)
	clear_terrain_button.disabled = false

func set_map_size(size: Vector2):
	map_size = size
	camera.limit_right = size.x
	camera.limit_bottom = size.y
	
	for i in 1000:
		if viewport.size.x * camera.zoom.x > camera.limit_right:
			camera.zoom -= Vector2.ONE * 0.1
		else:
			break

func on_map_size_changed(value: float) -> void:
	set_map_size(Vector2.ONE * value)
	terrain_preview.update()

func on_clear_generated() -> void:
	generated_terrain = null
	clear_terrain_button.disabled = true
	terrain_preview.set_generated_terrain(null)
	terrain_preview.update()

func start_target_pick(target: Object):
	clear_selected_objects()
	picking_target = target

func center_on_object(object: EditorObject):
	camera.global_position = object.global_position

func get_terrains() -> Array:
	var ret: Array
	
	for i in starting_material.get_item_count() - 1:
		var mat_name: String = starting_material.get_item_text(i)
		var mat: int = starting_material.get_item_id(i)
		if mat in Const.SwappableMaterials:
			mat_name = terrain_config.terrain_data.terrain[Const.SwappableMaterials.find(mat)].capitalize()
			
		ret.append({name = mat_name, id = mat})
	
	return ret

func set_unsaved(uns: bool):
	if uns == unsaved or is_configuring:
		return
	
	unsaved = uns
	if unsaved:
		$"%SaveStatus".modulate = Color.RED
		$"%SaveStatus".tooltip_text = "Unsaved"
		map_validated = false
	elif not map_validated:
		$"%SaveStatus".modulate = Color.GREEN
		$"%SaveStatus".tooltip_text = "Saved"

func set_validated():
	$"%SaveStatus".modulate = Color.CYAN
	$"%SaveStatus".tooltip_text = "Validated"
	map_validated = true

func generic_changed(value) -> void:
	set_unsaved(true)

func get_internal_tags() -> PackedStringArray:
	var tags: PackedStringArray
	
	if map_validated:
		tags.append("validated")
	
	tags.append("objective:" + objective_settings.get_data().win.type)
	
	if not get_edit_group("Waves").get_data().is_empty():
		tags.append("waves")
	
	if not get_edit_group("Events").get_data().is_empty():
		tags.append("events")
	
	return tags

func configure_object(object: EditorObject):
	is_configuring = true
	object._configure(self)
	is_configuring = false

func save_presets() -> void:
	user_settings.color_presets = darkness_color.get_picker().get_presets()
	save_user_settings()
	
func save_user_settings():
	var file =  FileAccess.open("user://editor_settings.txt", FileAccess.WRITE)
	file.store_string(var_to_str(user_settings))
