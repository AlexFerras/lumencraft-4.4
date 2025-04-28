extends Area2D

@export var size: Vector2

var entered_object: RigidBody2D

var players_inside: int
var enemies_inside: int
var objects_inside: Array

func _ready() -> void:
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.extents = size / 2
	add_child(shape)
	
	collision_mask |= Const.PLAYER_COLLISION_LAYER
	collision_mask |= Const.ENEMY_COLLISION_LAYER
	collision_mask |= Const.PICKUP_COLLISION_LAYER
	
	connect("area_entered", Callable(self, "on_area_enter"))
	connect("area_exited", Callable(self, "on_area_exit"))
	connect("body_entered", Callable(self, "on_body_enter"))
	connect("body_exited", Callable(self, "on_body_exit"))

func on_area_enter(area: Area2D):
	if Player.get_from_area(area):
		Utils.notify_object_event(self, "player_entered2")
		players_inside += 1
		return
	
	if area.has_meta("parent_enemy"):
		Utils.notify_object_event(self, "enemy_entered2")
		enemies_inside += 1
		return

func on_area_exit(area: Area2D):
	if Player.get_from_area(area):
		players_inside -= 1
		return
	
	if area.has_meta("parent_enemy"):
		enemies_inside -= 1
		return

func on_body_enter(body: PhysicsBody2D):
	if body is RigidBody2D and not body is Player:
		entered_object = body
		objects_inside.append(body)
		Utils.notify_object_event(self, "object_entered2")

func on_body_exit(body: PhysicsBody2D):
	if body is RigidBody2D and not body is Player:
		objects_inside.erase(body)

func is_condition_met(condition: String, data: Dictionary):
	if has_meta("EV_" + condition + "2"):
		if condition == "object_entered" and data.get("filter", "Any") != "Any":
			return is_instance_valid(entered_object) and entered_object.get_meta("object_type", "None") == data.filter
		return true
	
	match condition:
		"player_inside":
			return players_inside > 0
		"enemy_inside":
			return enemies_inside > 0
		"object_inside":
			if data.filter == "Any":
				return not objects_inside.is_empty()
			else:
				for object in objects_inside:
					if object.get_meta("object_type", "None") == data.filter:
						return true
	
	return false
