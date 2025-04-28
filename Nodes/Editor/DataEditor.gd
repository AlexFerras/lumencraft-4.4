extends Control

var NULL_HASH = 0

var check_timer: float
var prev_hash: int = NULL_HASH

signal changed

func _ready() -> void:
	await self.ready
	NULL_HASH = hash(get_data())
	connect("changed", Callable(Utils.editor, "set_unsaved").bind(true))
	set_physics_process(is_visible_in_tree())

func set_data(data):
	prev_hash = hash(data)

func get_data():
	return null

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_physics_process(is_visible_in_tree())

func _physics_process(delta: float) -> void:
	check_timer += delta
	
	if check_timer >= 0.25:
		var new_hash := hash(get_data())
		if new_hash != prev_hash:
			emit_signal("changed")
			prev_hash = new_hash
