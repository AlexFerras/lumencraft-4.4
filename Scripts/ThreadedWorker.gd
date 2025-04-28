extends Node

var target: Object
var method: String
var data

var thread: Thread

static func create(for_target: Object, for_method: String, for_data = null) -> Node:
	var worker: Node = load("res://Scripts/ThreadedWorker.gd").new()
	worker.target = for_target
	worker.method = for_method
	worker.data = for_data
	worker.process_mode = Node.PROCESS_MODE_ALWAYS
	Save.add_child(worker)
	return worker

func _ready() -> void:
	thread = Thread.new()
	thread.start(Callable(target, method).bind(data))

func _process(delta: float) -> void:
	if not thread.is_alive():
		thread.wait_to_finish()
		thread = null
		queue_free()
