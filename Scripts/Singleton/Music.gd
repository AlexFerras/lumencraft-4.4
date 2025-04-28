@tool
extends Node

const TITLE = preload("res://Music/Dr 0001.ogg")
#const INTRO = p/reload("res://Music/Drone06.ogg")

const Set1 = {
	normal = preload("res://Music/New/Set1/normal1-granular-drone01.ogg"),
	intense = preload("res://Music/New/Set1/normal2-granular-drone01.ogg"),
	battle = preload("res://Music/New/Set1/walka1-granular-drone01.ogg"),
	wave = preload("res://Music/New/Set1/walka2-granular-drone01.ogg"),
	fear = preload("res://Music/New/drone_fear_st_02.ogg"),
}

const Set2 = {
	normal = preload("res://Music/New/Set2/dronest3_2_normal1.ogg"),
	intense = preload("res://Music/New/Set2/dronest3_2_normal2.ogg"),
	battle = preload("res://Music/New/Set2/dronest3_2_atack1.ogg"),
	wave = preload("res://Music/New/Set2/dronest3_2_atack2.ogg"),
	fear = preload("res://Music/New/drone_fear_st_02.ogg"),
}

const Set3 = {
	normal = preload("res://Music/New/Set3/01-eksploracja.ogg"),
	intense = preload("res://Music/New/Set3/01-baza.ogg"),
	battle = preload("res://Music/New/Set3/01-walka.ogg"),
	wave = preload("res://Music/New/Set3/01-fala.ogg"),
	fear = preload("res://Music/New/drone_fear_st_02.ogg"),
}

const Set4 = {
	normal = preload("res://Music/New/Set4/02-baza.ogg"),
	intense = preload("res://Music/New/Set4/02-eksploracja.ogg"),
	battle = preload("res://Music/New/Set4/02-walka.ogg"),
	wave = preload("res://Music/New/Set4/02-fala.ogg"),
	fear = preload("res://Music/New/drone_fear_st_02.ogg"),
}

##

const Campaign = {
	hub1 = "res://SFX/Campaign/motyw01-base-03.ogg",
	hub2 = "res://SFX/Campaign/motyw02-mel.ogg",
	hub3 = "res://SFX/Campaign/motyw04-mel-fx.ogg",
	endgame = "res://SFX/Campaign/heroic.wav"
}

var music_player1: AudioStreamPlayer
var music_player2: AudioStreamPlayer
var current_audio_player: AudioStreamPlayer
var other_audio_player: AudioStreamPlayer

var current_set := Set1
var current_track: String

var queue: Array
var transition: Tween
var transition_target: AudioStream
var block_stop: int

var do_fade:bool = false
var fader := 1.0
var fade_time := 1.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	set_process(false)
	
	music_player1 = AudioStreamPlayer.new()
	music_player1.bus = "Music"
	music_player1.connect("finished", Callable(self, "_on_music_finish"))
	add_child(music_player1)
	
	music_player2 = AudioStreamPlayer.new()
	music_player2.bus = "Music"
	music_player2.connect("finished", Callable(self, "_on_music_finish"))
	add_child(music_player2)
	
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize_set()

func play_music(music: AudioStream):
	_block_stop()
	
	music_player1.volume_db = linear_to_db(1.0)
	music_player2.volume_db = linear_to_db(0.0)
	
	current_audio_player = music_player1
	current_audio_player.stream = music
	current_audio_player.play()
	
	current_track = ""

func swap_track(track: String):
#	if track == current_track:
#		return
	_block_stop()
	
	if not current_audio_player:
		push_warning("but why")
		current_audio_player = music_player1
	
	current_track = track
	var music: AudioStream = current_set[current_track]
	
	if current_audio_player.stream == music and fader > 0:
		fader = fade_time - fader
		var temp = other_audio_player
		other_audio_player = current_audio_player
		current_audio_player = other_audio_player
		return
	
	other_audio_player = music_player2 if current_audio_player == music_player1 else music_player1
	other_audio_player.stream = music
	other_audio_player.volume_db = linear_to_db(0)
	copy_playback(current_audio_player, other_audio_player)

	set_process(true)
	fader = fade_time

