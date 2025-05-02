extends PanelContainer

const SKIP_ITEMS2 = [Const.ItemIDs.PLASMA_GUN, Const.ItemIDs.DIRT_GRENADE, Const.ItemIDs.PICKAXE, Const.ItemIDs.ARTIFACT, Const.ItemIDs.TECHNOLOGY_ORB]

@onready var building_inspector = $"%BuildingInspector"
@onready var enemy_inspector = $"%EnemyInspector"
@onready var music_label = $"%MusicLabel"

var game: Game
var map: Map

var debug_enemies: bool
var show_frame_time: bool
var god_mode: bool
var alt_used: bool

var can_use: bool

func _ready() -> void:
	can_use = not Music.is_game_build()
	get_parent().hide()
	building_inspector.hide()
	enemy_inspector.hide()
	speed_changed(1)
	
	if Array(OS.get_cmdline_args()).has("lumen") or OS.has_feature("expo"):
		can_use = true
	
	if can_use:
		Utils.set_meta("debug_active", true)
	
	await get_tree().create_timer(1).timeout
	
	for item in Const.ItemIDs.values():
		if item in SKIP_ITEMS2:
			continue
		
		if item == Const.ItemIDs.AMMO:
			add_item_to_list(item, Const.Ammo.BULLETS)
			add_item_to_list(item, Const.Ammo.ROCKETS)
			add_item_to_list(item, Const.Ammo.LASERS)
		elif item == Const.ItemIDs.KEY:
			for i in 4:
				add_item_to_list(item, i)
		else:
			add_item_to_list(item)
	
	var techs = Const.Technology.keys()
	techs.sort()
	for tech in techs:
		$"%TechList".add_item(tech)
	
	for id in Const.game_data.upgradable_weapons:
		for upgrade in Const.Items[id].upgrades:
			$"%UpgradeList".add_item(Const.Items[id].default_name + ": " + upgrade.name)
			$"%UpgradeList".set_item_metadata($"%UpgradeList".get_item_count() - 1, str(id, upgrade.name))
	
	if not Utils.game.map:
		await Utils.game.map_changed
	
	$"%DisableDarkness".set_pressed_no_signal(not Utils.game.map.has_node("PixelMap/MapDarkness/Darkness") or not Utils.game.map.get_node("PixelMap/MapDarkness/Darkness").visible)
	$"%DisableFog".set_pressed_no_signal(not Utils.game.map.pixel_map.fog_of_war or not Utils.game.map.pixel_map.fog_of_war.visible)
	
	if not Music.is_game_build():
		debug_enemies = true
		show_frame_time = false
	
	var file = File.new()
	if Utils.safe_open(file, "user://debug", file.READ):
#		$VBoxContainer/FreeCamera.pressed = bool(file.get_8())
		$"%DebugEnemies".set_pressed_no_signal(bool(file.get_8()))
		debug_enemies = $"%DebugEnemies".pressed
		$"%ShowFrameTime".set_pressed_no_signal(bool(file.get_8()))
		show_frame_time = $"%ShowFrameTime".pressed
		_toggle_frame_time(show_frame_time)
#		$VBoxContainer/PauseGame.pressed = bool(file.get_8())
#		$VBoxContainer/DisableDarkness.pressed = bool(file.get_8())
#		$VBoxContainer/DisableFog.pressed = bool(file.get_8())

@onready var item_list = $"%ItemList"

func add_item_to_list(id, data = null):
	item_list.add_item(Utils.get_item_name({id = id, data = data}))
#	item_list.add_icon_item(Utils.get_item_icon(id, data), Utils.get_item_name({id = id, data = data}))
	item_list.set_item_metadata(item_list.get_item_count() - 1, {id = id, data = data})

@onready var pixel_label = $"%PixelLabel"

