@tool
extends FlyingSwarm
var projectile_scene = preload("res://Nodes/Enemies/MegaSwarm/ShootingSwarm/ShootingSwarmProjectile.tscn")

@export var shot_range := 120.0
@export var shot_delay := 0.2
@onready var fov_angle = atan(4/shot_range)*8

func additional_setup():
	flying=1
	setUserMaterialDamageToUnits(Const.Materials.LAVA, 0.0, 0.0)
	setUserMaterialUsitsSpeedMultiplier(Const.Materials.LAVA, 1.0)

	setWalkAnimationMinSpeedFract(0.64)

	setEnemyMaxPursuitDistance(unit_radius + (80.0 if just_wander else 40.0))
	setEnemyBuildingMaxPursuitDistance(unit_radius + 12)
	setUserMaterialUsitsSpeedMultiplier(Const.Materials.WALL3, 0.5);
	setVisibilityThroughCollisionUserMaterialsMask(Utils.monster_sight_mask)

func setup_attacks():
	addNewAttack(shot_range, shot_delay, self, "shooting_attack", 192.0, false, true, true, 0.25, fov_angle)
	addNewAttack(attack_range, attack_delay, self, "terrain_attack", 192.0, true, true, true)

func shooting_attack(attack_id: int, position: Vector2, heading: Vector2, target: Node, attacker_unit_id: int, in_distance_from_focus_check: bool):
	if target:
		var projectile = projectile_scene.instantiate()
		projectile.global_position = position + heading * 5
		var predict_direction = heading
		if target in Utils.game.players:
			var len_to_target = (target.global_position - position).length()
			predict_direction = (len_to_target*predict_direction + (len_to_target/projectile.speed)*target.linear_velocity).normalized()
			if abs(heading.angle_to(predict_direction)) > fov_angle:
				if sign(heading.angle_to(predict_direction)) <= 0:
					predict_direction = heading.rotated(-fov_angle)
				else:
					predict_direction = heading.rotated(fov_angle)
		projectile.rotation = predict_direction.angle()
		projectile.direction = predict_direction
		Utils.game.map.add_child(projectile)
	else:
		var projectile = projectile_scene.instantiate()
		projectile.global_position = position
		projectile.rotation = heading.angle()
		projectile.direction = heading
		Utils.game.map.add_child(projectile)
