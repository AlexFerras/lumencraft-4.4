@tool
extends Sprite2D
@export var render=false: set = render
@export var create_pixelmap=false: set = create_pixelmap
@export var generate_rects =false: set = set_generate_rects
@export var render_rects_pixelmap=false: set = render_rects_pixelmap
@export var ensure_walkability=false: set = set_ensure_walkability
@export var render_rects=false: set = render_rects
@export var create_objects=false: set = create_objects_impl
@export var clear_this_scene=false: set = clear_this_scene
@export var count_resources=false: set = set_count_resources
@export var my_seed=0: set = set_seeds


@export var reactor_rect_size=200
@export var spawner_rect_size=200
@export var boss_rect_size=200
@export var nest_rect_size=200
@export var mine_rect_size=200
@export var cave_rect_size=200
@export var lava_rect_size=200

@export var save_lcmap = false: set = save_lcmap_impl


var soft_material = Const.Materials.DIRT
var hard_material = Const.Materials.CLAY


var rng:RandomNumberGenerator
var map_file: MapFile
var current_object_rect: Node

var object_stash: Array
var item_containers: Array
var required_items: Array

func set_ensure_walkability(new_is):
	if new_is==false:
		return
	ensure_walkability=false
	var step=128
	var path_end=scale*0.5
	path_end=Vector2(2000,2150)
	var starts=[]
	for x in range(step*0.5,scale.x, step):
		for y in range(step*0.5,scale.y, step):	
			starts.append(Vector2(x,y))
	starts.shuffle()
	#starts=[Vector2(700,2400)]
	var pixel_map: PixelMap = $"%NotPixelMap"	
	var blob=load("res://Resources/Textures/blob_mask128.png").get_data()

	var durabilities=pixel_map.get_user_materials_durability()
	for i in range(len(durabilities)):
		durabilities[i]*=100
	
	var blocking_mask=(1<<Const.Materials.ROCK )


	for start in starts:
		var found=0
		while found<10:
			var path_data: PathfindingResultData =pixel_map.find_path_astar_through_materials(start, path_end, durabilities, 1.0, ~(blocking_mask), true, 9) 
			
			if path_data:
				if !path_data.path_found:
					var path=path_data.get_path()
					var blob_pos=path[len(path)-1]
					#if len(path)>=2:
					#	blob_pos-=(path[len(path)-1]-path[len(path)-2]).normalized()*32
					var dir=(path_end-blob_pos).normalized()
					#blob_pos-=dir*32
					#print("ray   ",blob_pos,"        ",path_end)
					var ray=pixel_map.rayCastQTDistance(blob_pos,dir,128,(blocking_mask))
					#pixel_map.update_material_mask_rotated(blob_pos,blob,Const.Materials.DIRT,Vector3(rand_range(1.0,1.0)*0.5,rand_range(1.0,1.0)*0.5,randf()*TAU),(1<<Const.Materials.ROCK ))
					if ray:
					#	print("ray_trafil ",ray.hit_position)
						blob_pos=ray.hit_position
					#else:
					#	blob_pos+=dir*32

						
					#print("robie dziure ",blob_pos)
					pixel_map.update_material_mask_rotated(blob_pos,blob,Const.Materials.DIRT,Vector3(randf_range(1.0,1.0)*0.8,randf_range(1.0,1.0)*0.8,randf()*TAU),blocking_mask)
					#print("koniec")
					found+=1
				else:
					found=5777777
					#print("finish")
			else:
				break

func colliding_with_ther_rects(rect):
	var generated_rects=$"%generated_rects"
	var colliding=false
	for i in generated_rects.get_children():
		if Rect2(i.position,i.size).intersects(rect):
			colliding=true
			break
	return colliding
			
func choose_preset_to_fill_rect(curr_rect):
	var presets=$"%good_rects_presets"
	
	var presets_array=presets.get_children()
	var i =0
	while i < presets_array.size():
		if presets_array[i].visible==false:
			presets_array.remove(i)
			continue
	
		
		if !presets_array[i].can_be_placed_in_rect(curr_rect.size):
			presets_array.remove(i)
			continue
		i+=1
	var total_probability=0
	for preset in presets_array:
		total_probability+=preset.probability
	var ran=randi()%total_probability
	var start=0
	for preset in presets_array:
		if ran<start+preset.probability:
			return preset.duplicate()
		start+=preset.probability

#return presets_array[randi() %presets_array.size()].duplicate()
			
	
	

func generate_rects_pass(rectangles):
		
	var generated_rects=$"%generated_rects"

	var i=0
#	if Engine.editor_hint:
#		print(rectangles)
	while i < len(rectangles):
		var curr_rect: Rect2=rectangles[i]
		var j=0
		while j <5:
			if i<rectangles.size()-j:
					var other_rect=rectangles[i+j]

					var merged=curr_rect.merge(other_rect)
					if merged.size.x*merged.size.y==curr_rect.size.x*curr_rect.size.y+other_rect.size.x*other_rect.size.y:
						curr_rect=merged
						rectangles.remove(i+j)
						j-=1
			j+=1
		i+=1

		
