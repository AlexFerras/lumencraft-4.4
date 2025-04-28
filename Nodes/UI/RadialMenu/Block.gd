extends Node2D

@export var selected_color := Color( 0.988235, 0.490196, 0.0901961, 1.0 )
@export var unselected_color := Color( 0.25098, 0.121569, 0.0196078, 0.5 )
@export var disabled_color := Color( 0.25098, 0.0196078, 0.0196078, 0.501961 )

var target_color :Color = unselected_color
var disabled := false

@onready var sprite: Sprite2D = get_node_or_null("Block1")
@onready var frame: Sprite2D = get_node_or_null("Block1/BlockFrame")

func _process(delta):
	var colored := sprite as Node2D if sprite else self
	colored.self_modulate = colored.self_modulate.lerp(target_color, 0.1)
	if colored.self_modulate.is_equal_approx(target_color):
		set_process(false)

func select()->void:
	if disabled:
		target_color = selected_color.lerp(disabled_color, 0.7)
	else:
		target_color = selected_color
	set_process(true)
	
	if frame:
		frame.show()
	
func deselect()->void:
	if disabled:
		target_color = disabled_color
	else:
		target_color = unselected_color
	set_process(true)
	
	if frame:
		frame.hide()

func unhide()->void:
	visible = true
	set_process(true)
	
func unshow()->void:
	visible = false
	set_process(false)
