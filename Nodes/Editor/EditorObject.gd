@tool
extends Node2D
class_name EditorObject

const SIMPLE_OBJECTS = {
	"Explosive Barrel": "res://Nodes/Objects/Explosive/ExplosiveBarrel.tscn",
	"Monster Egg": "res://Nodes/Objects/Egg/MonsterEgg.tscn",
	"Boulder": "res://Nodes/Objects/Rock/Rock.tscn",
	"Glowing Coral": "res://Nodes/Objects/Deco/Sea_flower/sea_flower.tscn",
	"Tree": "res://Nodes/Objects/Deco/Tree/Tree.tscn",
}

@export var custom_condition_list: Array
@export var custom_action_list: Array

var object_type: String
var object_name: String
var object_data: Dictionary
var defaults: Dictionary

var can_rotate: bool

var icon: Sprite2D
var tooltip_dirty: bool
var config_dirty: bool

signal data_changed
signal deleted

func copy() -> EditorObject:
	var dupe := duplicate() as EditorObject
	dupe.object_type = object_type
	dupe.object_name = object_name
	dupe.object_data = object_data.duplicate(true)
	dupe.icon = dupe.get_child(0)
	dupe.can_rotate = can_rotate
	return dupe

func set_icon(i: Sprite2D):
	icon = i
	icon.show_behind_parent = true
	add_child(icon)

func init_data(data: Dictionary):
	object_data = data
	_init_data()
	object_data.merge(defaults)
	_refresh()

func destroy():
	if Utils.editor.current_selected == self:
		Utils.editor.current_selected = null
	
	if Utils.editor.current_hovered == self:
		Utils.editor.current_hovered = null
	
	if Utils.editor.locate_object == self:
		Utils.editor.locate_object = null
	
	queue_free()

func _init_data():
	pass

func _refresh():
	queue_redraw()

func _configure(editor):
	pass

func _hover_object(object: EditorObject):
	pass

func _push_object(object: EditorObject) -> bool:
	return false

func _unhover_object():
	pass

func _unhover():
	pass

func _get_tooltip() -> Control:
	return null

func _has_point(p: Vector2) -> bool:
	var rect := icon.get_rect()
	rect.position *= icon.scale
	rect.size *= icon.scale
	return has_rotated_point(p - position, rect, rotation)

func has_rotated_point(point: Vector2, rect: Rect2, rot: float) -> bool:
	point -= rect.position
	rect.position = Vector2()
	point -= rect.size * 0.5
	point = point.rotated(-rot)
	point += rect.size * 0.5
	return rect.has_point(point)

func _draw_rect(canvas: CanvasItem, color: Color):
	var rect := icon.get_rect()
	rect.position = position + rect.position * icon.scale
	rect.size *= icon.scale
	draw_rotated_rect(canvas, rect, rotation, color)

func draw_rotated_rect(canvas: CanvasItem, rect: Rect2, rot: float, color: Color):
	canvas.draw_set_transform(rect.position + rect.size * 0.5, rot, Vector2.ONE)
	canvas.draw_rect(Rect2(-rect.size * 0.5, rect.size), color, false, 1.5)

func draw_icon(p_icon: Texture2D, size := Vector2(), color := Color.WHITE):
	var icon_size := p_icon.get_size()
	if size != Vector2():
		icon_size = size
	draw_texture_rect(p_icon, Rect2(-size * 0.5, size), false, color)

func get_value(value: String):
	if value in object_data:
		return object_data[value]
	else:
		return defaults[value]

func _rotate(r: int):
	if can_rotate:
		rotation += PI/16 * r

func create_numeric_input(editor, text: String, field: String, min_value := 1.0, max_value := 9999.0, slider := false, step := -1.0) -> Range:
	var vbox := VBoxContainer.new()
	
	var label := Label.new()
	label.text = text
	label.autowrap = true
	vbox.add_child(label)
	
	var ranger: Range
	var value_label: LineEdit
	
	if slider:
		var le_slider = preload("res://Nodes/Editor/GUI/LineEditSlider.tscn").instantiate()
		vbox.add_child(le_slider)
		ranger = le_slider.get_child(0)
	else:
		ranger = SpinBox.new()
	
	ranger.min_value = min_value
	ranger.max_value = max_value
	if step > 0:
		ranger.step = step
	
	if not field.is_empty():
		ranger.value = object_data.get(field, 0)
		ranger.connect("value_changed", Callable(self, "_set_object_data_callback").bind(field))
	
	if not ranger.get_parent():
		vbox.add_child(ranger)
	
	if value_label:
		value_label.text = str(ranger.value)
	
	editor.add_object_setting(vbox)
	
	return ranger