func _process(delta):
	if fader > delta:
		fader -= delta
		other_audio_player.volume_db = linear_to_db(1.0 - (fader / fade_time))
		current_audio_player.volume_db = linear_to_db(fader / fade_time)
	else:
		set_process(false)
		fader = 0.0
		other_audio_player.volume_db = linear_to_db(1.0)
		_block_stop()
		current_audio_player.stop()
		current_audio_player = other_audio_player
		other_audio_player = null

func crossfade(music: AudioStream):
	if not current_audio_player:
		current_audio_player = music_player1
	
	if music == current_audio_player.stream and queue.is_empty() or music == transition_target:
		return
	
	current_track = ""
	queue.append(music)
	
	if not transition:
		_pop_queue()

func stop():
	if not music_player1: # uh
		return
	
	_block_stop()
	music_player1.stop()
	music_player2.stop()

func _pop_queue():
	if queue.is_empty() or not is_inside_tree():
		return
	
	other_audio_player = music_player2 if current_audio_player == music_player1 else music_player1
	other_audio_player.stream = queue.pop_front()
	copy_playback(current_audio_player, other_audio_player)
	
	set_process(true)
	fader = fade_time

func _finalize_queue(new_audio_player: AudioStreamPlayer):
	_block_stop()
	_pop_queue()

func _block_stop(): ## hack bo bug
	block_stop = get_tree().get_frame() + 3

func _on_music_finish():
	if current_track.is_empty() or get_tree().get_frame() - block_stop < 0:
		return
	
	if current_track != "battle" and current_track != "wave":
		if current_set == Set1:
			current_set = Set2
		elif current_set == Set2:
			current_set = Set3
		elif current_set == Set3:
			current_set = Set4
		elif current_set == Set4:
			current_set = Set1
	
	if fader > 0:
		fader = 0
		_block_stop()
		other_audio_player.stop()
		other_audio_player = null
		set_process(false)
	
	var music: AudioStream = current_set[current_track]
	current_audio_player.stream = music
	current_audio_player.volume_db = linear_to_db(1)
	current_audio_player.play()

static func get_music_list() -> Array:
	var list: Array
	
	var script = Music.get_script().source_code.split("\n")
	for line in script:
		var i = line.find("preload(")
		if i > -1:
			var j = line.find(".ogg\")")
			list.append(line.substr(i + 9, j - i - 5))
		
		if line.begins_with("##"):
			break
	
	return list

# Pewnie zastanawiasz się co to tutaj robi
# Słowo klucz: cykliczne referencje
func is_game_build() -> bool:
	if not OS.has_feature("editor"):
		return true
	
	if Const.get_override("TEST_RELEASE"):
		return true
	
	return false

# Nawet nie próbowałem gdzieś indzej tego dawać.
func is_demo_build() -> bool:
	if OS.has_feature("demo"):
		return true
	
	if Const.get_override("TEST_DEMO"):
		return true
	
	return false

func is_mobile_build() -> bool:
	if OS.has_feature("mobile"):
		return true
	
	if Const.get_override("TEST_MOBILE"):
		return true
	
	return false

func is_switch_build() -> bool:
	return false

func copy_playback(from: AudioStreamPlayer, to: AudioStreamPlayer):
	var ratio := from.get_playback_position() / from.stream.get_length()
	to.play(ratio * to.stream.get_length())

func get_current_set():
	if current_set == Set1:
		return 1
	elif current_set == Set2:
		return 2
	elif current_set == Set3:
		return 3
	elif current_set == Set4:
		return 4

func randomize_set():
	current_set = get("Set" + str(randi() % 4 + 1))
	if current_audio_player:
		current_audio_player.seek(0)
