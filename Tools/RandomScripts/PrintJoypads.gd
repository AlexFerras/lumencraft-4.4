@tool
extends EditorScript

func _run():
	for i in Input.get_connected_joypads():
		prints("Joypad %s" % i, Input.get_joy_name(i))
