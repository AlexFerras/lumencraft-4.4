extends Node

@export var win_message: String

@export var objective_queue: Dictionary
@export var timeouts: Dictionary
var queue_dirty: bool

func _ready() -> void:
	if not objective_queue.is_empty():
		refresh_queue()
	set_process(not timeouts.is_empty())

func add_objective(text: String, priority: int):
	assert(not priority in objective_queue, "Dany priorytet już istnieje.")
	objective_queue[priority] = text
	refresh_queue()

func add_top_objective(text: String) -> int:
	var idx: int
	if objective_queue.is_empty():
		idx = 0
	else:
		var priorities := objective_queue.keys()
		priorities.sort()
		idx = priorities.back() + 1
	
	objective_queue[idx] = text
	refresh_queue()
	return idx

func add_top_objective_with_timeout(text: String, timeout: float):
	var idx := add_top_objective(text)
	timeouts[idx] = timeout
	set_process(true)

func remove_objective(text: String):
	for id in objective_queue:
		if text == objective_queue[id]:
			objective_queue.erase(id)
			refresh_queue()
			return
	assert(false, "Dany cel nie istnieje.")

func remove_objective_id(id: int):
	objective_queue.erase(id)
	refresh_queue()

func refresh_queue():
	queue_dirty = true
	call_deferred("_refresh_queue")

func _refresh_queue():
	if not queue_dirty:
		return
	queue_dirty = false
	
	if objective_queue.is_empty():
		if win_message.is_empty():
			Utils.game.win()
		else:
			Utils.game.win(win_message)
		return
	
	var priorities := objective_queue.keys()
	priorities.sort()
	
	var current_text: String = objective_queue[priorities.back()]
	if Utils.game.ui.objective_text != current_text:
		Utils.game.ui.set_objective(0, current_text, true)

func _process(delta: float) -> void:
	var finished := true
	for idx in timeouts.keys():
		timeouts[idx] -= delta
		if timeouts[idx] <= 0:
			timeouts.erase(idx)
			remove_objective_id(idx)
		else:
			finished = false
	
	if finished:
		set_process(false)
