@tool
extends "res://Nodes/Map/Generator/rect_generator.gd"

@export var is_boss=false

func place_objects_impl(whatever):
	if not whatever:
		return
	
	var generator = $"%GeneratedMapBase"
	var pixel_map = $"%NotPixelMap"
	var rng: RandomNumberGenerator = generator.rng

	var rect = Rect2(position, size)
	if is_boss:
		generator.create_object("Object", "Light3D", rect.get_center(), {color = Color(0.8,0.1,0.1), radius=0.5*0.5*(size.x+size.y)+50})

	var distance_from_reactor = generator.get_distance_from_reactor(rect.get_center())
#	var better_normalized_distance_from_reactor = generator.get_distance_from_reactor_normalized_better(rect.get_center())
	
	var better_normalized_distance_from_reactor = generator.get_distance_from_reactor_normalized_4k(rect.get_center())
#	prints("better ",better_normalized_distance_from_reactor,"4k",fourk_normalized_distance_from_reactor)
	var group_power=100.0+distance_from_reactor/8.0

	var waves_gen = CustomizableWavesGenerator.new()
	waves_gen.set_emergency_swarm("Strong Spider Swarm")
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Spider Swarm", 1, 4)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Strong Spider Swarm", 4, 8)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Slow Swarm", 5, 8)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Flying Swarm", 6, 8)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Shooting Swarm", 6, 10)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Flying Shooting Swarm", 8, 10)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Arthoma", 2, 6)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Suicidoma", 4, 8)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Suicacidoma", 6, 8)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Acidoma", 8, 10)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Gobbler", 8, 10)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Crystal GRUBAS", 1, 10)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Turtle", 1, 10)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("King", 1, 10)

	var monsters = waves_gen.generate_enemy_group_based_on_wave(my_seed, min(better_normalized_distance_from_reactor, 1.0)*9+1, group_power*owner.enemy_multiplier * (4.0 if is_boss else 1.0), is_boss)

	var treasure = load("res://Scripts/TreasureGenerator.gd").new().generate_treasure((2.0 if is_boss else 1.0) * distance_from_reactor * owner.item_multiplier, rng)
	
	var possible = utils.HexPoints.get_hex_arranged_points_in_rectangle(rect, 8)
	possible.shuffle()
	var nest_position: Vector2
	
	var current_enemy = monsters.pop_back()
	for i in possible.size():
		var point: Vector2 = possible[i]
		if pixel_map.isCircleEmpty(point, 5, utils.walkable_collision_mask):
			if current_enemy.count > 4:
				if not pixel_map.isCircleEmpty(point, 30, utils.walkable_collision_mask) or nest_position.distance_squared_to(point) < 2500:
					continue
				
				var dist = generator.get_distance_from_reactor_normalized_4k(rect.get_center())
				var angle = get_angle_of_nearest_wall(point)
				var skin: int = min(int(1 + dist * 4), 3)
				#swap these two
				if skin==1:
					skin=2
				elif skin==2:
					skin=1
				
				generator.create_object("Object", "Monster Nest", point, {swarm = current_enemy.name, max_enemy_count = int(dist * 4 + 1), skin = skin, max_hp = skin * 150}, angle)
				current_enemy.count = 0
				nest_position = point
			else:
				if current_enemy.name.begins_with("Swarm"):
					generator.create_object("Enemy Swarm", current_enemy.name.get_slice("/", 1), point, {count = current_enemy.count})
					current_enemy.count = 0
				else:
					var data: Dictionary
					if not treasure.is_empty() and rng.randi() % 10 == 0:
						data.items = [treasure.pop_back()]
					elif is_boss and current_enemy.name in Const.BOSS_ENEMIES:
						var treasure2 = load("res://Scripts/TreasureGenerator.gd").new().generate_treasure(2.0 * distance_from_reactor * owner.item_multiplier, rng)
						if not treasure2.is_empty():
							data.items = [treasure[rng.randi() % treasure.size()]]
						data.max_distance_from_spawn_position=max(distance_from_reactor-200,350)
					
					generator.create_object("Enemy", current_enemy.name, point, data)
			
			if current_enemy.count > 1:
				current_enemy.count -= 1
			else:
				current_enemy = monsters.pop_back()
			
			if current_enemy == null:
				possible = possible.slice(i + 1, possible.size() - 1)
				break
	
	if treasure.is_empty():
		return
	
	if generator.get_distance_from_reactor_normalized_4k(rect.get_center()) > 0.5 and rng.randi() % 100 < 30:
		treasure = [{id = Const.ItemIDs.ARMORED_BOX, amount = 1, data = treasure}]
	
	if nest_position != Vector2():
		generator.create_object("Object", "Chest" if Engine.is_editor_hint() else "Chest", nest_position, {items = treasure, disable_physics = true}, rng.randf() * TAU)
		return
	
	for i in possible.size():
		var point: Vector2 = possible[i]
		if pixel_map.isCircleEmpty(point, 10, utils.walkable_collision_mask):
			var angle = get_angle_of_nearest_wall(point)
			generator.create_object("Object", "Chest" if Engine.is_editor_hint() else "Rusty Chest", point, {items = treasure}, angle)
			break
