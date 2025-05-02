extends ProgressBar

@onready var label: Label = $Value
@onready var audio_spam: AudioStreamPlayer = get_node_or_null("TestAudio")
@onready var button: Button = get_parent()

var normal: StyleBox
@export var display_func: String
@export var disabled: bool: set = set_disabled
@export var disabled_style: StyleBox
var can_spam: bool

var slider_delay: float

func _ready() -> void:
	connect("value_changed", Callable(self, "update_label"))
	# TODO
	get_tree().connect("process_frame", Callable(self, "idle").bind(), CONNECT_ONE_SHOT)
	var normal = button.get_theme_stylebox("normal")
	
	get_parent().connect("gui_input", Callable(self, "_gui_input"))
	
	if disabled:
		get_parent().disabled = true
		modulate.v = 0.2
	
	set_process(false)

func _process(delta: float) -> void:
	slider_delay += delta
	if slider_delay >= 0.04:
		value += step * Input.get_axis("ui_left", "ui_right")
		slider_delay = 0
	
	if not Input.is_action_pressed("ui_left") and not Input.is_action_pressed("ui_right"):
		set_process(false)

func idle():
	can_spam = audio_spam != null
	focus_mode = Control.FOCUS_ALL

func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			set_value_at(event.position)
	
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			set_value_at(event.position)
	
	if event.is_echo():
		return
	
	if event.is_pressed() and (event.is_action("ui_left") or event.is_action("ui_right")):
		set_process(true)
		accept_event()

func set_value_at(pos: Vector2):
	value = min_value + (max_value - min_value) * (pos.x / size.x)

func update_label(v: float):
	if can_spam:
		audio_spam.call_deferred("play")
	
	if display_func:
		label.text = call(display_func, v)
	else:
		label.text = str(v)

#func convert_downsample_to_bit(value:int) -> int: ## wywalić
#	var r = 0
#	while value >> 1:
#		r += 1
#		value = value >> 1
#	return 6 - r

func light_downsample(value: int) -> String:
	value = 6 - value
	
	if value > 0:
		return str("1/", 1 << value)
	return "1"

#func shadow_render_steps(value:int) -> String: ## to też
#	return str(value / 4.0)

func intensity(v: float) -> String:
	return "OFF" if is_zero_approx(v) else "%.2f" % v

func audio(v: float) -> String:
	return str(round(v * 100))

func percent(v: float):
	return "%s%%" % (v * 100)

func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER:
		button.add_theme_stylebox_override("normal", button.get_stylebox("hover"))
	elif what == NOTIFICATION_FOCUS_EXIT:
		button.add_theme_stylebox_override("normal", normal)
		set_process(false)

func multiplier(v: float) -> String:
	return str(v, "×")

func set_value_if_not_disabled(v: float):
	if not disabled:
		value = v

func set_disabled(d):
	disabled = d
	if disabled:
		add_theme_stylebox_override("fg", disabled_style)
	else:
		remove_theme_stylebox_override("fg")
