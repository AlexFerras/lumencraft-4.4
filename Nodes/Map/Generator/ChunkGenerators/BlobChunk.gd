@tool
extends "res://Nodes/Map/Generator/ChunkGenerator.gd"

@export var filter_material: ShaderMaterial

func generate(size: Vector2):
	filter_material.set_shader_parameter("cut_off", rng.randf_range(0.091, 0.31))
#	filter_material.set_shader_param("smoothness", rng.randf_range(1.0, 5.0))
	size = size
	$Circle.size = size
	
	texture.width = size.x
	texture.height = size.y
	texture.noise.seed = rng.randi()
	await texture.changed
	
	var baker = preload("res://Scripts/TextureBaker.gd").create(size)
	baker.add_target(self, Vector2(), true)
	$Circle.hide()
	
	await baker.finished
	
	texture = baker.texture
	material = filter_material
	
	ready = true

func create_content(generator, pixel_map: PixelMap) -> Array:
	return generic_create_content(generator, pixel_map)
