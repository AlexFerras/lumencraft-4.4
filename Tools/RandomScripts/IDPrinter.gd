@tool
extends EditorScript

func _run():
	for i in Constants.ItemIDs.size():
		print(i, ": ", Constants.ItemIDs.keys()[i])
