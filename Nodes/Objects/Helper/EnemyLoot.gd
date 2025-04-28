extends Node2D
@export var probability=1.0
@export var pickups: Array

func _enter_tree() -> void:
	set_meta("pickup_container", true)

func _ready() -> void:
	name = str("Loot", randi() % 10000)
	
	for child in get_children():
		if child is Pickup:
			pickups.append(child.get_data())
			child.queue_free()

func spawn_items():
	for pickup in pickups:
		if randf_range(0.0,1.0)<=probability:
			Pickup.launch(pickup, global_position, Vector2.RIGHT.rotated(randf() * TAU) * 100, true, false)
	pickups.clear()
