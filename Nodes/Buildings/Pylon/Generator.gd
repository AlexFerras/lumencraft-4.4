extends BaseBuilding

signal lost_power

@export var turned_on: bool = true
@export var stored_power: float = 60
@export var max_power: float = 0

const RANGE = 40.0

@onready var animator := $AnimationPlayer as AnimationPlayer
@onready var lights := $Lights
@onready var interactive := $GenericInteractable as GenericInteractable
@onready var power_meter := $Sprite2D/TextureProgressBar as TextureProgressBar
@onready var diode := $Sprite2D/Diode as Sprite2D
@onready var audio := $AudioStreamPlayer2D as AudioStreamPlayer2D

var START := preload("res://SFX/Building/Generator/Start.wav")
var END := preload("res://SFX/Building/Generator/Shutdown.wav")

signal toggled

func _ready() -> void:
	if max_power == 0:
		max_power = stored_power
	
	if stored_power == -1:
		stored_power = 999999999

func _process(delta: float) -> void:
	stored_power -= delta
	if power_meter.visible:
		power_meter.value = stored_power
	
	if stored_power <= 0:
		set_disabled(true)
		Utils.play_sample(END, audio)
		init_range_extender(0)
		## TODO: dodać ładowanie

func build() -> void:
	super.build()
	update_power_meter()
	
	init_range_extender(RANGE)
	is_running = turned_on
	set_process(is_running)
	update_diode()

func set_disabled(disabled: bool, force := false):
	super.set_disabled(disabled, force)
	set_process(not disabled)
	interactive.set_can_interact(not disabled)
	update_diode()

func on_interacted(player) -> void:
	emit_signal("toggled")
	turned_on = not turned_on
	is_running = turned_on
	set_process(is_running)
	interactive.refresh_text = true
	update_diode()
	
	if is_running:
		Utils.play_sample(START, audio)
	else:
		Utils.play_sample(END, audio)

func update_diode():
	if not diode:
		connect("ready", Callable(self, "update_diode"))
		return
	
	if is_running:
		diode.modulate = Color.GREEN 
		animator.play("start")
	else:
		diode.modulate = Color.RED
		animator.play("sopt")

func audio_finished() -> void:
	if audio.stream == START:
		audio.stream = preload("res://SFX/Building/Generator/Running.wav")
		audio.play()

func destroy(explode := true):
	super.destroy(explode)
	Utils.game.map.post_process.set_deferred("range_dirty", true)

func update_power_meter():
	if not power_meter:
		await self.ready
	
	if max_power < 0:
		power_meter.hide()
	else:
		power_meter.show()
		power_meter.max_value = max_power
		power_meter.value = stored_power

func execute_action(action: String, data: Dictionary):
	if action == "toggle":
		on_interacted(null)
	else:
		super.execute_action(action, data)
