extends Node2D

@export var repair_radius=1
@export var max_repair_radius=16.0
@onready var repair_point=$reapair_point
@onready var particles=$GPUParticles2D
@onready var repair_area=$"reapair_point/Area2D"
@onready var repair_sound=$"repair_sound"
var player: Player
var repair_cost=0.0
var repair_cost_mul=1.0

var revive_lumen: bool 
var lava_cooling: bool =false
var last_carring= null

func set_player(p: Player):
	player = p

func _ready() -> void:
	Utils.set_collisions(repair_area, repair_area.collision_mask | Const.BUILDING_COLLISION_LAYER, Utils.ACTIVE)
	repair_point.set_as_top_level(true)
#	repair_point.global_position=global_position
	repair_point.global_position=global_position+(Vector2.RIGHT.rotated(player.get_shoot_rotation())).normalized()*16
	repair_sound.play(randf_range(0,5))
	repair_cost=player.get_current_item().get("repair_cost",0.0)
	Utils.subscribe_tech(self, "dead_lumen_convert")
	Utils.subscribe_tech(self, "repair_tool_efficiency")
	Utils.subscribe_tech(self, "lava_cooling")

func _tech_unlocked(tech: String):
	if tech == "dead_lumen_convert":
		revive_lumen = true
	if  tech == "repair_tool_efficiency":
		repair_cost_mul = 0.5
	if  tech == "lava_cooling":
		lava_cooling = true

func put_away():
	particles.emitting=false
	repair_sound.volume_db=linear_to_db(0.0)
	repair_radius=1.0


func _physics_process(delta):

	var actual_angle=(repair_point.global_position-global_position).angle()
	var new_angle=lerp_angle(actual_angle,player.get_shoot_rotation(),0.1)
	#repair_point.global_position=global_position+(Vector2.RIGHT.rotated(new_angle)).normalized()*20
	#repair_point.global_position=repair_point.global_position*0.9+0.1*(global_position+(Vector2.RIGHT.rotated(player.get_shoot_rotation())).normalized()*16)
	repair_point.global_position=global_position+(Vector2.RIGHT.rotated(new_angle)).normalized()*16
	
	if player.is_shooting() and not player.build_menu:
		var desired_point=global_position+(Vector2.RIGHT.rotated(new_angle)).normalized()*26
		Utils.game.map.pickables.add_attraction_velocity_to_pickables(desired_point, 15, 10, -1)
		var ran=5.0
		var repulsionpoint=desired_point+Vector2(randf_range(-ran,ran),randf_range(-ran,ran))
		Utils.game.map.pickables.add_repulsion_velocity_to_pickables(repulsionpoint, 1, 27, -1)
	
		Utils.game.map.pixel_map.particle_manager.explosion_happened(desired_point, max_repair_radius, 400)
		Utils.game.map.pixel_map.flesh_manager.explosion_happened(desired_point, max_repair_radius, 400)
		
		
		
		var item_to_carry=null
		var col = Utils.game.map.pixel_map.rayCastQTFromTo(global_position, repair_area.global_position, Utils.walkable_collision_mask)
		if !col :

			for i in repair_area.get_overlapping_bodies():
				if i.is_in_group("repair_kit_pickable"):
					if i is Pickup:
						if i.buried:
							continue
					if i is PixelMapRigidBody:
						col = Utils.game.map.pixel_map.rayCastQTFromTo(repair_area.global_position, i.global_position, Utils.walkable_collision_mask)
						if col :
							continue
						item_to_carry=i
						if last_carring!=null:
							if item_to_carry==last_carring:
								item_to_carry=last_carring
								break
			
		if item_to_carry:
			last_carring=item_to_carry
			col = Utils.game.map.pixel_map.rayCastQTFromTo(global_position, desired_point, Utils.walkable_collision_mask)
			if col :
				desired_point = global_position+(desired_point-global_position).normalized() *(col.hit_distance-item_to_carry.radius)

			item_to_carry.global_position=item_to_carry.global_position.lerp(desired_point,0.2)
			#item_to_carry.linear_velocity=(desired_point-item_to_carry.global_position)*10.5

		
		
		
		
		repair_radius= min(max_repair_radius,repair_radius+0.5)
		particles.emitting=true
		repair_sound.volume_db=linear_to_db(clamp(db_to_linear(repair_sound.volume_db)+0.2,0,3.0))
		# RECHECK
		(particles.process_material as ParticleProcessMaterial).initial_velocity.x=125+2.0*player.linear_velocity.dot(Vector2.RIGHT.rotated(player.get_shoot_rotation()))

		for building in get_tree().get_nodes_in_group("repair_my_pixels"):
			repair_cost+=building.repair_pixels(repair_point.global_position,repair_radius)*0.002*repair_cost_mul

		for i in repair_area.get_overlapping_areas():
			if i is BaseBuilding:
				if i.hp<i.max_hp:
					i.repair(1)
					repair_cost+=0.1*repair_cost_mul
					
		var healed=Utils.game.map.pixel_map.update_heal_circle(repair_point.global_position, repair_radius, 10, 5)
		repair_cost+=healed*0.00001*repair_cost_mul
		
		if revive_lumen:
			var transformed := Utils.game.map.pixel_map.update_material_circle(repair_point.global_position, repair_radius, Const.Materials.LUMEN, 1 << Const.Materials.DEAD_LUMEN, true)
			repair_cost += transformed * 0.001*repair_cost_mul
			
			
		if lava_cooling:	
			var transformed := Utils.game.map.pixel_map.update_material_circle(repair_point.global_position, repair_radius, Const.Materials.ASHES, 1 << Const.Materials.LAVA, true)
			repair_cost += transformed * 0.001*repair_cost_mul
		#Utils.game.map.pixel_map.update_damage_circle(repair_point.global_position*0.99+global_position*0.01, repair_radius, 3000, 4, 255, 1 << Const.Materials.LAVA)
		
		var kits_available=player.get_item_count(Const.ItemIDs.REPAIR_KIT)
		player.subtract_item(Const.ItemIDs.REPAIR_KIT, min(int(repair_cost), kits_available), null, true)

		if kits_available<repair_cost:
			queue_free()
		repair_cost-=int(repair_cost)
		
	else:
		repair_radius=1.0
		#repair_point.global_position=global_position+(Vector2.RIGHT.rotated(new_angle)).normalized()*16
		repair_sound.volume_db=linear_to_db(clamp(db_to_linear(repair_sound.volume_db)-0.2,0,3.0))
		particles.emitting=false
		last_carring=null


func _exit_tree() -> void:
	particles.emitting=false
	var trans=global_transform
	remove_child(particles)
	Utils.game.map.add_child(particles)
	particles.global_transform=trans
	get_tree().create_timer(2).connect("timeout", Callable(particles, "queue_free"))
	
