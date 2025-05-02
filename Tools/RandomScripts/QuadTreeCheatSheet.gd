@tool
extends EditorScript

func _run() -> void:
	for i in 14:
		prints("%2d" % i, "=", 1 << (13 - i))
