extends Node2D

@onready var cursor := $Cursor
var center := Vector2(100,100)
func _ready():
#	InputMap.action_set_deadzone("p1_left", 0.05)
#	InputMap.action_set_deadzone("p1_right", 0.05)
#	InputMap.action_set_deadzone("p1_up", 0.05)
#	InputMap.action_set_deadzone("p1_down", 0.05)
#
#	InputMap.action_set_deadzone("p1_look_left", 0.05)
#	InputMap.action_set_deadzone("p1_look_right", 0.05)
#	InputMap.action_set_deadzone("p1_look_up", 0.05)
#	InputMap.action_set_deadzone("p1_look_down", 0.05)
	pass

func _process(delta):
#	cursor.position = center + Input.get_vector("p1_left", "p1_right", "p1_up", "p1_down" ) * Vector2(100,100)
	cursor.position = center + Input.get_vector("p1_look_left", "p1_look_right", "p1_look_up", "p1_look_down" ) * Vector2(100,100)

func _draw():
	var rect = Rect2(Vector2.ZERO,Vector2(201,201))
#	draw_rect( rect, Color(0.0,0.0,0.0,0.4) )
#	draw_rect( rect, Color(1.0,1.0,1.0,1.0), false )
	draw_circle( Vector2(100,100), 100, Color(0.0,0.0,0.0,0.4) )
	draw_arc(Vector2(100,100),100, 0, TAU, 360, Color(1.0,1.0,1.0,1.0) )
	draw_line(Vector2(90,100), Vector2(111,100), Color(1.0,1.0,1.0,0.5))
	draw_line(Vector2(100,90), Vector2(100,111), Color(1.0,1.0,1.0,0.5))
