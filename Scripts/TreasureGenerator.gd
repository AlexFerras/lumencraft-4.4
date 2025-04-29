@tool
extends RefCounted
const RARITY_CHANCES = {
	5: 10,
	4: 50,
	3: 100,
	2: 500,
}

const RARITY_QUALITY = {
	5: 0.5,
	4: 0.3,
	3: 0.2,
	2: 0.1,
}

static var item_cache = {}
static var pool_cache = {}
static var hack = [false]

static func reset():
	item_cache.clear()

var rng: RandomNumberGenerator

func _init():
	if item_cache.is_empty():
		for item in Const.Items:
			item_cache[item] = Const.Items[item].duplicate()
		
		item_cache[Const.ItemIDs.AMMO].stack_size = 50
		item_cache[Const.ItemIDs.METAL_SCRAP] = {item_id = Const.ItemIDs.METAL_SCRAP, rarity = 1, quality = 1}
		item_cache[Const.ItemIDs.LUMEN] = {item_id = Const.ItemIDs.LUMEN, rarity = 1, quality = 1}
		item_cache[Const.ItemIDs.FLARE].max_stack = 30

func get_item_quality(item: Dictionary) -> float:
	if item.id == Const.ItemIDs.AMMO:
		if item.data == 1:
			return item_cache[item.id].quality * 10
	
	return item_cache[item.id].quality

func generate_treasure(value: float, rng_: RandomNumberGenerator, cfg := {}) -> Array:
	rng = rng_
	var utils = load("res://Scripts/Singleton/Utils.gd")
	
	var treasure: Array
	var divider := rng.randf_range(0.7, 0.9)
	
	var rarity_slots: Array
	var rarity_value := value
	
	var rarity_chances := RARITY_CHANCES.duplicate()
	for r in rarity_chances:
		if "super_value" in cfg and r >= 4:
			rarity_chances[r] += (500 - rarity_chances[r]) * (value / 10000) * 2
		else:
			rarity_chances[r] += (500 - rarity_chances[r]) * (value / 10000)
	
	for i in 10:
		var rarity = utils.pick_random_with_chances(rarity_chances, 1000, rng)
		if rarity is int:
			rarity_slots.append(rarity)
			if rarity >= 4 and "super_value" in cfg and not cfg.get("super_value_free_rarity", false):
				cfg.super_value_free_rarity = true
			else:
				rarity_value -= value * RARITY_QUALITY[rarity]
		
		if rarity_value <= value * divider:
			break
	
	rarity_slots.sort()
	rarity_slots.reverse()
	
	value /= 10
	for rare in rarity_slots:
		var item := generate_from_rarity(rare, value)
		if item.is_empty():
			continue
		
		if rare >= 4 and cfg.get("super_value", false):
			cfg.super_value = false
			set_item_amount(item, value)
		else:
			value -= set_item_amount(item, value)
		treasure.append(item)
	
	for i in 1000:
		if value <= 1:
			break
		
		var item := generate_from_rarity(1, value)
		if item.is_empty():
			continue
		
		value -= set_item_amount(item, value)
		treasure.append(item)
	
	for item in treasure.duplicate():
		if item.id == Const.ItemIDs.LIGHTNING_GUN:
			if hack[0]:
				treasure.erase(item)
				treasure.append({id = Const.ItemIDs.LUMEN, amount = 100, data = null})
			else:
				hack[0] = true
	
	return treasure

func generate_from_rarity(rarity: int, value: float) -> Dictionary:
	var utils = load("res://Scripts/Singleton/Utils.gd")
	
	var item: Dictionary
	
	var pool = get_item_pool(rarity)
	
	var chances: Dictionary
	for id in pool:
		match id:
			Const.ItemIDs.AMMO:
				for i in 2:
					var new_item = {id = id, data = i}
					var quality = get_item_quality(new_item)
					
					var chance = value - quality
					if chance >= 1:
						chances[new_item] = chance
			Const.ItemIDs.TECHNOLOGY_ORB:
				var chance = value - item_cache[id].quality
				if chance >= 1:
					var new_item = {id = id, data = {}}
					
					var type = rng.randi() % 3
					match type:
						0:
							new_item.data.technology = Const.Technology.keys()[rng.randi() % Const.Technology.size()]
						1:
							var weapon = Const.game_data.upgradable_weapons[rng.randi() % Const.game_data.upgradable_weapons.size()]
							var upgrade_list = Const.Items[weapon].upgrades
							var upgrade = upgrade_list[rng.randi() % upgrade_list.size()]
							new_item.data.weapon_upgrade = str(Const.ItemIDs.keys()[weapon], "/", upgrade.name)
							new_item.data.upgrade_level = 1
						2:
							new_item.data.player_upgrade = Const.game_data.scout_upgrades[rng.randi() % Const.game_data.scout_upgrades.size()]
							new_item.data.level = 1
					
					chances[new_item] = chance
			_:
				var chance = value - item_cache[id].quality
				if chance >= 1:
					chances[{id = id}] = chance
	
	if chances.is_empty():
		return {}
	
	item = utils.pick_random_with_chances(chances, 0 , rng)
	
	return item

func get_item_pool(rarity: int) -> Array:
	if rarity in pool_cache:
		return pool_cache[rarity]
	
	var pool: Array
	
	for id in Constants.ItemIDs.values():
		var item = item_cache[id]
		
		if not "rarity" in item:
			continue
		
		if item.rarity == rarity:
			pool.append(item.item_id)
	
	pool_cache[rarity] = pool
	return pool

func set_item_amount(item: Dictionary, value: int) -> int:
	var q = get_item_quality(item)
	var stack_size: int = min(item_cache[item.id].get("stack_size", 200), item_cache[item.id].get("max_stack", 99999))
	if item.id == Const.ItemIDs.AMMO and item.data == Const.Ammo.ROCKETS:
		stack_size /= 2
	var max_amount = min(stack_size, floor(value / q))
	item.amount = rng.randi_range(max(max_amount / 2, 1), max_amount)
	return q * item.amount
