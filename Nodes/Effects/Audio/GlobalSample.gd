extends AudioStreamPlayer

func _init(audio: AudioStream):
	stream = audio
	bus = "SFX"
	autoplay = true

func _ready() -> void:
	connect("finished", Callable(self, "queue_free"))
	add_to_group("dont_save")
	add_to_group("audio_sample")
