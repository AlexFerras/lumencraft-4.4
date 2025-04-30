extends AudioStreamPlayer2D

@export var start_samples:Array[AudioStream] # (Array, AudioStream)
@export var loop_samples:Array[AudioStream] # (Array, AudioStream)
@export var end_samples:Array[AudioStream] # (Array, AudioStream)

var looping: bool

func _init() -> void:
	attenuation = 2
	max_distance = 500
	bus = "SFX"

func _ready() -> void:
	connect("finished", Callable(self, "next_sample"))

func start():
	if looping:
		return
	
	looping = true
	stream = start_samples[randi() % start_samples.size()]
	play()

func stop_looping():
	if not looping:
		return
	
	looping = false
	stream = end_samples[randi() % end_samples.size()]
	play()

func next_sample():
	if not looping:
		return
	
	stream = loop_samples[randi() % loop_samples.size()]
	play()
