extends AudioStreamPlayer2D

var follow: Node2D

func _init(audio: AudioStream, source: Node2D, p_follow: bool):
	stream = audio
	attenuation = 2
	max_distance = 500
	bus = "SFX"
	autoplay = true
	
	if source and source.is_inside_tree():
		global_position = source.global_position
	
	if p_follow:
		follow = source
		follow.connect("tree_exited", Callable(self, "unfollow"))
	else:
		set_process(false)

func _ready() -> void:
	connect("finished", Callable(self, "queue_free"))
	add_to_group("dont_save")
	add_to_group("audio_sample")

func _process(delta: float):
	if is_instance_valid(follow):
		if not follow.is_inside_tree():
			push_error("audio source outsize od tree: " + follow.name)
			return
		global_position = follow.global_position

func unfollow():
	follow = null
	set_process(false)