#			var size_diff=Vector2(
#				0 if curr_rect.size.x<curr_rect.size.y else curr_rect.size.x*rand_range(0.0,0.5),
#				0 if curr_rect.size.x>curr_rect.size.y else curr_rect.size.y*rand_range(0.0,0.5))
#			curr_rect.size-=size_diff
#			#curr_rect.position+=Vector2(size_diff.x*randf(),size_diff.y*randf())
#			match randi()%4:
#				0:
#					pass
#				1:
#					curr_rect.position+=Vector2(size_diff.x,size_diff.y)
#				2:
#					curr_rect.position+=Vector2(0,size_diff.y)
#				3:
#					curr_rect.position+=Vector2(size_diff.x,0)
		#curr_rect=curr_rect.grow(32)
		
		var new_rect=choose_preset_to_fill_rect(curr_rect)
		new_rect.position=curr_rect.position
		new_rect.size = curr_rect.size
		
		if new_rect.variable_size>0:
			var size_diff=Vector2(
				0 if new_rect.size.x<new_rect.size.y else new_rect.size.x*randf_range(0.0,new_rect.variable_size),
				0 if new_rect.size.x>new_rect.size.y else new_rect.size.y*randf_range(0.0,new_rect.variable_size))
			new_rect.size-=size_diff
			#curr_rect.position+=Vector2(size_diff.x*randf(),size_diff.y*randf())
			match randi()%4:
				0:
					pass
				1:
					new_rect.position+=Vector2(size_diff.x,size_diff.y)
				2:
					new_rect.position+=Vector2(0,size_diff.y)
				3:
					new_rect.position+=Vector2(size_diff.x,0)

		
		
#		var new_rect=empty_rect.instance()
#		new_rect.position=curr_rect.position
#		new_rect.scale=curr_rect.size
		
		
		generated_rects.add_child(new_rect)
		new_rect.my_seed=randi()
		new_rect.owner=get_parent()
		new_rect.propagate_call("set_owner",[get_parent()])
		new_rect.rect_placed_randomizer()


