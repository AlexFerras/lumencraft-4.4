extends Node2D

const SPREAD = 0.0
const MAX_TIME = 2.0

var texture :=preload("res://Resources/Terrain/puffs.png") 
var ball_size=9.0
var timer: float
var stop: bool
var shoot_point
var player: Player
var foams: Array

func _ready() -> void:
	set_physics_process(false)
	set_process(false)

var count=0
func _physics_process(delta: float) -> void:

	if not stop:
		var foam := FoamBall.new()
		foam.position = shoot_point
		foam.draw_position = foam.position
		foam.direction = Vector2.RIGHT.rotated(player.get_shoot_rotation() + randf_range(-SPREAD, SPREAD))
		foam.initial_velocity= player.linear_velocity
		foam.rotation = randf_range(0.2,1.0)
		foam.randx=randi()%8
		foam.randy=randi()%8
		foams.append(foam)
	if foams.is_empty():
		if stop:
			set_physics_process(false)
			set_process(false)
	else:
		var foams_to_delete: Array
		
		for foam in foams:
			if not foam.move(delta):
				foams_to_delete.append(foam)

		for foam in foams_to_delete:
			if foam.lifetime<MAX_TIME:
				var ray := Utils.game.map.pixel_map.rayCastQTFromTo(foam.position+foam.direction*10.0, foam.position)
				if ray:
					foam.position = (foam.position+ray.hit_position)*0.5
				Utils.game.map.pixel_map.update_material_spiral(foam.position, 50,Const.Materials.FOAM2 if Save.is_tech_unlocked("fireproof_foam") else Const.Materials.FOAM, 4, 1<<Const.Materials.EMPTY | 1<<Const.Materials.TAR)
				if count%2==0:
					Utils.get_audio_manager("slime").play(foam.position)
				#	Utils.play_sample(Utils.random_sound("res://SFX/Misc/slime")).volume_db=-5.0
				count+=1
			foams.erase(foam)

func _process(delta: float) -> void:
	for foam in foams:
		foam.draw_position = lerp(foam.draw_position, foam.position, 0.1)
	queue_redraw()

func _draw() -> void:
	for foam in foams:
		draw_set_transform(foam.position,foam.rotation,foam.rotation*Vector2.ONE)
		draw_texture_rect_region(texture, Rect2(-Vector2(ball_size,ball_size)*0.5,Vector2(ball_size,ball_size)),Rect2(Vector2(128*foam.randx,128*foam.randy),Vector2(128,128)))

class FoamBall:
	const SPEED = 100
	var initial_velocity=Vector2.ZERO
	var position: Vector2
	var draw_position: Vector2
	var direction: Vector2
	var rotation: float
	var lifetime: float
	var randx=0
	var randy=0
	
	func move(delta: float) -> bool:
		var next_pos=position+(direction * SPEED + initial_velocity) * delta;
		
		var params = PhysicsPointQueryParameters2D.new()
		params.position = next_pos
		params.collision_mask = Const.ENEMY_COLLISION_LAYER
		params.collide_with_areas = true
		params.collide_with_bodies = true
		if Utils.get_physics_world2d().intersect_point(params, 1):
			return false

	
		var ray := Utils.game.map.pixel_map.rayCastQTFromTo(position, next_pos, Utils.player_bullet_collision_mask)
		if ray:
			position = ray.hit_position
			return false
		
		position = next_pos
		lifetime += delta
		return lifetime < MAX_TIME
