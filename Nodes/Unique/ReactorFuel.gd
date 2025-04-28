#tool
extends Node2D

@onready var reactor: BaseBuilding = get_parent()
@onready var label: Label = $"%Label"
@onready var label_on_screen: Label = $"%Label2"
@onready var max_fuel: float = $"%FuelBars/ProgressBar3".max_value
@onready var siren_reverb:AudioEffectReverb = AudioServer.get_bus_effect(AudioServer.get_bus_index("Siren"), 0)
@export var fuel_level: float = 200
@export var lumen_fuel_value: float = 10

enum REACTOR_MODE {OFF, LOW, NOMINAL, OVERDRIVE}

var pickable_tracker: PixelMapPickables
@export var need_to_start := 10
@export var powered_chambers: Array
@export var reactor_mode:int = -1

var player_distance_from_core:= 0.0
var is_progressbar_on_screen: bool
const RADIUS = 75.0

signal reactor_state_changed(reactor_mode)

func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	assert(reactor)
	pickable_tracker = Utils.game.map.pickables
	
	for chamber in $Chambers.get_children():
		chamber.connect("body_entered", Callable(self, "chamber_enter").bind(chamber))
	
	reactor.start_on = false
	reactor.get_node("AnimationPlayer").play("startup")
	reactor.get_node("AnimationPlayer").advance(30)
	match reactor_mode:
		REACTOR_MODE.OFF:
#			reactor.get_node(@"AnimationPlayer").play("slow_burn")
			mode_kaput()
		REACTOR_MODE.LOW:
			mode_low()
		REACTOR_MODE.NOMINAL:
#			$"%SyrenAnimation".play("Stop")
#			reactor.get_node(@"AnimationPlayer").play("normal_burn")
			reactor.get_node("AnimationPlayer").play("startup")
			mode_nominal()
			reactor.start_on = true
		REACTOR_MODE.OVERDRIVE:
			mode_overdrive()
			reactor.start_on = true
		_:
#			reactor.get_node(@"AnimationPlayer").play("normal_burn")
#			$"%SyrenAnimation".play("Start")
			mode_low()

	update_fuel_bars()
	
	for i in powered_chambers:
		enable_chamber($Chambers.get_child(i))

	await get_parent().get_parent().ready
	emit_signal("reactor_state_changed", reactor_mode)

func process_siren_sfx():
	player_distance_from_core = global_position.distance_to( Utils.game.main_player.global_position )
	siren_reverb.wet = (max(0, player_distance_from_core - 400) / 600)
	siren_reverb.damping = 1.0 - siren_reverb.wet

func _physics_process(delta: float) -> void:
	process_siren_sfx()
	var prev_fuel_level := fuel_level
	
	fuel_level -= delta
	if powered_chambers.size() >= 3:
		fuel_level = 1300
	update_fuel_bars()

	if fuel_level <= 0:
		if reactor_mode == REACTOR_MODE.LOW:
			mode_kaput()

	elif fuel_level <= 300:
		if reactor_mode == REACTOR_MODE.NOMINAL:
#			reactor.get_node(@"AnimationPlayer").play("normal_burn")
			mode_low()
			
	elif fuel_level <= 1500:
		if reactor_mode == REACTOR_MODE.LOW:
			reactor.get_node("AnimationPlayer").play("startup")
			$"%SyrenAnimation".play("Stop")
			mode_nominal()

		if reactor_mode == REACTOR_MODE.OVERDRIVE:
			reactor.get_node("AnimationPlayer").play("normal_burn")
			mode_nominal()
	else:
		if reactor_mode == REACTOR_MODE.NOMINAL:
			mode_overdrive()
	
	update_fuel_labels()

	
func mode_low():
	reactor.get_node("AnimationPlayer").play("slow_burn")
	reactor_mode = REACTOR_MODE.LOW
	emit_signal("reactor_state_changed", reactor_mode)
	$"%LabelMode".text="LOW"
	$"%SyrenAnimation".play("Start")
	get_parent().regenerate = 0

func mode_nominal():
	reactor.init_range_extender(reactor.RANGE)
	reactor_mode = REACTOR_MODE.NOMINAL
	emit_signal("reactor_state_changed", reactor_mode)
	$"%LabelMode".text="NOMINAL"
	get_parent().regenerate = 0

func mode_overdrive():
	reactor.get_node("AnimationPlayer").play("fast_burn")
	reactor.init_range_extender(reactor.RANGE * 1.25)
	reactor_mode = REACTOR_MODE.OVERDRIVE
	emit_signal("reactor_state_changed", reactor_mode)
	$"%LabelMode".text="OVERDRIVE"
	get_parent().regenerate = 2
#	get_tree().call_group("player_buildings","set", "regenerate", 2)
	
func mode_kaput():
	reactor_mode = REACTOR_MODE.OFF
	reactor.get_node("AnimationPlayer").play("startdown")
	emit_signal("reactor_state_changed", reactor_mode)
	$"%LabelMode".text = ""
	
	Utils.call_super_deferred(reactor, "set", ["is_running", false])
#	$LampaAnimator.play("BlinkOFF")
	need_to_start = -1
	$"%SyrenAnimation".play("PowerOFF")
	$GenericComputer.set_disabled(true)
	get_parent().regenerate = 0

func update_fuel_labels():
	label.visible = reactor.is_running and powered_chambers.size() < 3
	label.text = "%02d:%02d" % [int(fuel_level) / 60, int(fuel_level) % 60]
	$"%CenterContainer".modulate.a = lerp($"%CenterContainer".modulate.a, 1.0 * int(not is_progressbar_on_screen), 0.1)
	label_on_screen.visible = label.visible
	label_on_screen.text = label.text

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_arc(Vector2(), RADIUS, 0, TAU, 32, Color.ORANGE, 2)

func chamber_enter(body, chamber):
	if body.is_in_group("lumen_chunks"):
		enable_chamber(chamber)
		body.queue_free()
		
		powered_chambers.append(chamber.get_index())
		match powered_chambers.size():
			1:
				Utils.game.ui.set_objective(2, "Collect 2 golden Lumen.")
			2:
				Utils.game.ui.set_objective(3, "Collect 1 golden Lumen.")
			3:
				Utils.game.ui.set_objective(4, "Defend yourself from the 10th enemy wave.")
		
		if powered_chambers.size() == 3:
			fuel_level = 999999999
			update_fuel_bars()

func enable_chamber(chamber):
	chamber.get_node("Sprite2D").frame = 0
	chamber.get_node("CollisionShape2D").queue_free()

func add_lumen(amount: int):
	for i in amount:
		if reactor.is_running:
			fuel_level = fuel_level + lumen_fuel_value
#			fuel_level = min(fuel_level + lumen_fuel_value, max_fuel)
			update_fuel_bars()
		else:
			need_to_start -= 1
			if need_to_start == 0:
				reactor.start()
				$"%SyrenAnimation".play("Stop")
				fuel_level += 600
				update_fuel_bars()

func update_fuel_bars():
	if powered_chambers.size() < 3:
		$"%FuelBars".propagate_call("set_value", [fuel_level])
		$"%FuelBarsOnScreen".propagate_call("set_value", [fuel_level])
	else:
		$"%FuelBarsOnScreen".visible = false
		$"%FuelBars".visible = false
		$"%LabelMode".text="RUNNING"
		
func _on_screen_entered_screen():
	is_progressbar_on_screen = true

func _on_screen_exited_screen():
	is_progressbar_on_screen = false