func set_generate_rects(new_is):
	if new_is==false:
		return
	generate_rects=false
	
	var generated_rects=$"%generated_rects"
	for i in generated_rects.get_children():
		generated_rects.remove_child(i)
		i.queue_free()
		
	
	rng=RandomNumberGenerator.new()
	rng.seed=randi() if my_seed==0 else my_seed
	seed(my_seed)

	var caves_gen :ProceduralMapCavesGenerator=$"%caves_gen"
	var reactor_pos=caves_gen.get_reactor_position()
		

	var viewport=$"%SubViewport"
	var pixel_map: PixelMap = $"%NotPixelMap"
	#pass 1 rects on everything not bedrock

	
	var rectangles: Array = pixel_map.getEmptyRegions(7, (1<<Const.Materials.ROCK), true)

	generate_rects_pass(rectangles)

	for preset in $"%good_rects_presets".get_children():
		if !preset.visible:
			continue
		for req in preset.distance_requirements:
			var min_distance=req[0]
			var max_distance=req[1]
			var count=req[2]

			var rect_gens=generated_rects.get_children()
			rect_gens.shuffle()
			
			
			for i in count:
				var placed=false
				for rect in rect_gens:
					if is_instance_valid(rect) and rect.empty and preset.can_be_placed_in_rect(rect.size):
						var distance_from_reactor=get_distance_from_reactor(rect.position+rect.size*0.5)
						if distance_from_reactor>min_distance and distance_from_reactor<max_distance:

							var new_rect=preset.duplicate()
							new_rect.size=rect.size
							new_rect.position=rect.position
							generated_rects.remove_child(rect)
							rect.free()
							generated_rects.add_child(new_rect)
							new_rect.my_seed=randi()
							new_rect.owner=get_parent()
							new_rect.propagate_call("set_owner",[get_parent()])
							placed=true
							print("placed on empty")
							break
				if placed:
					continue
				#we are here because it was unable to place on empty rect we need to force placemant now
				#try to replace any rect
				for rect in rect_gens:
					if is_instance_valid(rect) and preset.can_be_placed_in_rect(rect.size):
						var distance_from_reactor=get_distance_from_reactor(rect.position+rect.size*0.5)
						if distance_from_reactor>min_distance and distance_from_reactor<max_distance:

							var new_rect=preset.duplicate()
							new_rect.size=rect.size
							new_rect.position=rect.position
							generated_rects.remove_child(rect)
							rect.free()
							generated_rects.add_child(new_rect)
							new_rect.my_seed=randi()
							new_rect.owner=get_parent()
							new_rect.propagate_call("set_owner",[get_parent()])
							placed=true
							print("placed on any")
							break
				if placed:
					continue
				#we are here because it was unable to place on any rect we need to force placemant now
				#very unlikely but we need to force placemant to bigger rect
				for rect in rect_gens:
					if is_instance_valid(rect) and preset.is_smaller_than_size(rect.size):
						var distance_from_reactor=get_distance_from_reactor(rect.position+rect.size*0.5)
						if distance_from_reactor>min_distance and distance_from_reactor<max_distance:

							var new_rect=preset.duplicate()
							new_rect.size=new_rect.min_size
							new_rect.position=rect.position
							generated_rects.remove_child(rect)
							rect.free()
							generated_rects.add_child(new_rect)
							new_rect.my_seed=randi()
							new_rect.owner=get_parent()
							new_rect.propagate_call("set_owner",[get_parent()])
							placed=true
							print("placed on bigger")
							break
				if placed:
					continue
				#we are here because it was unable to place on any larger rect
				#force placement on any cost in the middle of mindistance and maxdistance
				var forced_distance_from_recator=randf_range(max(min_distance,150.0),max_distance)
				
				var new_rect2=Rect2()
				new_rect2.size=preset.min_size
				var map_rect2=Rect2(Vector2(0,0),scale)
				for try in 400:
					new_rect2.position=+reactor_pos+forced_distance_from_recator*Vector2(0,1).rotated(randf()*TAU)
					if map_rect2.encloses(new_rect2) and !colliding_with_ther_rects(new_rect2) and pixel_map.get_materials_histogram_rect(new_rect2)[Const.Materials.ROCK]<new_rect2.get_area()*0.5:
						
						var new_rect=preset.duplicate()
						new_rect.size=new_rect2.size
						new_rect.position=new_rect2.position
						generated_rects.add_child(new_rect)
						new_rect.my_seed=randi()
						new_rect.owner=get_parent()
						new_rect.propagate_call("set_owner",[get_parent()])
						placed=true
						print("placed forced")
						break
				if !placed:
					printerr("cannot place rect ",preset.name ," on map")
				
								
	

	
	var aoa_positions= [
						caves_gen.get_wave_spawns_positions(),
						caves_gen.get_bosses_spawns_positions(),
						caves_gen.get_mines_positions(),
						caves_gen.get_caves_positions(),
						caves_gen.get_nests_positions()]

	var ao_sizes=	 [	
						spawner_rect_size,
						boss_rect_size,
						mine_rect_size,
						cave_rect_size,
						nest_rect_size]
						
						

	
	var ao_radiuses= [	
						caves_gen.get_wave_spawns_radiuses(),
						caves_gen.get_bosses_spawns_radiuses(),
						caves_gen.get_mines_radiuses(),
						caves_gen.get_caves_radiuses(),
						caves_gen.get_nests_radiuses()]	
	var ao_presets= [	
						$"../cave_presets/spawner_rect",
						$"../cave_presets/boss_rect",
						$"../cave_presets/mine_rect",
						$"../cave_presets/cave_rect",
						$"../cave_presets/nest_rect"]
	for i in range(len(aoa_positions)):
		for j in range(len(aoa_positions[i])):		
			var size=Vector2.ONE*ao_radiuses[i][j]*2*1.3
			var rect_pos=aoa_positions[i][j]-size*0.5
			if get_distance_from_reactor(rect_pos)<(ao_presets[i]).min_distance_from_reactor:
				continue
			var new_rect=ao_presets[i].duplicate()
			new_rect.size=size
			new_rect.position=rect_pos
			generated_rects.add_child(new_rect)
			new_rect.my_seed=randi()
			new_rect.owner=get_parent()
			new_rect.propagate_call("set_owner",[get_parent()])


	var lava_positions=caves_gen.get_lava_sources_positions()
	var lava_radiuses=caves_gen.get_lava_sources_radiuses()

	var lava_preset=$"../cave_presets/lava_rect"
	for i in range(len(lava_positions)):
		var new_rect=lava_preset.duplicate()
		new_rect.size.x=randf_range(min(150.0,lava_radiuses[i]*2.0), min(200.0,lava_radiuses[i]*1.5)) 
		new_rect.size.y=randf_range(min(150.0,lava_radiuses[i]*2.0), min(200.0,lava_radiuses[i]*1.5))
		new_rect.position=lava_positions[i]-new_rect.size*0.5
		var lava_rect=Rect2(new_rect.position,new_rect.size)
		for j in generated_rects.get_children():
			if j.remove_if_lava_rect and lava_rect.intersects(Rect2(j.position,j.size)):
				generated_rects.remove_child(j)
				
		
		generated_rects.add_child(new_rect)
		new_rect.my_seed=randi()
		new_rect.owner=get_parent()
		new_rect.propagate_call("set_owner",[get_parent()])
		new_rect.lava_source_id=i+1
		new_rect.lava_radius=lava_radiuses[i]
		


	var reactor_preset=$"../cave_presets/reactor_rect"
	var new_rect=reactor_preset.duplicate()
	new_rect.size=Vector2.ONE*caves_gen.get_reactor_radius()*2*1.3
	new_rect.position=caves_gen.get_reactor_position()-new_rect.size*0.5
	generated_rects.add_child(new_rect)
	new_rect.my_seed=randi()
	new_rect.owner=get_parent()
	new_rect.propagate_call("set_owner",[get_parent()])
	var reactor_rect=Rect2(new_rect.position,new_rect.size)
	for j in generated_rects.get_children():
		if j.remove_if_lava_rect and reactor_rect.intersects(Rect2(j.position,j.size)):
			generated_rects.remove_child(j)
