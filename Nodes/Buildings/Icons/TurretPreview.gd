extends "res://Nodes/Buildings/Icons/GenericPreview.gd"

@onready var attack_range = $attack_range_visual

@export var range_radius := 150.0

func set_as_preview():
	super.set_as_preview()
	set_meta("custom_canvas", true)
	
	attack_range.set_meta("range_expander_color", 2.0)
	attack_range.add_to_group("range_draw")
	attack_range.set_meta("custom_canvas", true)
	attack_range.set_meta("range_expander_radius", range_radius)
	attack_range.circle_radius=range_radius
	
func on_moved():
	attack_range.visible=true
	Utils.game.map.post_process.range_dirty = true

func on_placed():
	remove_meta("range_expander_radius")
	attack_range.visible=false
	Utils.game.map.post_process.range_dirty = true
