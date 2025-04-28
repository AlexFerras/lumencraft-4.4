extends Timer

var finished: bool
var saved_wait_time := -1.0

func _ready() -> void:
	connect("timeout", Callable(self, "on_finished"))

func on_finished():
	autostart = false
	if saved_wait_time > 0:
		wait_time = saved_wait_time
	Utils.notify_object_event(self, "finished")

func is_condition_met(condition: String, data: Dictionary) -> bool:
	return false

func execute_action(action: String, data: Dictionary):
	if action == "start":
		start()
	elif action == "stop":
		stop()

func _get_save_data() -> Dictionary:
	if is_stopped():
		return {}
	else:
		return {running = true, remaining = time_left, total_time = wait_time}

func _set_save_data(data: Dictionary):
	if data.get("running", false):
		saved_wait_time = data.total_time
		wait_time = data.remaining
		autostart = true