#


#	render_rects_pixelmap(true)
#	yield(self, "pass_finished")


	


signal pass_finished
func create_pixelmap(nothing):
	if nothing==false:
		return
	create_pixelmap=false
	var pixel_map: PixelMap = $"%NotPixelMap"
	
	#$"%Viewport".size = Vector2.ONE * owner.map_size
	var map_tex=$"%SubViewport".get_texture()
	pixel_map.set_pixel_data(map_tex.get_data().get_data(), map_tex.get_size())
	if Engine.is_editor_hint():
		print("pixelmap_created")
		pixel_map.material=load("res://Resources/Materials/PixelMapMaterial.tres")
				
func clear_this_scene(nothing):
	if nothing==false:
		return
	clear_this_scene=false
	for i in get_children():
		if i.is_class("Sprite2D"):
			if i.material:
				i.material.set_shader_parameter("map",null)

	var rects=$"%generated_rects"				
	for i in rects.get_children():
		for sprite in i.get_children():
			if sprite.is_class("Sprite2D"):
				if sprite.material:
					sprite.material.set_shader_parameter("map",null)		
	
	for i in $"%generated_rects".get_children():
		i.queue_free()	
		
	for i in $"%swarm_batchs".get_children():
		i.queue_free()
				
	for i in $"%Objects".get_children():
		i.queue_free()
				
func set_seeds(new_seed):
	if new_seed==my_seed:
		return
	if not has_node(@"%generated_rects"):
		return
	
	refresh_scale()
	my_seed=new_seed
	var last_seed=0
	var rnd=RandomNumberGenerator.new()
	rnd.seed=randi() if new_seed==0 else new_seed
	for i in get_children():
		if i.is_class("Sprite2D"):
			if i.material:
				if !i.use_same_seed:
					last_seed=rnd.randi_range(-10000,10000)
				i.my_seed=last_seed

	for i in $"%generated_rects".get_children():
		i.my_seed=rnd.randi_range(-10000,10000)
	
	
	if Engine.is_editor_hint():
		$"%caves_gen".my_seed = new_seed

								
signal render_done

func render(newren):
	if newren==false:
		return
	render=false

	refresh_scale()
	var viewport=$"%SubViewport"
			
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_ONCE
	await RenderingServer.frame_post_draw
	viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_NEVER

	
	for i in get_children():
		if i is Node2D:
			var was_color=i.modulate
			i.modulate.r8=255 if i.material_type != Const.Materials.EMPTY else 0
			if i.material_type == Const.Materials.DIRT:
				i.modulate.g8 = soft_material
			elif i.material_type == Const.Materials.CLAY:
				i.modulate.g8 = hard_material
			else:
				i.modulate.g8 = i.material_type
			i.modulate.b8= 0
			i.modulate.a8= 255 

			remove_child(i)
			viewport.add_child(i)
			i.owner=get_parent()
			if !i.keep_scale:
				i.scale=self.scale
			else:
				i.scale=Vector2(1.0,1.0)
				
			var texture_dup=viewport.get_texture()
			if i.material and i.material.is_class("ShaderMaterial"):
				
				if i.needs_duplicate_texture:
					texture_dup =ImageTexture.new()
					texture_dup.create_from_image(viewport.get_texture().get_data())
					i.texture=texture_dup
				i.material.set_shader_parameter("map",texture_dup)
				i.material.set_shader_parameter("material_mask",i.mask)
			i.update()
			

			viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			await RenderingServer.frame_post_draw
			if i.get("needs_duplicate_texture"):
				i.material.set_shader_parameter("map",null)
				i.texture=null

				
		
			#if i.material and i.material.is_class("ShaderMaterial"):
			#	i.material.set_shader_param("map",null)

			viewport.remove_child(i)
			if !i.keep_scale:
				i.scale=Vector2.ONE
			else:
				i.scale=Vector2(1.0,1.0)/self.scale

			i.modulate=was_color
			add_child(i)
			i.owner=get_parent()
	$"%map".texture=viewport.get_texture()
	#hack refresh
	$"%map".visible=false
	$"%map".visible=true
	emit_signal("render_done")
	
#	var mapimg=viewport.get_texture().get_data()
#	mapimg.convert(Image.FORMAT_RGBA8)
#	mapimg.save_png("dupa11.png")



