extends Node2D

var data:=PackedInt32Array([0])
var data_size = 300
var rect = Rect2(Vector2(600,20), Vector2(data_size*2,200))
var idx = 0
var msec_time = 0
var msec_prev_time = 0

@onready var frame = $"../FrameTimePlotRect"

func _ready():
	
	if Music.is_game_build():
		frame.queue_free()
		queue_free()
		return
	
	data.resize(data_size)
	for i in data_size:
		data[i] = 0
	
func _process(delta):
	if get_tree().paused:
		msec_prev_time = OS.get_system_time_msecs()
		return
	msec_time = OS.get_system_time_msecs()  - msec_prev_time
	msec_prev_time = OS.get_system_time_msecs()
	
	rect.position = frame.position
	data[idx] = msec_time
	idx += 1
	idx%=data_size

func _physics_process(delta):
	update()

func _draw():
	if Music.is_game_build():
		return
	draw_rect(rect, Color(0,0,0,0.1), true, 1)
	draw_line(rect.position + Vector2(0,rect.size.y*0.25), rect.position + Vector2(rect.size.x,rect.size.y*0.25), Color(1,1,1,0.2))
	draw_line(rect.position + Vector2(0,rect.size.y*0.50), rect.position + Vector2(rect.size.x,rect.size.y*0.50), Color(1,1,1,0.2))
	draw_line(rect.position + Vector2(0,rect.size.y*0.75), rect.position + Vector2(rect.size.x,rect.size.y*0.75), Color(1,1,1,0.2))
#	draw_line(rect.position + Vector2(0,80), rect.position + Vector2(rect.size.x, 80), Color(1,1,1,0.2))
	draw_rect(rect, Color(1,1,1,0.4), false, 1)
	var avg = 0.0
	var data_max = 0.0
	for i in range(idx,data_size):
		avg+=data[i]
		if data_max < data[i]:
			data_max= data[i]
		
		draw_rect(Rect2(rect.position+Vector2((i-idx)*2.0,rect.size.y-min(data[i]*4,200)),Vector2.ONE*2.0*clamp(float(data[i])/17.0,0.3,6)), Color.from_hsv(min(data[i], 17.0)/17.0,1,1,1))
#		draw_circle(rect.position+Vector2(i-idx,rect.size.y-min(data[i]*2,100)), clamp(float(data[i])/17.0,0.1,3), Color.from_hsv(min(data[i], 17.0)/17.0,1,1,1))
	for i in idx:
		avg+=data[i]
		if data_max < data[i]:
			data_max= data[i]
		draw_rect(Rect2(rect.position + Vector2((data_size-idx+i)*2.0, rect.size.y-min(data[i]*4,200)), Vector2.ONE*2.0*clamp(float(data[i])/17.0,0.3,6)), Color.from_hsv(min(data[i], 17.0)/17.0,1,1,1))
#		draw_circle(rect.position+Vector2(data_size-idx+i,rect.size.y-min(data[i]*2,100)), clamp(float(data[i])/17.0,0.1,3), Color.from_hsv(min(data[i], 17.0)/17.0,1,1,1))
	
	avg /= data_size
	draw_string(preload("res://Resources/Fonts/Font20.tres"), rect.position+rect.size +Vector2(10, 10-min(avg*4,200)), str(round(avg*100.0)/100.0,'ms'))
	if data_max > avg+5:
		draw_string(preload("res://Resources/Fonts/Font20.tres"), rect.position+rect.size +Vector2(10, 10-min(data_max*4,200)), str(round(data_max*100.0)/100.0,'ms'))
