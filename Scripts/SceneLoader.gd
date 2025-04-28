extends RefCounted

var loader: ResourceLoader
var resource: Resource
var is_finished: bool

signal finished

func interactive_load(path):
	loader = ResourceLoader.load_threaded_request(path)

func progress():
	if not loader:
		return
	
	if loader.poll() == ERR_FILE_EOF:
		resource = loader.get_resource()
		is_finished = true
		loader = null
		emit_signal("finished")
