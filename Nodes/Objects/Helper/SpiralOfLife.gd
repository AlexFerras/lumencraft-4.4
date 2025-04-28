extends Node

var should_emit: bool
var timer: float

signal lazy_process

func _process(delta: float) -> void:
	timer += delta
	
	if should_emit:
		emit_signal("lazy_process")
		should_emit = false
		timer = 0

func _physics_process(delta: float) -> void:
	should_emit = true