func _process(delta: float) -> void:
	if not is_instance_valid(Utils.game):
		queue_free()
		return
	
	if god_mode:
		for player in game.players:
			player.hp = player.get_max_hp()
			player.stamina = player.get_max_stamina()
	
	if debug_enemies:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or not enemy is BaseEnemy:
				continue
			elif enemy.is_dead:
				call_if_exists(enemy, "_debug_disable")
				enemy.update()
				continue
			
			if not enemy.is_connected("draw", Callable(self, "draw_debug")):
				enemy.connect("draw", Callable(self, "draw_debug").bind(enemy))
			
			enemy.update()
			call_if_exists(enemy, "_debug_enable")
			call_if_exists(enemy, "_debug_process")
	
	if is_visible_in_tree():
		var mouse_pos = map.get_local_mouse_position()
		var color = map.pixel_map.get_pixel_at(mouse_pos)
		pixel_label.text = "(%5.1f, %5.1f) pixel: %s" % [mouse_pos.x, mouse_pos.y, (color * 255)]
		pixel_label.add_theme_color_override("font_color", color)
		music_label.text = "Current music: %s" % Music.current_track

func draw_debug(enemy):
	if debug_enemies and not enemy.is_dead:
		call_if_exists(enemy, "_debug_draw")

func toggle_enemy_debug(enabled):
	debug_enemies = enabled
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if debug_enemies:
			call_if_exists(enemy, "_debug_enable")
		else:
			call_if_exists(enemy, "_debug_disable")
		enemy.update()
	save_settings()

func call_if_exists(target, method):
	if target.has_method(method):
		target.call(method)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed:
			if can_use and event.keycode == KEY_QUOTELEFT:
				toggle()
				accept_event()
			
			if event.keycode == KEY_N:
				if Input.is_key_pressed(KEY_L) and Input.is_key_pressed(KEY_U) and Input.is_key_pressed(KEY_M) and Input.is_key_pressed(KEY_E):
					can_use = true
		else:
			if event.keycode == KEY_ALT:
				if alt_used:
					alt_used = false
				else:
					Utils.game.camera.set_target(Utils.game.camera_target)
	
	if not event is InputEventKey or not event.pressed:
		return
	
	if not SteamAPI.IS_ONLINE and event.keycode == KEY_F12:
		var ui_exceptions = ["Player1", "Player2", "MinimapPanel", "Bars"]
		var vis: Dictionary
		
		for node in Utils.game.ui.get_children():
			if node is CanvasItem:
				if node.name in ui_exceptions:
					continue
				
				vis[node] = node.modulate
				node.modulate.a = 0
		
		DirAccess.new().make_dir_recursive("user://Screenshots")
		
		await get_tree().idle_frame
		await get_tree().idle_frame
		var data = get_viewport().get_texture().get_data()
		data.flip_y()
		data.save_png(str("user://Screenshots/screenshot-", str(Time.get_unix_time_from_system(), ".png")))
		
		for node in vis:
			node.modulate = vis[node]
	
	game = Utils.game
	if not is_instance_valid(game):
		return
	map = game.map
	if not is_instance_valid(map):
		return
	
	if not can_use:
		return
	
	if event.keycode == KEY_F1:
		Save.cheated = true
		if Input.is_key_pressed(KEY_SHIFT):
			for player in game.players:
				player.force_position = map.get_local_mouse_position()
		else:
			Utils.game.main_player.force_position = map.get_local_mouse_position()
	
	if event.keycode == KEY_F2:
		Save.cheated = true
		Utils.explode_circle(map.get_local_mouse_position(), 20, 100000, 5)
	
	if event.keycode == KEY_F3:
		Save.cheated = true
		map.pixel_map.update_material_circle(map.get_local_mouse_position(), 10, 0, 0)
		
	if event.keycode == KEY_F4:
		Save.cheated = true
		if event.control:
			game.win()
		else:
			game.main_player.damage({damage = 9999})