func render_rects(newren):
	if newren==false:
		return
	render_rects=false
	
	
	refresh_scale()
	var viewport=$"%SubViewport"

	viewport.render_target_clear_mode=SubViewport.CLEAR_MODE_NEVER
	var rects=$"%generated_rects"
	for i in rects.get_children():
		for sprite in i.get_children():
			if sprite == null or not sprite.get_script(): 
				continue
			
			if sprite is Sprite2D:
				var was_color=sprite.modulate
				sprite.modulate.r8=255
				sprite.modulate.g8=sprite.material_type
				sprite.modulate.b8=0
				sprite.modulate.a8=255
				var was_parent=sprite.get_parent()
				var render_scale=sprite.global_scale
				var render_pos=sprite.global_position
				
				was_parent.remove_child(sprite)
				viewport.add_child(sprite)
				sprite.owner=get_parent()
				sprite.scale=render_scale
				sprite.position=render_pos
				if sprite.material and sprite.material.is_class("ShaderMaterial"):
					var texture_dup =ImageTexture.new()
					texture_dup.create_from_image(viewport.get_texture().get_data())
					sprite.material.set_shader_parameter("map",texture_dup)
					sprite.material.set_shader_parameter("material_mask",sprite.mask)
				sprite.update()

				viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
				await RenderingServer.frame_post_draw

			
				#if i.material and i.material.is_class("ShaderMaterial"):
				#	i.material.set_shader_param("map",null)

				viewport.remove_child(sprite)
#				sprite.scale=Vector2.ONE
				sprite.position=Vector2.ZERO
				sprite.modulate=was_color
				was_parent.add_child(sprite)
				sprite.owner=get_parent()
	$"%map".texture=viewport.get_texture()
	#hack refresh
	$"%map".visible=false
	$"%map".visible=true
	
	var mapimg=viewport.get_texture().get_data()
	mapimg.convert(Image.FORMAT_RGBA8)
	mapimg.save_png("dupa11.png")
	
	
func set_count_resources(newren):
	if newren==false:
		return
	count_resources=false


	
	var pixel_map: PixelMap = $"%NotPixelMap"
	
	var metal_total = 0
	var lumen_total = 0
	
	var histogram=pixel_map.get_materials_histogram()
	
	metal_total += histogram[Const.Materials.WEAK_SCRAP] /Const.ResourceSpawnRate[Const.Materials.WEAK_SCRAP]
	lumen_total += histogram[Const.Materials.LUMEN] /Const.ResourceSpawnRate[Const.Materials.LUMEN]
	
	prints("Metal from minning:", histogram[Const.Materials.WEAK_SCRAP] /Const.ResourceSpawnRate[Const.Materials.WEAK_SCRAP])
	prints("Lumen from mining:", histogram[Const.Materials.LUMEN]/Const.ResourceSpawnRate[Const.Materials.LUMEN])
	
	var vein_metal = 0
	var nigget_metal = 0
	var chest_metal = 0
	
	var mushroom_lumen = 0
	var clump_lumen = 0
	var chest_lumen = 0
	
	for object in $"%Objects".get_children():
		if object.name.begins_with("MetalVein"):
			vein_metal += object.count
		elif object.name.begins_with("Mushroom"):
			mushroom_lumen += object.lumens_inside * object.scale.x
		elif object.name.begins_with("LumenClump"):
			clump_lumen += 25
		elif object.name.begins_with("MetalNugget"):
			nigget_metal += 25
		elif object.name.begins_with("Chest"):
			for pickup in object.get("pickups"):
				if pickup.id == Const.ItemIDs.LUMEN:
					chest_lumen += pickup.amount
				elif pickup.id == Const.ItemIDs.METAL_SCRAP:
					chest_metal += pickup.amount
	
	metal_total += vein_metal
	prints("Vein metal:", vein_metal)
	
	metal_total += nigget_metal
	prints("Nugget metal:", nigget_metal)
	
	metal_total += chest_metal
	prints("Chest metal:", chest_metal)
	
	lumen_total += mushroom_lumen
	prints("Mushroom lumen:", mushroom_lumen)
	
	lumen_total += clump_lumen
	prints("Clump lumen:", clump_lumen)
	
	lumen_total += chest_lumen
	prints("Chets lumen:", chest_lumen)
	
	prints("Total metal:", metal_total)
	prints("Total lumen:", lumen_total)
	
