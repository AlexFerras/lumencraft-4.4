@tool
extends Node2D

var fluid_source_id = -1
@export var fluid_radius = 200.0: set = set_radius
@export var fluid_flow_speed = 43.0: set = set_velocity
@export var fluid_dmg_materials_mask = 0x1FFFFFFF: set = set_dmg_materials_mask
@export var fluid_dmg_durability_threshold = 0: set = set_dmg_durability_threshold
@export var fluid_dmg = 0: set = set_dmg
@export var fluid_is_simulated: bool = false: set = set_is_simulated
@export var fluid_simulate_in_editor: bool = false: set = set_simulate_in_editor

var flammable_mask: int

enum FLUID_MATERIAL { WATER = Constants.Materials.WATER, LAVA = Constants.Materials.LAVA }
@export var fluid_type: FLUID_MATERIAL = FLUID_MATERIAL.WATER

var pixel_map: PixelMap
var is_loaded: bool

func _ready() -> void:
	if Engine.is_editor_hint():
		pixel_map = get_tree().edited_scene_root.find_child("PixelMap")
		if not get_tree().edited_scene_root.is_ancestor_of(self):
			return
	else:
		pixel_map = Utils.game.map.pixel_map
	
	if not pixel_map:
		push_error(name + ": No PixelMap!")
		return
	
	var fsp := update_fluid(false)
	if fluid_source_id == -1:
		fluid_source_id = pixel_map.addFluidSource(fluid_type, fsp)
	else:
		fluid_source_id = pixel_map.addFluidSourceAndForceID(fluid_source_id, fluid_type, fsp)
	
	set_notify_transform(true)
	pixel_map.rebuild_lava_data_texture()

func _notification(what):
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		if is_loaded:
			is_loaded = false
			return
		
		if fluid_source_id >= 0:
			update_fluid()

func set_radius(radius: float):
	fluid_radius = radius
	
	if not is_inside_tree():
		return
	
	update_fluid()
	if Engine.is_editor_hint():
		$Gizmo.update()

func set_velocity(speed: float):
	fluid_flow_speed = speed
	
	if not is_inside_tree():
		return
	
	update_fluid()

func set_dmg_materials_mask(dmg_materials_mask: int):
	fluid_dmg_materials_mask = dmg_materials_mask

	if not is_inside_tree():
		return

	update_fluid()

func set_dmg_durability_threshold(dmg_durability_threshold: int):
	fluid_dmg_durability_threshold = dmg_durability_threshold
	fluid_dmg = max(fluid_dmg, dmg_durability_threshold)
	notify_property_list_changed()

	if not is_inside_tree():
		return
	
	update_fluid()

func set_dmg(dmg: int):
	fluid_dmg = dmg
	fluid_dmg_durability_threshold = min(fluid_dmg_durability_threshold, dmg)
	notify_property_list_changed()
	
	if not is_inside_tree():
		return
	
	update_fluid()

func set_is_simulated(is_simulated: bool):
	fluid_is_simulated = is_simulated
	
	if not is_inside_tree():
		return
	
	update_fluid()

func set_simulate_in_editor(simulate_in_editor: bool):
	fluid_simulate_in_editor = simulate_in_editor

	if not is_inside_tree():
		return

	update_fluid()

func update_fluid(update_pixelmap := true) -> FluidSourceParams:
	flammable_mask = fluid_dmg_materials_mask & ~(load("res://Scripts/Singleton/Utils.gd").fire_resistant_mask)
	
	var fsp := FluidSourceParams.new()
	fsp.position = global_position
	fsp.radius = fluid_radius
	fsp.max_flood_str = fluid_flow_speed
	fsp.dmg_materials_mask = flammable_mask
	fsp.dmg_durability_threshold = fluid_dmg_durability_threshold
	fsp.dmg = fluid_dmg
	fsp.is_simulated = fluid_is_simulated
	fsp.simulate_in_editor = fluid_simulate_in_editor
	
	if update_pixelmap:
		pixel_map.updateFluidSource(fluid_source_id, fsp)
		pixel_map.rebuild_lava_data_texture()
	
	return fsp

func _get_property_list() -> Array:
	return [{name = "source_id", type = TYPE_INT, usage = PROPERTY_USAGE_STORAGE}]

func _set(property: String, value):
	if property == "source_id":
		fluid_source_id = value
		return true
	return false

func _get(property: String):
	if property == "source_id":
		return fluid_source_id
	return null

func _get_save_data() -> Dictionary:
	return {}

func _set_save_data(data: Dictionary):
	is_loaded = true

func try_spawn() -> void:
	if not pixel_map.is_pixel_solid(global_position) or ((1 << pixel_map.get_pixel_at(global_position).g8) & flammable_mask):
		pixel_map.spawnFluidAtFluidSource(fluid_source_id)

func execute_action(action: String, data: Dictionary):
	match action:
		"enable_flow":
			fluid_is_simulated = true
		"disable_flow":
			fluid_is_simulated = false
	update_fluid()