#		Utils.game.map.pixel_map.flesh_manager.spawn_in_position(Utils.game.map.get_local_mouse_position())
	
	# KEY_F5 - see TerrainDrawer.tscn
	
	if event.keycode == KEY_F6:
		map.pixel_map.get_texture().get_data().save_png("res://Tools/Photos/MapDump.png")
	
	if event.keycode == KEY_F7:
		Utils.set_meta("editor_debug", "user://gen.lcmap")
		Utils.change_scene_with_loading("res://Scenes/Editor/MapEditor.tscn")
	
	if event.keycode == KEY_F9:
		map.floor_surface.hard_reload()
		map.floor_surface2.hard_reload()

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_shape := CircleShape2D.new()
			
			for building in get_tree().get_nodes_in_group("player_buildings"):
				var building_shape: CollisionShape2D = Utils.get_node_by_type(building, CollisionShape2D)
				if not building_shape:
					push_error("No shape: " + building.name)
					continue
				
				if mouse_shape.collide(Transform2D(0, map.get_global_mouse_position()), building_shape.shape, building_shape.global_transform):
					if Input.is_key_pressed(KEY_ALT):
						Utils.game.camera.set_target(building)
						alt_used = true
					
					building_inspector.inspect(building)
					enemy_inspector.hide()
					break
			
			for enemy in get_tree().get_nodes_in_group("enemies"):
				var enemy_shape: CollisionShape2D = Utils.get_node_by_type(enemy, CollisionShape2D)
				if not enemy_shape:
					continue
				
				if mouse_shape.collide(Transform2D(0, map.get_global_mouse_position()), enemy_shape.shape, enemy_shape.global_transform):
					if Input.is_key_pressed(KEY_ALT):
						Utils.game.camera.set_target(enemy)
						alt_used = true
					
					building_inspector.hide()
					enemy_inspector.inspect(enemy)
					break
			
			for gate in get_tree().get_nodes_in_group("debug:stone_gates"):
				var gate_shape: CollisionShape2D = Utils.get_node_by_type(gate, CollisionShape2D)
				if not gate_shape:
					continue
#				print(node.get_local_mouse_position(), node.get_local_mouse_position().length())
#				if node.get_local_mouse_position().length() < 70:
				if mouse_shape.collide(Transform2D(0, map.get_global_mouse_position()), gate_shape.shape, gate_shape.global_transform):
					if gate.opened:
						gate.execute_action("close", {})
					else:
						gate.execute_action("open", {})

#func spawn_wave() -> void:
#	var spawner = map.find_node("WaveSpawner")
#	if spawner:
##		var spawner = manager.get_child(randi() % manager.get_child_count())
#		spawner.spawn_wave($VBoxContainer/HBoxContainer2/SpinBox.value)

func kill_all() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.take_damage_raw({damage = 9999999})

	for swarm_node in Utils.game.map.enemies_group.get_all_swarms_nodes():
		var swarm: Swarm = swarm_node
		swarm.killAllUnits()

func toggle_darknes(button_pressed: bool) -> void:
	map.set_disable_darkness(button_pressed)
#	save_settings()

func toggle_fog(button_pressed: bool) -> void:
	map.set_disable_fog_of_war(button_pressed)
#	Utils.game.map.pixel_map.fog_of_war.visible = button_pressed
#	save_settings()

func toggle_pause(button_pressed: bool) -> void:
	get_tree().paused = not get_tree().paused
#	save_settings()

func toggle_draw_pm_qt(button_pressed: bool) -> void:
	$"%StaticCL/Drawer".draw_pm_qt = button_pressed

func toggle_draw_pickables_debug(button_pressed: bool) -> void:
	$"%StaticCL/Drawer".draw_pickables_debug = button_pressed

func toggle_draw_enemy_tracker(button_pressed: bool) -> void:
	$"%StaticCL/Drawer".draw_enemy_tracker = button_pressed

func toggle_draw_swarm_debug(button_pressed: bool) -> void:
	$"%StaticCL/Drawer".draw_swarm_debug = button_pressed

func toggle_draw_player_tracker(button_pressed: bool) -> void:
	$"%StaticCL/Drawer".draw_player_tracker = button_pressed

func toggle_draw_buildings_trackers(button_pressed: bool) -> void:
	$"%StaticCL/Drawer".draw_buildings_trackers = button_pressed

func spawn_GRUBAS() -> void:
	var grubas = load("res://Nodes/Enemies/CrystalUrasectus/CrystalUrasectus.tscn").instantiate()
	grubas.position = Utils.game.main_player.position + Vector2.RIGHT * 60
	grubas.set_tracking()
	map.add_child(grubas)

func give_item() -> void:
	add_item(item_list.get_selected_metadata().id, item_list.get_selected_metadata().data, $"%SpinBox".value)

