extends HBoxContainer

const RENAMES = {
	Laptop = "Message Box",
}

enum {BUILDING, ENEMY, ENEMY_SWARM, OBJECT}

var type: int
var data: Dictionary

func set_building(building: Dictionary, group: ButtonGroup):
	type = BUILDING
	data.name = building.name
	data.icon = "res://Nodes/Buildings/Icons/Icon" + building.scene.get_file()
	data.can_rotate = building.build_rotate
	init(group)
	set_tooltip(building.description)
	
	var icon: Node2D = get_editor_object().icon
	icon.get_parent().queue_free()
	icon.get_parent().remove_child(icon)
	
	var my_icon: Control = $Icon
	var size: Vector2 = icon.get_node("BoundingRect").scale * icon.scale
	icon.scale *= max(my_icon.custom_minimum_size.x, my_icon.custom_minimum_size.y) / max(size.x, size.y)
	icon.position = my_icon.custom_minimum_size * 0.5
	my_icon.add_child(icon)

func set_enemy(enemy: Dictionary, group: ButtonGroup):
	type = ENEMY
	data.name = enemy.name
	data.scale = enemy.get("placeholder_scale", 1)
	init(group)
	set_tooltip(enemy.description)
	if "placeholder_sprite" in enemy:
		$Icon.texture = load(enemy.placeholder_sprite)

func set_enemy_swarm(swarm: Dictionary, group: ButtonGroup):
	set_enemy(swarm, group)
	type = ENEMY_SWARM

func set_object(object: String, group: ButtonGroup):
	type = OBJECT
	data.name = object
	init(group)
	
	var node := get_editor_object()
	$Icon.texture = node.icon.texture
	node.queue_free()

func set_pickup(id: int, dat, group: ButtonGroup):
	type = OBJECT
	data.id = id
	data.data = dat
	data.name = Utils.get_item_name({id = id, data = dat})
	init(group)
	data.name = "Pickup"
	
	var node := get_editor_object()
	$Icon.texture = node.icon.texture
	node.queue_free()

func set_tooltip(tooltip: String):
	assert(not $Name.tooltip_text.is_empty())
	$Name.tooltip_text = "%s\n%s" % [tr($Name.tooltip_text), tr(tooltip)]

func init(group: ButtonGroup):
	$Name.text = Utils.trim_string(tr(RENAMES.get(data.name, data.name)), 28)
	$Name.tooltip_text = tr(RENAMES.get(data.name, data.name))
	$Name.group = group

