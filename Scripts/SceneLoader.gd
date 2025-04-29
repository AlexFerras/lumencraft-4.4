extends RefCounted

var resource: Resource
var is_finished: bool
var path:String


signal finished

func interactive_load(in_path):
	self.path = in_path
	ResourceLoader.load_threaded_request(path)
	

func progress():
	var status = ResourceLoader.load_threaded_get_status(path)
	
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		resource = ResourceLoader.load_threaded_get(path)
		is_finished = true
		emit_signal("finished")