func create_checkbox(editor, text: String, field: String):
	var checkbox := CheckBox.new()
	checkbox.text = text
	checkbox.button_pressed = object_data.get(field, false)
	checkbox.connect("toggled", Callable(self, "_set_object_data_callback").bind(field))
	editor.add_object_setting(checkbox)

func _set_object_data_callback(value, field: String):
	object_data[field] = value
	emit_signal("data_changed")
	_refresh()

var fetching: bool

func _on_placed():
	pass

func _on_deleted():
	emit_signal("deleted")

func _to_string() -> String:
	return str(object_name, " ", position)

func get_data() -> Dictionary:
	return object_data

func set_data(data: Dictionary):
	init_data(data)

func is_placed() -> bool:
	return get_parent().name == "PlacedObjects"

func get_dict() -> Dictionary:
	var object := {}
	object.position = position
	if can_rotate:
		object.rotation = rotation
	object.type = object_type
	object.name = object_name
	object.data = get_data()
	return object

func can_pick_target(action: bool) -> bool:
	if action:
		return not action_get_events().is_empty()
	else:
		return not get_condition_list().is_empty()

func get_id() -> int:
	return get_index()

func action_get_events() -> Array:
	return custom_action_list

func get_condition_list() -> Array:
	return custom_condition_list

func get_target_name() -> String:
	return str(tr(object_name), " <", round(position.x), ", ", round(position.y), ">")

func get_short_target_name() -> String:
	return str(Utils.trim_string(tr(object_name), 13), " <", round(position.x), ", ", round(position.y), ">")

func get_additional_config(editor, condition_action: String) -> Control:
	return null

static func create_from_data(editor, object: Dictionary):
	match object.type:
		"Building":
			return editor.create_object_by_name(editor.buildings_buttons, object.name)
		"Enemy", "Enemy Swarm":
			return editor.create_object_by_name(editor.enemy_buttons, object.name)
		"Object":
			return editor.create_object_by_name(editor.object_buttons, object.name)

