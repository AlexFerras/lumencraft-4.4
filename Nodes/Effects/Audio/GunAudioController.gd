extends AudioStreamPlayer2D

@export var shot_path: String

var first_shot: AudioStream
var shots: Array
var tail: AudioStream

var tail_player: AudioStreamPlayer2D
var first := true

func _ready() -> void:
	stream = AudioStreamRandomizer.new()
	bus = "SFX"
	max_distance = 500
	attenuation = 2
	
	tail_player = AudioStreamPlayer2D.new()
	tail_player.max_distance = 500
	tail_player.attenuation = 2
	tail_player.bus = "SFX"
	add_child(tail_player)
	update_shot_set()

func update_shot_set():
	shots.clear()
	first_shot = load(shot_path + "00_first_01.wav")
	tail = load(shot_path + "00_tail_only_01.wav")
	
	var shot_tester := File.new()
	for i in 1000:
		var path := str(shot_path, str(i +1).pad_zeros(2), ".wav")
		if shot_tester.file_exists(path + ".import"):
			shots.append(load(path))
		else:
			break
	
	tail_player.stream = tail

func reset():
	first = true

func shoot():
	if first:
		stream.audio_stream = first_shot
		first = false
	else:
		stream.audio_stream = shots[randi() % shots.size()]
	
	tail_player.play()
	play()