func toggle_free_camera() -> void:
	game.camera.toggle_camera_following()
	game.camera.set_process_input(not game.camera.is_camera_following)
	for player in game.players:
		player.set_process(game.camera.is_camera_following)
		player.in_vehicle = not game.camera.is_camera_following # lol
#	save_settings()

func dupa(dupa):
	execute_command()

func execute_command() -> void:
	var ref := RefCounted.new()
	var src := GDScript.new()
	src.source_code = "extends RefCounted\nfunc execute():\n\t" + $"%LineEdit".text
	src.reload()
	ref.set_script(src)
	ref.execute()

func save_settings():
	var file = File.new()
	file.open("user://debug", file.WRITE)
	
#	file.store_8(int($VBoxContainer/FreeCamera.pressed))
	file.store_8(int($"%DebugEnemies".pressed))
	file.store_8(int($"%ShowFrameTime".pressed))
	
#	file.store_8(int($VBoxContainer/PauseGame.pressed))
#	file.store_8(int($VBoxContainer/DisableDarkness.pressed))
#	file.store_8(int($VBoxContainer/DisableFog.pressed))

func toggle_ui(disable: bool):
	if disable:
		Utils.game.ui.cutscene_memo = ["lol"]
	else:
		Utils.game.ui.cutscene_memo = []
	
	for control in Utils.game.ui.get_children():
		if disable:
			control.set_meta("debug_visible", control.visible)
			control.hide()
		else:
			control.visible = control.get_meta("debug_visible")

func _toggle_frame_time(button_pressed):
	var frame_time = Utils.game.ui.get_node_or_null('FrameTimePlot')
	if not frame_time:
		return
	
	frame_time.visible = button_pressed
	frame_time.set_process( button_pressed )
	frame_time.set_physics_process( button_pressed )
	save_settings()

func speed_changed(value: float):
	Engine.time_scale = value
	$"%SpeedLabel".text = "Game speed %s" % value

func toggle_god_mode(enable: bool) -> void:
	god_mode = enable

const SKIP_ITEMS = [Const.ItemIDs.BAT,Const.ItemIDs.HOOK,Const.ItemIDs.ARTIFACT,Const.ItemIDs.KATANA,Const.ItemIDs.LASER,Const.ItemIDs.ONE_SHOT,Const.ItemIDs.PICKAXE,Const.ItemIDs.LIGHTNING_GUN,Const.ItemIDs.SICKLE, Const.ItemIDs.LANCE, Const.ItemIDs.PLASMA_GUN, Const.ItemIDs.DIRT_GRENADE, Const.ItemIDs.SUPER_GRENADE, Const.ItemIDs.FLARE, Const.ItemIDs.PICKAXE, Const.ItemIDs.ARTIFACT]

func give_all() -> void:
	for i in game.players.size():
		game.players[i].max_stacks = 1000
		Utils.game.ui.get_player_ui(i + 1).refresh_inventory()
	
	for i in Const.ItemIDs.size():
		if i < Const.RESOURCE_COUNT or i in SKIP_ITEMS:
			continue
		
		if i == Const.ItemIDs.AMMO:
			add_item(i, Const.Ammo.BULLETS)
			add_item(i, Const.Ammo.ROCKETS)
			add_item(i, Const.Ammo.LASERS)
		else:
			add_item(i)
	add_item(Const.ItemIDs.LUMEN)
	add_item(Const.ItemIDs.METAL_SCRAP)

func add_item(item: int, data = null, amount := -1):
	if amount == -1:
		amount = Utils.get_stack_size(item, data)
	
	if item == Const.ItemIDs.AMMO and data == null:
		add_item(item, Const.Ammo.BULLETS, amount)
		add_item(item, Const.Ammo.ROCKETS, amount)
		add_item(item, Const.Ammo.LASERS, amount)
		return
	
	for player in game.players:
		player.add_item(item, amount, data, true, Player.StackPolicy.ANY, true)

func toggle_alternate_health(button_pressed: bool) -> void:
	for player in game.players:
		player.get_node("AlternateHealth").set_enabled(button_pressed)