static func instance(object: Dictionary, map: Node2D, helper: Dictionary, interactive := false):
	match object.type:
		"Building":
			var building_data: Dictionary = Const.Buildings.get(object.name, {})
			if building_data.is_empty(): ## compat
				object.name = load("res://Scenes/Editor/MapEditor.gd").COMPAT_OBJECTS.get(object.name)
				building_data = Const.Buildings[object.name]
			
			await Utils.load_resource(building_data.scene, interactive)
			var actual_building: Node2D = Utils.async_resource_loader.resource.instantiate()
			actual_building.position = object.position
			if object.data.get("ignored_by_enemies", false):
				actual_building.enemy_ignore = true
			
			if actual_building is BaseBuilding and not Engine.is_editor_hint():
				actual_building.angle = object.get("rotation", 0)
				actual_building.hp = object.data.get("health", actual_building.building_data.max_hp)
				actual_building.update_angle()
				actual_building.update_resource_ratio()
				actual_building.refresh_hp_on_start()
			else:
				actual_building.rotation = object.get("rotation", 0)
			map.add_editor_object(actual_building)
			
			match object.name:
				"Reactor":
					if object.data.running:
						actual_building.start()
						map.connect("ready", Callable(actual_building.get_node("AnimationPlayer"), "advance").bind(1000))
					
					if "radius" in object.data:
						actual_building.RANGE = object.data.radius
					else:
						actual_building.level = max(object.data.reactor_level, 1) # max = compat
						var level = actual_building.level - 1
						actual_building.RANGE = 150 + level * 40
						actual_building.max_hp = 1000 + level * 1000
						actual_building.hp += (level * 1000)
					
					actual_building.disable_zap = object.data.get("disable_zap", false)
					actual_building.enabled_screens = object.data.get("enabled_screens", 15)
					actual_building.add_lumen_slots(object.data.get("chunk_slots", 0))
				"Machinegun Turret", "Sniper Turret", "Flamethrower Turret", "Missile Turret", "Bomb Turret":
					actual_building.start_upgrades = object.data.upgrades
					actual_building.increase_limit_on_start = object.data.get("increase_limit", true)
				"Gate":
					actual_building.should_open = object.data.open
				"Storage Container":
					actual_building.stored_lumen = object.data.lumen
					actual_building.stored_metal = object.data.scrap
				"Item Rack":
					if not object.data.stored_item.is_empty():
						actual_building.stored_item = object.data.stored_item
						actual_building.stored_item.merge({data = null})
				"Lumen Farm":
					actual_building.mushroom_count = object.data.mushrooms
					actual_building.speed = object.data.speed
				"Health Center":
					actual_building.upgrade_level = object.data.level
				"Hero Center":
					actual_building.owning_player_id = object.data.player_id
				"Generator":
					actual_building.turned_on = object.data.running
					actual_building.stored_power = object.data.stored_power
				"Wall":
					actual_building.set_wall_level(object.data.get("level", 0))
		"Enemy":
			var scene: String = Const.Enemies.get(object.name, {}).get("scene", "")
			if scene.is_empty(): ## compat
				push_error("Unknown enemy: " + object.name)
				return
			
			await Utils.load_resource(scene, interactive)
			var actual_enemy: BaseEnemy = Utils.async_resource_loader.resource.instantiate()
			actual_enemy.position = object.position
			actual_enemy.set_rotation_custom(object.rotation)
			actual_enemy.override_stats = object.data.overrides
			if object.data.has("max_distance_from_spawn_position"):
				actual_enemy.max_distance_from_spawn_position = object.data.max_distance_from_spawn_position
			var loot = object.data.get("items", [])
			if not loot.is_empty():
				for item in loot:
					item.id = Const.ItemIDs.keys().find(item.id)
				
				var loot_node := preload("res://Nodes/Objects/Helper/EnemyLoot.gd").new()
				loot_node.pickups = loot
				actual_enemy.add_child(loot_node)
			
			map.add_editor_object(actual_enemy)
		"Enemy Swarm":
			if Engine.is_editor_hint():
				var swarm: Swarm = load(Const.Enemies[object.name].scene).instantiate()
				swarm.position = object.position
				swarm.how_many = object.data.count
				swarm.spawn_radius = object.data.radius
				swarm.prioritize_player = true
				swarm.just_wander = true
				swarm.attacks_terrain = false
				map.add_editor_object(swarm)
			else:
				var fake_swarm = preload("res://Nodes/Enemies/FakeSwarm.gd").new()
				fake_swarm.scene = Const.Enemies[object.name].scene
				fake_swarm.position = object.position
				fake_swarm.amount = object.data.count
				fake_swarm.radius = object.data.radius
				map.add_editor_object(fake_swarm)
		"Object":
			match object.name:
				"Start Point":
					var node := Node2D.new()
					node.name = "Start"
					node.position = object.position
					map.add_editor_object(node)
				"Goal Point":
					var node: Node2D = preload("res://Nodes/Objects/Goal/Goal.tscn").instantiate()
					node.index = object.data.get("index", -1)
					node.set_time(object.data.get("time_limit", 0))
					node.message = object.data.get("message", "")
					node.position = object.position
					map.add_editor_object(node)
				"Pickup":
					var id: int = Const.ItemIDs.keys().find(object.data.id)
					
					if id < Const.RESOURCE_COUNT:
						for i in object.data.amount:
							helper.pickables_to_spawn.append({position = object.position + Vector2(randf_range(-8, 8), randf_range(-8, 8)), type = id, scale = Vector2.ONE * 0.1, velocity = Vector2(randf_range(-8, 8), randf_range(-8, 8)), pointed = true})
						map.add_editor_object(null)
					else:
						var pickup := Pickup.instance(id)
						pickup.data = object.data.data
						pickup.amount = object.data.amount
						pickup.position = object.position
						map.add_editor_object(pickup)
				"Armored Box":
					var box := Pickup.instance(Const.ItemIDs.ARMORED_BOX)
					box.position = object.position
					box.data = []
					for item in object.data.items:
						item.id = Const.ItemIDs.keys().find(item.id)
						box.data.append(item)
					map.add_editor_object(box)
				"Chest", "Rusty Chest":
					if object.name == "Chest":
						await Utils.load_resource("res://Nodes/Objects/Chest/Chest.tscn", interactive)
					else:
						await Utils.load_resource("res://Nodes/Objects/Chest/RustyChest.tscn", interactive)
					var chest: PixelMapRigidBody = Utils.async_resource_loader.resource.instantiate()
					chest.position = object.position
					chest.rotation = object.rotation
					if object.data.get("disable_physics", false):
						chest.mode = RigidBody2D.FREEZE_MODE_STATIC
					for item in object.data.items:
						item.id = Const.ItemIDs.keys().find(item.id)
						chest.pickups.append(item)
					map.add_editor_object(chest)
				"Item Placer":
					var placer: Node2D = load("res://Nodes/Objects/Helper/ItemPlacer.gd").new() as Node2D
					placer.position = object.position
					placer.radius = object.data.radius
					placer.mode = object.data.mode
					for item in object.data.items:
						item.id = Const.ItemIDs.keys().find(item.id)
						placer.items.append(item)
					map.add_editor_object(placer)
				"Laptop":
					await Utils.load_resource("res://Nodes/Objects/Deco/Laptop.tscn", interactive)
					var laptop: Node2D = Utils.async_resource_loader.resource.instantiate() as Node2D
					laptop.position = object.position
					laptop.message = object.data.message
					map.add_editor_object(laptop)
				"Wave Spawner":
					var spawner = preload("res://Nodes/Enemies/Spawners/WaveSpawner.tscn").instantiate()
					spawner.radius = object.data.radius
					spawner.position = object.position
					map.add_editor_object(spawner)
				"Water Source", "Lava Source":
					var source: Node2D
					if object.name == "Water Source":
						source = preload("res://Nodes/Objects/Map/WaterSource.tscn").instantiate()
					else:
						source = preload("res://Nodes/Objects/Map/LavaSource.tscn").instantiate()
						if object.data.get("destroy_terrain", true):
							source.fluid_dmg_durability_threshold = 4
							source.fluid_dmg = 4
						
						if "id" in object.data:
							source.fluid_source_id = object.data.id
					
					source.fluid_radius = object.data.radius
					source.position = object.position
					source.fluid_is_simulated = object.data.get("flowing", true)
					map.add_editor_object(source)
				"Monster Nest":
					await Utils.load_resource("res://Nodes/Objects/AlienNest/AlienNest.tscn", interactive)
					var nest = Utils.async_resource_loader.resource.instantiate()
					nest.max_spawn = object.data.max_enemy_count
					nest.sprite = object.data.skin
					nest.position = object.position
					nest.max_hp = object.data.get("max_hp", 150)
					nest.attack_base = object.data.get("attack_base", false)
					nest.min_sec_spawn = object.data.get("spawn_interval", 5.0)
					
					if object.data.swarm.begins_with("Swarm/"):
						nest.swarm_scene = load(Const.Enemies[object.data.swarm.get_slice("/", 1)].scene)
					elif Const.Enemies[object.data.swarm].is_swarm:
						nest.swarm_scene = load(Const.Enemies[object.data.swarm].scene)
					else:
						var enemy = load(Const.Enemies[object.data.swarm].scene).instantiate()
						nest.add_child(enemy, true)
					
					map.add_editor_object(nest)
				"Hole Trap":
					await Utils.load_resource("res://Nodes/Objects/Hole/Hole.tscn", interactive)
					var trap = Utils.async_resource_loader.resource.instantiate()
					if object.data.enemy.begins_with("Swarm"):
						trap.swarm_object = load(Const.Enemies[object.data.enemy.get_slice("/", 1)].scene)
					else:
						trap.swarm_object = load(Const.Enemies[object.data.enemy].scene)
					trap.total_monsters = object.data.enemy_count
					trap.max_monsters_at_once = object.data.max_enemies_at_once
					trap.spawn_batch = object.data.spawn_batch
					trap.spawn_interval = object.data.spawn_interval
					trap.position = object.position
					if not object.data.get("auto_trigger", true):
						trap.disable_trigger()
					map.add_editor_object(trap)
				"Stone Gate":
					await Utils.load_resource("res://Nodes/Objects/StoneGate/StoneGate.tscn", interactive)
					var gate = Utils.async_resource_loader.resource.instantiate()
					var merged_items: Dictionary
					for item in object.data.items:
						var key = [item.id, item.get("data")]
						merged_items[key] = merged_items.get(key, 0) + item.amount
					
					var final_items: Array
					for key in merged_items:
						final_items.append({id = key[0], data = key[1], amount = merged_items[key]})
					
					for i in final_items.size():
						gate.set(str("item", i), final_items[i].id)
						gate.set(str("amount", i), final_items[i].amount)
						gate.set(str("data", i), final_items[i].get("data"))
					
					gate.position = object.position
					gate.rotation = object.rotation
					if object.data.get("open", false):
						gate.get_node("AnimationPlayer").play("Open")
						gate.get_node("AnimationPlayer").advance(1000)
						gate.opened = true
					map.add_editor_object(gate)
				"Technology Orb":
					await Utils.load_resource("res://Nodes/Pickups/Orb/TechnologyOrb.tscn", interactive)
					var orb = Utils.async_resource_loader.resource.instantiate()
					orb.data = object.data
					orb.position = object.position
					map.add_editor_object(orb)
				"Metal Vein":
					await Utils.load_resource("res://Nodes/Objects/OreVein/MetalVein.tscn", interactive)
					var vein = Utils.async_resource_loader.resource.instantiate()
					vein.count = object.data.get("metal_count", 3000)
					vein.position = object.position
					map.add_editor_object(vein)
					
					if object.data.get("has_miner", false):
						vein.create_miner()
						vein.miner.position = vein.position
						map.add_child(vein.miner, true)
				"Teleport Plate":
					await Utils.load_resource("res://Nodes/Objects/Teleport/Teleport.tscn", interactive)
					var teleport = Utils.async_resource_loader.resource.instantiate()
					teleport.position = object.position
					teleport.color = object.data.color
					map.add_editor_object(teleport)
				"Lumen Mushroom":
					await Utils.load_resource("res://Nodes/Objects/Mushrooms/Mushroom.tscn", interactive)
					var shroom: Node2D = Utils.async_resource_loader.resource.instantiate() as Node2D
					shroom.position = object.position
					shroom.rotation = randf_range(0, TAU)
					shroom.random_growth = object.data.random
					if not object.data.random:
						shroom.scale = Vector2.ONE * object.data.scale
						shroom.max_grow = object.data.max_growth
					map.add_editor_object(shroom)
				"Light3D":
					var light := preload("res://Nodes/Lights/LightSprite.tscn").instantiate() as LightSprite
					light.position = object.position
					light.modulate = object.data.color
					light.drop_shadow = object.data.shadow
					light.scale = Vector2.ONE * object.data.radius / 128.0
					light.is_static = true
					light.visible = object.data.get("enabled", true)
					light.reveal_fog = object.data.get("reveal_fog", false)
					map.add_editor_object(light)
				"Interactive Light3D":
					var light = preload("res://Nodes/Buildings/InteractiveLight/InteractiveLight.tscn").instantiate()
					light.position = object.position
					light.offset = object.data.offset
					light.color = object.data.color
					light.duration = object.data.duration
					light.pattern = object.data.pattern
					map.add_editor_object(light)
				"Terrain Modifier":
					var mod := preload("res://Nodes/Objects/Helper/Events/TerrainModifier.gd").new()
					mod.position = object.position
					mod.rotation = object.rotation
					mod.shape = object.data.shape
					match mod.shape:
						mod.editor.RECTANGLE:
							mod.size = Vector2(object.data.width, object.data.height)
						mod.editor.CIRCLE:
							mod.radius = object.data.radius
					map.add_editor_object(mod)
				"Trigger":
					var trigger := preload("res://Nodes/Objects/Helper/Events/Trigger.gd").new()
					trigger.position = object.position
					trigger.size = Vector2(object.data.width, object.data.height)
					map.add_editor_object(trigger)
				"Timer":
					var timer := preload("res://Nodes/Objects/Helper/Events/EventTimer.gd").new()
					timer.wait_time = object.data.time
					timer.autostart = object.data.autostart ## tak chyba nie?
					map.add_editor_object(timer)
				"Lumen Chunk":
					await Utils.load_resource("res://Nodes/Unique/LumenChunk.tscn", interactive)
					var chunk = Utils.async_resource_loader.resource.instantiate()
					chunk.position = object.position
					map.add_editor_object(chunk)
					
					if object.data.display_marker:
						var marker := preload("res://Nodes/Map/MapMarker/MapMarker.tscn").instantiate()
						marker.texture = preload("res://Nodes/Unique/PlacerCircle.png")
						marker.scale = Vector2.ONE * object.data.marker_radius / 256.0
						marker.position = chunk.position + Utils.random_point_in_circle(object.data.marker_radius)
						marker.modulate = Color.WHITE
						map.add_child(marker)
				"Marker":
					var marker := preload("res://Nodes/Objects/Helper/Events/Marker.gd").new()
					marker.position = object.position
					marker.visible = object.data.visible
					marker.mode = object.data.display_mode
					map.add_editor_object(marker)
				_:
					var obj: Node2D = load(SIMPLE_OBJECTS[object.name]).instantiate() as Node2D
					obj.position = object.position
					map.add_editor_object(obj)
		"Custom":
			match object.name:
				"Swarm Scene":
					var swarm: Swarm = load(object.scene).instantiate()
					swarm.data_to_load = object.data
					swarm.just_wander=true
					swarm.enemies_spawned=1
					swarm.how_many = 1
					map.add_editor_object(swarm)
				"Crafted Rect":
					var parent = Constants.get_crafted_rect(object.data.rect).scene.instantiate()
					
					for node in parent.get_children():
						node.position += object.position
						parent.remove_child(node)
						map.add_editor_object(node)
					
					parent.free()
				"Script":
					var custom = load(object.script_path).new()
					map.add_editor_object(custom)
