extends GenericInteractable

@export var message # (String, MULTILINE)
@export var destructible: bool

@onready var animator := $AnimationPlayer as AnimationPlayer
@onready var screen := $ComputerScreen
@onready var scroll: ScrollBar = $ScrollContainer.get_v_scroll_bar()

var life := 5
var screen_active: bool
var current_player: Player

func _ready() -> void:
	if not message.is_empty():
		animator.play("Active")
		screen.reset()
		$"%ScrollMessage".text = message
	
	if destructible:
		Utils.set_collisions($Detector, Const.ENEMY_COLLISION_LAYER, Utils.PASSIVE)
	else:
		$Detector.queue_free()
	
	$ScrollContainer.show()
	screen.add_custom_control($ScrollContainer)
	
	set_physics_process(false)

func _process(delta: float) -> void:
	if not current_player:
		return
	
	if current_player.is_action_pressed("look_up"):
		scroll.value -= 200 * delta
	elif current_player.is_action_pressed("look_down"):
		scroll.value += 200 * delta

func _physics_process(delta: float) -> void:
	if screen.main_window.is_animating():
		return
	
	if screen.main_window.visible != screen_active:
		if screen_active:
			screen.main_window.showme()
			screen.main_window.show()
			screen.call_deferred("reset_window")
		else:
			screen.hide_ui()
	
	set_physics_process(false)

func _interact(player: Player):
	if screen.main_window.visible:
		if scroll.value < scroll.max_value - scroll.page:
			scroll.value += scroll.page - 42
		else:
			close_screen()
	else:
		set_player_overrides(true)
		set_show_ui(true)
		current_player = player
		scroll.value = 0
		disable_icon = true
		Player.set_block_scroll_all(true)
	animator.play("RESET")

func _can_interact() -> bool:
	return not message.is_empty()

func set_show_ui(show: bool):
	screen_active = show
	set_physics_process(true)
	set_process(show)
	if not show:
		Player.set_block_scroll_all(false)

func refresh_interactions():
	super.refresh_interactions()
	if players_inside.is_empty():
		call_deferred("close_screen")
		disable_icon = false

func on_enter_damage(area: Area2D) -> void:
	if life <= 0:
		return
	
	if area.is_in_group("player_projectile"):
		Utils.play_sample(Utils.random_sound("res://SFX/Bullets/bullet_impact_metal_light"), self)
		Utils.on_hit(area)
		life -= 1
		
		if life <= 0:
			var explosion := Const.EXPLOSION.instantiate()
			explosion.position = global_position
			explosion.type = explosion.NEUTRAL
			explosion.scale = Vector2.ONE * 0.1
			Utils.game.map.add_child(explosion)
			queue_free()

func _get_save_data() -> Dictionary:
	if animator.current_animation != "Active":
		return {read = true}
	
	return {}

func _set_save_data(data: Dictionary):
	await self.ready
	if data.get("read", false):
		animator.play("RESET")

func set_player_overrides(override: bool):
	if override:
		for player in players_inside:
			player.cancel_override = funcref(self, "close_screen")
	else:
		for player in players_inside:
			player.cancel_override = null

func close_screen(player = null):
	set_player_overrides(false)
	set_show_ui(false)
	screen.main_window.connect("visibility_changed", Callable(self, "set").bind("disable_icon", false), CONNECT_ONE_SHOT)

func _player_exited(player: Player):
	player.cancel_override = null