func render_rects_pixelmap(newren):
	if newren==false:
		return
	render_rects_pixelmap=false

	var pixel_map: PixelMap = $"%NotPixelMap"
	var rects=$"%generated_rects"
	for rect in rects.get_children():
		if rect.render_me== true:
			rect.render_me=false
			for preview in rect.get_children():
				for sprite in preview.get_children():
					if not sprite.get_script():
						continue
					
					var target_size: Vector2
					if sprite is Sprite2D:
						if sprite.use_rect_as_size:
							if not sprite.texture:
								push_error("Zepsuty rect. Za mały?")
								breakpoint
								continue
							target_size = sprite.texture.get_size()
						else:
							target_size = sprite.global_scale
					else:
						target_size = sprite.size
					
					var baker = preload("res://Scripts/TextureBaker.gd").create(target_size)
					var was_scale: Vector2
					#var offset=sprite.global_position-rect.global_position
					if sprite is Sprite2D:
						was_scale=sprite.scale
						sprite.scale=sprite.global_scale
					else:
						was_scale=sprite.scale
						sprite.scale=Vector2.ONE
					
					baker.add_target(sprite, Vector2.ZERO, true)
					if sprite is Sprite2D:
						sprite.scale=was_scale
					else:
						sprite.scale=was_scale
					await baker.finished
					#pixel_map.update_material_mask(sprite.global_position+sprite.global_scale*0.5,baker.texture.get_data(),sprite.material_type,1.0,sprite.mask)
					
					if sprite is Sprite2D:
						pixel_map.update_material_mask_rotated(sprite.global_position+target_size*0.5,baker.texture.get_data(),sprite.material_type,Vector3(1.0,1.0,0.0),sprite.mask,sprite.blue_channel)
					else:
						pixel_map.update_material_mask_rotated(sprite.global_position+target_size*0.5,baker.texture.get_data(),sprite.material_type,Vector3(1.0,1.0,0.0),sprite.mask,sprite.blue_channel)

	emit_signal("pass_finished")
	
	



func get_distance_from_reactor_normalized(from):
	var pixel_map: PixelMap = $"%NotPixelMap"
	var map_size = max(scale.x,scale.y)
	var reactor_pos=$"%caves_gen".get_reactor_position()
	return clamp(from.distance_to(reactor_pos)/map_size,0.0,1.0) 



func get_distance_from_reactor_normalized_better(from):
	var pixel_map: PixelMap = $"%NotPixelMap"
	var map_size = max(scale.x,scale.y)
	var reactor_pos=$"%caves_gen".get_reactor_position()
	var max_distance= Vector2()
	max_distance.x=max(map_size-reactor_pos.x,reactor_pos.x)
	max_distance.y=max(map_size-reactor_pos.y,reactor_pos.y)
	return clamp(from.distance_to(reactor_pos)/max(max_distance.x,max_distance.y),0.0,1.0) 



func get_distance_from_reactor_normalized_4k(from):
	var norm=get_distance_from_reactor_normalized_better(from)*(max(scale.x,scale.y)/4096.0)
	return norm 



func get_distance_from_reactor(from):
	var pixel_map: PixelMap = $"%NotPixelMap"
	var reactor_pos=$"%caves_gen".get_reactor_position()
	return clamp(from.distance_to(reactor_pos),0.0,8192.0) 

func spawn_swarm_in_position(pos,swarm_name,radius=5,count=1):
	create_object("Enemy Swarm", swarm_name, pos, {count = count})

		
func create_objects_impl(dupa):
	if not dupa:
		return
	for node in $"%Objects".get_children():
		node.free()
	object_stash.clear()
	
	var pixel_map: PixelMap = $"%NotPixelMap"
	var map_size = scale.x
	

	current_object_rect = null
	var lumen_clumps_count=scale.x*scale.y/(4096*4096)*100
	var metal_clumps_count=scale.x*scale.y/(4096*4096)*100
	var num_clumps=0
	for i in lumen_clumps_count:
		for j in 10:
			var point=Vector2(randf_range(0,scale.x),randf_range(0,scale.y))
			if pixel_map.isCircleSolid(point, 5, ~(1<<Const.Materials.ROCK)):
				num_clumps+=1
				create_object("Object", "Pickup", point, {id = Const.ItemIDs.LUMEN_CLUMP, amount = 1})
				break
	for i in metal_clumps_count:
		for j in 10:
			var point=Vector2(randf_range(0,scale.x),randf_range(0,scale.y))
			if pixel_map.isCircleSolid(point, 5, ~(1<<Const.Materials.ROCK)):
				num_clumps+=1
				create_object("Object", "Pickup", point, {id = Const.ItemIDs.METAL_NUGGET, amount = 1})
				break
	
	print("number_of clumps placed ",num_clumps)
	
	
	
	
	
	
	
	
	var waves_gen = CustomizableWavesGenerator.new()
	waves_gen.set_emergency_swarm("Strong Spider Swarm")
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Spider Swarm", 1, 4)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Strong Spider Swarm", 4, 8)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Slow Swarm", 5, 8)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Flying Swarm", 6, 8)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Shooting Swarm", 6, 10)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Flying Shooting Swarm", 8, 10)
	waves_gen.add_new_enemy_type_with_custom_threat_to_waves_enemies_generator("Arthoma", 2, 8, 60)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Suicidoma", 4, 9)
	waves_gen.add_new_enemy_type_to_waves_enemies_generator("Suicacidoma", 6, 9)
	waves_gen.add_new_enemy_type_with_custom_threat_to_waves_enemies_generator("Acidoma", 8, 10, 80)
	waves_gen.add_new_enemy_type_with_custom_threat_to_waves_enemies_generator("Gobbler", 8, 10, 100)

	var paths=$"%caves_gen".get_paths()
	var iter=0
	for i in paths:
		iter+=1
		if i.size()<2:
			continue
		var avg_path_pos=(i[0]+i[i.size()-1])*0.5
		var better_normalized_distance_from_reactor = get_distance_from_reactor_normalized_4k(avg_path_pos)
		var distance_from_reactor = get_distance_from_reactor(avg_path_pos)
		var group_power=10.0+distance_from_reactor/32.0
		var group = waves_gen.generate_enemy_group_based_on_wave(my_seed+iter, min(better_normalized_distance_from_reactor, 1.0)*9+1, group_power*owner.enemy_multiplier)

		for enemy_string in group:
			if enemy_string.name.begins_with("Swarm"):
				var pos=i[randi()%i.size()]
				if get_distance_from_reactor(pos)>350:
					spawn_swarm_in_position(pos,enemy_string.name.get_slice("/",1),20,enemy_string.count)
			else:
				for count in enemy_string.count:
					var pos=i[randi()%i.size()]
					if get_distance_from_reactor(pos)>350:
						create_object("Enemy", enemy_string.name, pos)
