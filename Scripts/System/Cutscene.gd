extends RefCounted
class_name Cutscene

var sequence: Array
var soft: bool

signal finished

func _init(s := false) -> void:
	soft = s
	Utils.game.cutscene = self
	Utils.get_tree().connect("idle_frame", Callable(self, "start").bind(), CONNECT_ONE_SHOT)
	
	if not soft:
		Utils.game.ui.start_cutscene()

func append_message(text: String, from, auto := false):
	sequence.append({type = "message", text = text, from = from, auto = auto})

func append_tween() -> Tween:
	var seq: Tween = Utils.create_tween()
	seq.stop()
	sequence.append({type = "tween", tween = seq})
	return seq

func start():
	next_step()

func next_step():
	if sequence.is_empty():
		Utils.game.cutscene = null
		if not soft:
			Utils.game.ui.finish_cutscene()
		emit_signal("finished")
		return
	
	var step: Dictionary = sequence.pop_front()
	match step.type:
		"message":
			show_message(step.text, step.from, step.auto).connect("tree_exited", Callable(self, "next_step").bind(), CONNECT_DEFERRED)
		"tween":
			step.tween.connect("finished", Callable(self, "next_step"))
			step.tween.start()

static func show_message(text: String, from, autoclose := false) -> Node2D:
	var message_box: Node2D = preload("res://Nodes/UI/Dialogue/DialogueBox.tscn").instantiate()
	message_box.set_text(text)
	Utils.game.ui.add_child(message_box)
	
	if from is Node2D:
		message_box.move_to(from)
	
	if autoclose:
		Utils.get_tree().create_timer(5).connect("timeout", Callable(message_box, "queue_free"))
	
	return message_box
