extends Node

var target: Object
var another: Object
var data

signal kill

func _init() -> void:
	name = "ObjectKiller"

func _ready() -> void:
	add_to_group("dont_save")

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		emit_signal("kill")
		if not is_instance_valid(target):
			return
		
		if target is Nodes2DTrackerMultiLvl:
			Utils.remove_from_tracker(another, false)
		elif target.has_method("kill_callback"):
			target.kill_callback(data)
		elif target is Node:
			target.queue_free()
