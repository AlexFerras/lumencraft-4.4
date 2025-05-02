extends Node

var fscreen : bool = false

func _ready():
#	Save.config.screenmode = Save.config.FULLSCREEN
#	Save.config.screenmode = Save.config.WINDOWED
#	Save.config.apply()
	var screen_size = DisplayServer.screen_get_size(0)
	var window_size = get_window().get_size()
	get_window().set_position(screen_size*0.5 - window_size*0.5)
	
func _process(delta):
	if Input.is_action_just_pressed("anarchy"):
		print("anarchy")
		if fscreen:
			Save.config.screenmode = Save.config.WINDOWED
			Save.config.apply()
			fscreen = !fscreen
			return
		if !fscreen:
			Save.config.screenmode = Save.config.FULLSCREEN
			Save.config.apply()
			fscreen = !fscreen
			return
