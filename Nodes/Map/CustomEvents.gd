extends "res://Scripts/MapEvents.gd"

@export var events: Array
var special = preload("res://Nodes/Editor/SpecialObject.gd").new()

@export var is_start := true
@export var internal_variables: Dictionary

func _init() -> void:
	name = "MapEvents"
	Utils.event_listener = special

func _game_start():
	special.internal_variables = internal_variables
	if not is_start:
		call_deferred("start_event")

func start_event():
	_physics_process(0)
	is_start = false

func _physics_process(delta: float) -> void:
	var j: int
	for i in events.size():
		var event: Dictionary = events[j]
		var any: bool = event.any
		var condition_met := true
		
		for condition in event.conditions:
			if not is_condition_met(condition):
				condition_met = false
				
				if not any:
					break
			elif any:
				condition_met = true
				break
		
		if not condition_met:
			j += 1
			continue
		
		for action in event.actions:
			execute_action(action)
		
		if not event.get("repeatable", false):
			events.remove(j)
	
	special.clear_events()

func is_condition_met(condition: Dictionary) -> bool:
	var object
	if condition.id == -1:
		object = special
	else:
		object = map.get_event_object(condition.id)
	
	match condition.type:
		"destroyed", "collected":
			if not object or not object.has_method("is_condition_met"):
				return object == null
		"killed", "triggered", "chest_opened":
			if not object:
				return true
		_:
			if not object:
				return false
	
	if object.has_meta("EV_" + condition.type):
		return true
	
	var data: Dictionary = condition.get("data", {}).duplicate()
	data.events = self
	
	return object.is_condition_met(condition.type, data)

func execute_action(action: Dictionary):
	var object
	if action.id == -1:
		object = special
	else:
		object = map.get_event_object(action.id)
	
	if not object:
		return
	
	match action.type:
		_:
			return object.execute_action(action.type, action.get("data", {}))

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		Utils.event_listener = null
