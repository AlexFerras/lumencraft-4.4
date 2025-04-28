extends Sprite2D

@export var fear_amount_max     := 100.0
@export var fear_amount_current := 0.0
@export var fear_amount_change_factor := 0.05

var sample_names := ["res://SFX/Fear/voice_male_breathing_slow_0", "res://SFX/Fear/voice_male_breathing_medium_0", "res://SFX/Fear/voice_male_breathing_fast_0"]
var light_level:float = 0.0
var is_in_light:bool
var darkness_color:Color

@onready var player:Player = get_parent()
@onready var darkness = $SubViewport/DarknessSprite

@onready var breath_fast = $BreathFast
@onready var breath_medium = $BreathMedium
@onready var breath_slow = $BreathSlow
@onready var viewport = $SubViewport

var darkness_counter:float = 0.0
var in_fear_counter:float = 0.0

func _ready():
	darkness.texture = Utils.game.map.darkness.light_viewport.get_texture()
	texture = viewport.get_texture()
	get_parent().is_fear_enabled = true
	get_parent().is_dash_enabled = false
	
	Utils.game.map.darkness.connect("viewports_resized", Callable(self, "update_darkness"))
	update_darkness()
	player.get_node("Torso/Spotlight").scale = Vector2(0.08, 0.08)
	
func add_fear(amount):
	fear_amount_current = clamp(fear_amount_current + amount, 0, fear_amount_max)

func _physics_process(delta):
	var delay = 0.5
	darkness_counter += delta
	if darkness_counter >=  delay:
		darkness_counter -= delay
		test_darkness()

	if light_level > 0.5  and fear_amount_current > 0:
		is_in_light = true
		add_fear(- light_level * fear_amount_change_factor * 2)
	else:
		is_in_light = false
		add_fear(fear_amount_change_factor - light_level * fear_amount_change_factor)
	if is_in_light:
		in_fear_counter = max(in_fear_counter - delta, 0)
	elif fear_amount_current / fear_amount_max > 0.4 and not is_in_light:
		in_fear_counter += delta

#	$Label.text = str(darkness_color.v) +" "+ str(darkness_color.s) +"\n"
#	$Label.text += str(round(fear_amount_current), " ", round(light_level*10000)/10000)
	blend_audio()
	
func update_darkness():
	darkness.scale.x = Save.config.downsample/8.0
	darkness.scale.y = darkness.scale.x
	darkness.update()

func test_darkness() -> void:
#	print((player.position_on_screen - get_viewport_rect().size*0.5), player.position_on_screen - get_viewport().size, darkness.texture.get_size(), Save.config.downsample)
	
	darkness.position = (Vector2.RIGHT.rotated(player.torso.rotation) * 30.0 + Vector2(2.0,6.75) ) / 4.0
	darkness.position -= (player.position_on_screen - get_viewport_rect().size * 0.5) / 8.0

	var data = texture.get_data()
	false # data.lock() # TODOConverter3To4, Image no longer requires locking, `false` helps to not break one line if/else, so it can freely be removed
	darkness_color = data.get_pixel(0, 0)
	false # data.unlock() # TODOConverter3To4, Image no longer requires locking, `false` helps to not break one line if/else, so it can freely be removed
	
	light_level = darkness_color.v
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func blend_audio():
	var value_1 = min( smoothstep(10,50,fear_amount_current), smoothstep(63,57,fear_amount_current)  )
	var value_2 = min( smoothstep(57,63,fear_amount_current), smoothstep(78,72,fear_amount_current) )
	var value_3 = smoothstep(72,78,fear_amount_current) 
	if value_1 > 0:
		if not breath_slow.playing:
			breath_slow.playing = true
		breath_slow.volume_db = linear_to_db(value_1 * 0.85)
	else:
		breath_slow.playing = false

	if value_2 > 0:
		if not breath_medium.playing:
			breath_medium.playing = true
		breath_medium.volume_db = linear_to_db(value_2)
	else:
		breath_medium.playing = false
		
	if value_3 > 0:
		if not breath_fast.playing:
			breath_fast.playing = true
		breath_fast.volume_db = linear_to_db(value_3)
	else:
		breath_fast.playing = false

	if value_1 + value_2 + value_3 > 0:
		if Music.current_track == "normal" or not Music.current_track:
			Music.swap_track("fear")
	else:
		if Music.current_track == "fear":
			Music.swap_track("normal")

func _on_BreathSlow_finished():
	breath_fast.stream = load(sample_names[0]+str(randi()%2+1))

func _on_BreathMedium_finished():
	breath_fast.stream = load(sample_names[1]+str(randi()%2+1))

func _on_BreathFast_finished():
	breath_fast.stream = load(sample_names[2]+str(randi()%2+1))