func hack_textures() -> void:
	var file = File.new()
	
	if Utils.safe_open(file, "res://Terrain.png", file.READ):
		var source = Image.new()
		source.load_png_from_buffer(file.get_buffer(file.get_length()))
		var size = Vector2(source.get_size() / 4)
		
		var texture = Texture2DArray.new()
		texture.create(size.x, size.y, 16, source.get_format())
		
		for y in 4:
			for x in 4:
				texture.set_layer_data(source.get_rect(Rect2(Vector2(x, y) * size, size)), x + y * 4)
		
		Utils.game.map.pixel_map.material.set_shader_parameter("terrain_texture_mix", texture)

func toggle_smoke(hide) -> void:
	if map.pixel_map.has_node("Smoke"):
		map.pixel_map.get_node("Smoke").visible = not hide

func force_wave() -> void:
	Utils.game.map.wave_manager.wave_countdown = 1

func force_wave_2() -> void:
	Utils.game.map.wave_manager.wave_countdown = 60

func set_max_players(value: float) -> void:
	Const.PLAYER_LIMIT = value
	Utils.game.ui.coop_settings.get_child(0).ultra_reload()

func set_fake_joypads(button_pressed: bool) -> void:
	Utils.game.ui.fake_joypads = button_pressed
	Utils.game.ui.refresh_buttons()
	Utils.game.ui.get_node("%CoopSettings").validate_scheme()

func unlock_tech() -> void:
	Save.unlock_tech($"%TechList".get_item_text($"%TechList".selected))

func upgrade_weapon() -> void:
	var tech: String = $"%UpgradeList".get_item_metadata($"%UpgradeList".selected)
	Save.set_unlocked_tech(tech, Save.get_unclocked_tech(tech) + 1)

func _on_Zoom_0075_pressed():
	game.camera.target_zoom = Vector2(0.075, 0.075)
	
func _on_Zoom_0125_pressed():
	game.camera.target_zoom = Vector2(0.075, 0.075)

func _on_Zoom_025_pressed():
	game.camera.target_zoom = Vector2(0.125, 0.125)

func _on_Zoom_05_pressed():
	game.camera.target_zoom = Vector2(0.25, 0.25)

func _on_Zoom_075_pressed():
	game.camera.target_zoom = Vector2(0.5, 0.5)
	
func _on_Zoom_1_pressed():
	game.camera.target_zoom = Vector2(0.75, 0.75)
#	game.camera.target_zoom = Vector2(1.0, 1.0)

func _on_Dark_color_changed(color):
	if is_instance_valid( Utils.game.map.pixel_map.get_node("DarknessByDistance") ):
		Utils.game.map.pixel_map.get_node("DarknessByDistance").gradient.set_color(0,color)


func _on_Light_color_changed(color):
	if is_instance_valid( Utils.game.map.pixel_map.get_node("DarknessByDistance") ):
		Utils.game.map.pixel_map.get_node("DarknessByDistance").gradient.set_color(1,color)

func create_locator() -> void:
	Utils.game.add_child(load("res://Nodes/Objects/Helper/EnemyLocator.tscn").instantiate())

func show_paths() -> void:
	Utils.game.map.wave_manager.show_all_paths_from_all_info_centers()

func toggle_wall_hack(enabled: bool) -> void:
	map.pixel_map.modulate.a = 1 - int(enabled) * 0.7

func toggle_god_reactor(button_pressed: bool) -> void:
	if button_pressed:
		game.core.set_meta("god_hp", game.core.hp)
		game.core.hp = 999999999
	else:
		game.core.hp = game.core.get_meta("god_hp", game.core.max_hp)

func next_music() -> void:
	Music.current_audio_player.stop()

func toggle():
	Save.cheated = true
	if is_instance_valid(Utils.game.map.pixel_map.get_node_or_null("DarknessByDistance")):
		$"%Dark".color = Utils.game.map.pixel_map.get_node("DarknessByDistance").gradient.get_color(0)
		$"%Light3D".color = Utils.game.map.pixel_map.get_node("DarknessByDistance").gradient.get_color(1)
	get_parent().visible =  not get_parent().visible
	if not is_visible_in_tree():
		building_inspector.hide()
		enemy_inspector.hide()

func toggle_boost_mode(button_pressed: bool) -> void:
	if Utils.nx:
		Utils.nx.set_cpu_boost(button_pressed)