func get_editor_object() -> EditorObject:
	var node := EditorObject.new()
	var node_data: Dictionary
	
	match type:
		BUILDING:
			node.set_script(get_object_script("Building", data.name))
			match data.name:
				"Power Expander":
					node.radius = load("res://Nodes/Buildings/Pylon/Pylon.gd").RANGE
				"Lumen Beam":
					node.custom_condition_list = ["is_shooting"]
			
			var icon := load(data.icon).instantiate() as Node2D
			node.set_icon(icon)
			
			node.object_type = "Building"
			node.can_rotate = data.can_rotate
		ENEMY:
			node.set_script(get_object_script("Enemy", data.name))
			
			var sprite := Sprite2D.new()
			sprite.texture = $Icon.texture
			sprite.scale = Vector2.ONE * data.scale
			node.set_icon(sprite)
			
			node.object_type = "Enemy"
		ENEMY_SWARM:
			node.set_script(get_object_script("EnemySwarm", data.name))
			
			var sprite := Sprite2D.new()
			sprite.texture = $Icon.texture
			sprite.scale = Vector2.ONE * data.scale
			node.set_icon(sprite)
			
			node.object_type = "Enemy Swarm"
		OBJECT:
			node.set_script(get_object_script("Object", data.name))
			var sprite := Sprite2D.new()
			
			match data.name:
				"Start Point":
					sprite.texture = load("res://Nodes/Editor/Icons/Start.png")
					sprite.scale = Vector2.ONE * 0.5
				"Goal Point":
					sprite.texture = load("res://Nodes/UI/ScoreFinished.png")
					sprite.scale = Vector2.ONE * 0.25
				"Pickup":
					node.set_item(data.id, data.data)
					sprite.texture = Utils.get_item_icon(data.id, data.data)
					sprite.scale = Pickup.get_texture_scale(sprite.texture)
				"Armored Box":
					node.no_item_text = "No items added. Drop a Pickup object on the box to add."
					node.custom_condition_list = ["collected"]
					sprite.texture = load("res://Nodes/Pickups/ArmoredBox/chest_armored_.png")
					sprite.scale = Vector2.ONE * 0.01
				"Technology Orb":
					node.custom_condition_list = ["collected"]
					sprite.texture = load(Const.Items[Const.ItemIDs.TECHNOLOGY_ORB].icon)
					sprite.scale = Vector2.ONE * 0.25
				"Chest":
					node.true_chest = true
					sprite.texture = Utils.create_sub_texture(load("res://Nodes/Objects/Chest/Crate.png"), Rect2(Vector2(0, 20), Vector2(202, 104)))
					sprite.scale = Vector2.ONE * 0.1
				"Rusty Chest":
					sprite.texture = load("res://Nodes/Objects/Chest/WoodenChest.png")
					sprite.scale = Vector2.ONE * 0.07
				"Item Placer":
					node.no_item_text = "No items added. Drop a Pickup object on the placer to add."
					sprite.texture = load("res://Nodes/Editor/Icons/ItemPlacer.png")
					sprite.scale = Vector2.ONE * 0.25
				"Laptop":
					sprite.texture = load("res://Nodes/Objects/Deco/computer_panel_t002.png")
					sprite.scale = Vector2.ONE * 0.01
				"Wave Spawner":
					sprite.texture = load("res://Nodes/Editor/Icons/WaveSpawner.png")
				"Water Source", "Lava Source":
					node.set_liquid(data.name.split(" ")[0])
				"Monster Egg":
					sprite.texture = load("res://Nodes/Objects/Egg/Egg_001c.png")
					sprite.scale = Vector2.ONE * 0.025
				"Monster Nest":
					var nest_texture = load("res://Nodes/Objects/AlienNest/Alien_building_T001.png")
					sprite.texture = Utils.create_atlas_frame(nest_texture, Vector2(5, 3), 0)
					sprite.scale = Vector2.ONE * 0.1
				"Hole Trap":
					sprite.texture = load("res://Nodes/Objects/Hole/Hole.png")
					sprite.z_index = -1
				"Explosive Barrel":
					node.custom_condition_list = ["destroyed"]
					node.custom_action_list = ["explode"]
					sprite.texture = load("res://Nodes/Objects/Explosive/ExplosiveBarrel.png")
					sprite.scale = Vector2.ONE * 0.048
				"Metal Vein":
					sprite.texture = load("res://Nodes/Objects/OreVein/Minerals_002.png")
					sprite.scale = Vector2.ONE * 0.125
				"Stone Gate":
					node.no_item_text = "No required items defined. Drop a Pickup object on the gate to add as required item."
					node.empty_text = "No Requirement"
					sprite.texture = load("res://Nodes/Objects/StoneGate/StoneGateIcon.png")
					sprite.scale = Vector2.ONE * 0.25
				"Teleport Plate":
					sprite.texture = load("res://Nodes/Objects/Teleport/Teleport.png")
					sprite.modulate = Color("ff3333")
					sprite.scale = Vector2.ONE * 0.125
				"Light3D":
					sprite.texture = load("res://Nodes/Editor/Icons/Light3D.png")
					sprite.scale = Vector2.ONE * 0.05
				"Interactive Light3D":
					sprite.texture = load("res://Nodes/Buildings/InteractiveLight/Lightcap.png")
					sprite.scale = Vector2.ONE * 0.025
				"Boulder":
					sprite.texture = load("res://Nodes/Objects/Rock/Rock0.png")
					sprite.scale = Vector2.ONE * 0.25
				"Lumen Chunk":
					sprite.texture = load("res://Nodes/Unique/Lumen_Cristal_.png")
					sprite.scale = Vector2.ONE * 0.1
				"Lumen Mushroom":
					sprite.texture = load("res://Nodes/Objects/Mushrooms/mushroom_anim_00.png")
					sprite.material = load("res://Nodes/Objects/Mushrooms/MushroomMaterial.tres")
					sprite.scale = Vector2.ONE * 0.3
				"Glowing Coral":
					sprite.texture = load("res://Nodes/Objects/Deco/Sea_flower/body_001.png")
					sprite.scale = Vector2.ONE * 0.2
				"Tree":
					sprite.texture = load("res://Nodes/Objects/Deco/Tree/Tree.png")
					sprite.scale = Vector2.ONE * 0.5
				"Terrain Modifier":
					sprite.texture = load("res://Nodes/Editor/Icons/CSG.svg")
				"Trigger":
					sprite.texture = load("res://Nodes/Editor/Icons/Trigger.svg")
				"Timer":
					sprite.texture = load("res://Nodes/UI/WaveTimer.png")
					sprite.scale = Vector2.ONE * 0.125
				"Marker":
					sprite.texture = load("res://Resources/Textures/location.png")
					sprite.modulate = Color("ff6800")
					sprite.scale = Vector2.ONE * 0.05
			
			assert(node.get_script(), data.name)
			node.set_icon(sprite)
			node.object_type = "Object"
	
	node.object_name = data.name
	node.init_data(node_data)
	return node

func wip():
	if Music.is_game_build():
		hide()