#		for pos in i:
#			if randi()%5==0 and get_distance_from_reactor(pos)>350:
#				spawn_swarm_in_position(pos,"Spider Swarm",20,10*get_distance_from_reactor_normalized(pos))


	for rect in $"%generated_rects".get_children():
		rect.place_objects = true

	
	
	var density=4
	var empty_regions: Array = pixel_map.getEmptyRegions(11)
	empty_regions.sort_custom(Callable(self, "sort_rects"))
	for region in empty_regions:
		for one in ((region.size.x/(density))-1):
			if randi()%100==0:
				var ran_pos_in_rect=region.position+Vector2(randf()*region.size.x,randf()*region.size.y)
				var ray=pixel_map.rayCastQT(ran_pos_in_rect,Vector2.ONE.rotated(TAU*randf()))
				if ray:
					create_object("Object", "Lumen Mushroom",ray.hit_position.lerp(ran_pos_in_rect,randf()*0.2), {scale = randf_range(0.1, 0.5)})

	
	
	var hole_traps_power=20.0;
	var holes_count=0
	
	
	var number_of_holes=scale.x*scale.y/(4096*4096)*200


	for i in number_of_holes:
		for j in 10:
			var point=Vector2(randf_range(0,scale.x),randf_range(0,scale.y))
			if get_distance_from_reactor(point)<350:
				continue
			if pixel_map.isCircleEmpty(point, 10, (1<<Const.Materials.ROCK)):

				var dict= {
				enemy = "Swarm/Fast Spider Swarm", 
				enemy_count = 1+int(hole_traps_power*randf_range(0.5,1.0)*get_distance_from_reactor_normalized_4k(point)) ,
				max_enemies_at_once = 60,
				spawn_batch = 5,
				spawn_interval = 1.0}
				holes_count+=1
				create_object("Object", "Hole Trap",point,dict )
				break
	print("number of holes placed ",holes_count)

	
	
	
	
	
	
	
#	density=4
#	empty_regions = pixel_map.getEmptyRegions(11)
#	empty_regions.sort_custom(self, "sort_rects")
#	for region in empty_regions:
#		for one in ((region.size.x/(density))-1):
#			if randi()%300==0:
#				var ran_pos_in_rect=region.position+Vector2(randf()*region.size.x,randf()*region.size.y)
#				var ray=pixel_map.rayCastQT(ran_pos_in_rect,Vector2.ONE.rotated(TAU*randf()))
#				if ray:
#					var pos=ray.hit_position.linear_interpolate(ran_pos_in_rect,randf()*1.0)
#					if get_distance_from_reactor(pos)<350:
#						continue
#
#					var dict= {
#					enemy = "Swarm/Fast Spider Swarm", 
#					enemy_count = 1+int(hole_traps_power*rand_range(0.5,1.0)*get_distance_from_reactor_normalized(pos)) ,
#					max_enemies_at_once = 6,
#					spawn_batch = 3,
#					spawn_interval = 1.0}
#					holes_count+=1
#					create_object("Object", "Hole Trap",pos,dict )

	
	assert(required_items.is_empty() or not item_containers.is_empty(), "NIEEEE")
	
	for item in required_items:
		## TODO: rozdzielać jak amount > 1?
		
		sort_position = item.position
		
		var possible_containers := item_containers.duplicate()
		for exception in item.exceptions:
			possible_containers.erase(exception)
		
		assert(not possible_containers.is_empty(), "NIEE")
		
		possible_containers.sort_custom(Callable(self, "sort_by_distance"))
		var close_containers: Array
		
		for container in possible_containers:
			if container.position.distance_squared_to(item.position) < 160000:
				close_containers.append(container)
			else:
				break
		
		var container: Dictionary
		if close_containers.is_empty():
			container = possible_containers.front()
		else:
			container = close_containers[randi() % close_containers.size()]
		container.data.items.append(item.item)
	
