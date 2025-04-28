extends Node

var time = 0.0
var daelay = 0.0
var dlamov = 0.0

func handle_resigs():
	time = 0.5
	set_physics_process(true)

func handle_movix():
	dlamov = 0.5
	set_physics_process(true)

func handle_maxing():
	daelay = 1.0
	set_physics_process(true)
	
func _physics_process(delta):
	if time>0:
		time -= delta
		if time <= 0:
			Save.config.apply_window_resize()
			
	if daelay > 0:
		daelay -= delta
		if daelay <= 0:
			Save.config.apply_window_maximize()
			
	if dlamov > 0:
		dlamov -= delta
		if dlamov <= 0:
			Save.config.apply_window_move()
	if dlamov<= 0 and daelay<=0 and time<=0:
		Save.config.backup_config()
		set_physics_process(false)