static func get_object_script(object_type: String, object: String) -> Script:
	match [object_type, object]:
		["Building", "Reactor"]:
			return load("res://Nodes/Editor/Buildings/EditorReactor.gd") as Script
		["Building", "Generator"]:
			return load("res://Nodes/Editor/Buildings/EditorGenerator.gd") as Script
		["Building", "Gate"]:
			return load("res://Nodes/Editor/Buildings/EditorGate.gd") as Script
		["Building", "Lumen Farm"]:
			return load("res://Nodes/Editor/Buildings/EditorFarm.gd") as Script
		["Building", "Hero Center"]:
			return load("res://Nodes/Editor/Buildings/EditorHeroCenter.gd") as Script
		["Building", "Health Center"]:
			return load("res://Nodes/Editor/Buildings/EditorHospital.gd") as Script
		["Building", "Storage Container"]:
			return load("res://Nodes/Editor/Buildings/EditorStorage.gd") as Script
		["Building", "Item Rack"]:
			return load("res://Nodes/Editor/Buildings/EditorRack.gd") as Script
		["Building", "Power Expander"]:
			return load("res://Nodes/Editor/Buildings/EditorPowerBuilding.gd") as Script
		["Building", "Wall"]:
			return load("res://Nodes/Editor/Buildings/EditorWall.gd") as Script
		["Building", _]:
			if object in ["Machinegun Turret", "Sniper Turret", "Flamethrower Turret", "Missile Turret", "Bomb Turret"]:
				return load("res://Nodes/Editor/Buildings/EditorTurret.gd") as Script
			else:
				return load("res://Nodes/Editor/Buildings/EditorBuilding.gd") as Script
		["Enemy", _]:
			return load("res://Nodes/Editor/Enemies/EditorEnemy.gd") as Script
		["EnemySwarm", _]:
			return load("res://Nodes/Editor/Enemies/EditorEnemySwarm.gd") as Script
		["Object", "Start Point"]:
			return load("res://Nodes/Editor/Objects/EditorStartPoint.gd") as Script
		["Object", "Goal Point"]:
			return load("res://Nodes/Editor/Objects/EditorGoal.gd") as Script
		["Object", "Pickup"]:
			return load("res://Nodes/Editor/Objects/EditorPickup.gd") as Script
		["Object", "Armored Box"]:
			return load("res://Nodes/Editor/Objects/EditorItemContainer.gd") as Script
		["Object", "Chest"], ["Object", "Rusty Chest"]:
			return load("res://Nodes/Editor/Objects/EditorChest.gd") as Script
		["Object", "Technology Orb"]:
			return load("res://Nodes/Editor/Objects/EditorTechnologyOrb.gd") as Script
		["Object", "Item Placer"]:
			return load("res://Nodes/Editor/Objects/EditorItemPlacer.gd") as Script
		["Object", "Wave Spawner"]:
			return load("res://Nodes/Editor/Objects/EditorWaveSpawner.gd") as Script
		["Object", "Water Source"], ["Object", "Lava Source"]:
			return load("res://Nodes/Editor/Objects/EditorLiquidSource.gd") as Script
		["Object", "Laptop"]:
			return load("res://Nodes/Editor/Objects/EditorLaptop.gd") as Script
		["Object", "Monster Nest"]:
			return load("res://Nodes/Editor/Objects/EditorNest.gd") as Script
		["Object", "Hole Trap"]:
			return load("res://Nodes/Editor/Objects/EditorHoleTrap.gd") as Script
		["Object", "Metal Vein"]:
			return load("res://Nodes/Editor/Objects/EditorVein.gd") as Script
		["Object", "Stone Gate"]:
			return load("res://Nodes/Editor/Objects/EditorStoneGate.gd") as Script
		["Object", "Teleport Plate"]:
			return load("res://Nodes/Editor/Objects/EditorTeleport.gd") as Script
		["Object", "Light3D"]:
			return load("res://Nodes/Editor/Objects/EditorLight.gd") as Script
		["Object", "Interactive Light3D"]:
			return load("res://Nodes/Editor/Objects/EditorInteractiveLight.gd") as Script
		["Object", "Lumen Mushroom"]:
			return load("res://Nodes/Editor/Objects/EditorMushroom.gd") as Script
		["Object", "Terrain Modifier"]:
			return load("res://Nodes/Editor/Objects/EditorTerrainModifier.gd") as Script
		["Object", "Trigger"]:
			return load("res://Nodes/Editor/Objects/EditorTrigger.gd") as Script
		["Object", "Timer"]:
			return load("res://Nodes/Editor/Objects/EditorTimer.gd") as Script
		["Object", "Lumen Chunk"]:
			return load("res://Nodes/Editor/Objects/EditorLumenChunk.gd") as Script
		["Object", "Marker"]:
			return load("res://Nodes/Editor/Objects/EditorMarker.gd") as Script
	
	return EditorObject