var sort_position: Vector2

func sort_by_distance(item1, item2) -> bool:
	return sort_position.distance_squared_to(item1.position) < sort_position.distance_squared_to(item2.position)

func sort_by_distance_of_center(item1: Rect2, item2: Rect2) -> bool:
	return sort_position.distance_squared_to(item1.get_center()) < sort_position.distance_squared_to(item2.get_center())

func _ready():
	set_notify_transform(true)

func refresh_scale():
	if not has_node(@"%SubViewport"):
		return
	
	$"%SubViewport".size=scale
	$"%map".global_scale=Vector2.ONE
	for i in get_children():
		if i.has_method("map_size_changed"):
			i.map_size_changed(scale)
	
func _notification(what):
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		refresh_scale()



func create_object(type: String, object: String, pos: Vector2, data := {}, rot := 0.0) -> Dictionary:
	var obj := EditorObject.new()
	obj.set_script(preload("res://Nodes/Editor/EditorItem.gd").get_object_script(type.replace(" ", ""), object))
	
	obj.object_type = type
	obj.object_name = object
	obj.init_data(data)
	
	obj.position = pos
	obj.rotation = rot
	obj.queue_free()
	
	var dict := obj.get_dict()
	if map_file:
		map_file.objects.append(dict)
	else:
		# Jest deferred, czyli możesz sobie zmieniać dict.
		#call_deferred("instance_object", dict)
		object_stash.append(dict.duplicate(true))
		instance_object(dict)
	
	if type == "Enemy" or object == "Chest" or object == "Rusty Chest":
		item_containers.append(dict)
	
	return dict

func instance_object(dict: Dictionary):
	EditorObject.instantiate(dict, self, {})

func add_editor_object(object: Node2D):
	if object == null:
		return
	
	if current_object_rect:
		current_object_rect.add_child(object)
		object.position -= current_object_rect.position
	else:
		$"%Objects".add_child(object)
	object.owner = owner

func add_required_items(items: Array, where: Vector2, container_exceptions := []):
	for item in items:
		item = item.duplicate()
		item.id = Const.ItemIDs.keys()[item.id]
		required_items.append({item = item, position = where, exceptions = container_exceptions})

func save_lcmap_impl(co):
	if not co:
		return
	
	var _map_file = MapFile.new()
	
	var biome = load("res://Nodes/Map/Generator/Biomes/Cave.tres")
#	biome = load("res://Nodes/Map/Generator/Biomes/Desert.tres")
	
	_map_file.map_name = "Godot created this"
	_map_file.terrain_config = Const.game_data.DEFAULT_TERRAIN_CONFIG.duplicate()
	_map_file.terrain_config.lower_floor = biome.lower_floor_textures
	_map_file.terrain_config.upper_floor = biome.upper_floor_textures
	_map_file.terrain_config.terrain[4] = biome.soft_wall_material
	_map_file.terrain_config.terrain[5] = biome.hard_wall_material
	_map_file.terrain_config.alt_floor = true
	_map_file.start_config = {inventory = [], technology = {}}
	_map_file.darkness_color = Color(0.3,0.1,0.7)
	_map_file.start_config.stats = {clones=3}
	_map_file.enable_fog = true
	_map_file.objects = object_stash
	
	# objects
	
	for i in $"%swarm_batchs".get_children():
		_map_file.objects.append({type = "Custom", name = "Swarm Scene", scene = i.filename, data = i.getUnitsStateBinaryData()})
	
	var terrain := Image.new()
	terrain.create_from_data(scale.x, scale.y, false, Image.FORMAT_RGBA8, $"%NotPixelMap".get_pixel_data())
	_map_file.pixel_data = terrain
	
	# floor
	
	
	var baker = preload("res://Scripts/TextureBaker.gd").create(Vector2(1024, 1024))
	baker.add_target(preload("res://Nodes/Map/Generator/Floor1_generator.tscn").instantiate())
	
	await baker.finished
	
	_map_file.floor_data = baker.texture.get_data()
	
	baker = preload("res://Scripts/TextureBaker.gd").create(Vector2(1024, 1024))
	baker.add_target(preload("res://Nodes/Map/Generator/Floor2_generator.tscn").instantiate())
	
	await baker.finished
	
	_map_file.floor_data2 = baker.texture.get_data()
	
	#CLEAR ALPHA FOR BLOOD
	
	_map_file.floor_data2.convert(Image.FORMAT_RGBA8)
	
	var image_data=_map_file.floor_data2.get_data()
	var i =3
	while i< image_data.size():
		image_data[i]=0
		i+=4
	
	_map_file.floor_data2.create_from_data(_map_file.floor_data2.get_width(),_map_file.floor_data2.get_height(),false,Image.FORMAT_RGBA8,image_data)
	
	var map_name = "ExportedMap-%s.lcmap" % Time.get_unix_time_from_system()
	_map_file.save_to_file("user://Maps/" + map_name)
	print("Mapa %s zapisana" % map_name)
