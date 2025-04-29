@tool
extends Node2D

@export var highlight_green = preload("res://Nodes/Buildings/Workshop/Sprites/ScreenHighlight.png")
@export var highlight_red = preload("res://Nodes/Buildings/Workshop/Sprites/ScreenUnavailable.png")
@export var colorize_highlight: bool

@export var target_screen: NodePath
@export var display_icon: Texture2D: set = set_display_icon
@export var secondary_icon: Texture2D: set = set_secondary_icon
@export var flip_icon: bool: set = set_flip_icon
@export var icon_tint: Color = Color.WHITE: set = set_icon_tint

@export var override_position: int

@onready var icon_node: Sprite2D = get_node_or_null("Icon")
@onready var icon_node2: Sprite2D = get_node_or_null("SecondaryIcon")
@onready var highlight: Sprite2D = get_node_or_null("Sprite2D/Highlight")
@onready var screen = get_node(target_screen)

@onready var detector := $PlayerDetector as GenericInteractable

var is_ready: bool
var active: bool
var disabled: bool
var locked: bool

func _ready():
	assert(not target_screen.is_empty())
	
	is_ready = true
	if Engine.is_editor_hint():
		return
	
	if icon_node:
		icon_node.material.set_shader_parameter("time_offset", randf_range(-1000, 1000))
	screen.owned_computers.append(self)

func set_no_item():
	set_disabled(true)
	set_display_icon(preload("res://Nodes/Buildings/Reactor/no_item.png"))
	set_secondary_icon(null)
	set_icon_tint(Color(1.53, 0.09, 0.0, 0.63))
	icon_node.show()
	
	if active:
		screen.set_icon(preload("res://Nodes/Buildings/Reactor/no_item.png"))
		screen.set_title("Error")
		screen.set_description("404")
		set_deferred("active", false)

func set_finished_item():
	set_disabled(true)
	set_display_icon(preload("res://Nodes/Buildings/Reactor/FinishedItem.png"))
	set_secondary_icon(null)
	set_icon_tint(Color(0.09, 1.53, 0.0, 0.63))
	icon_node.show()
	
	if active:
		screen.set_icon(preload("res://Nodes/Buildings/Reactor/FinishedItem.png"))
		screen.set_title("")
		screen.set_description("")
		set_deferred("active", false)

func reload():
	if active:
		screen.reset()
	_setup()
	if active:
#		screen.reset_window(override_position)
		screen.call_deferred("reset_window", override_position)
	refresh_color()

func set_display_icon(new_icon: Texture2D):
	display_icon = new_icon
	call_deferred("update_icon")

func set_secondary_icon(new_icon: Texture2D):
	secondary_icon = new_icon
	call_deferred("update_icon")

func set_flip_icon(f: bool):
	flip_icon = f
	call_deferred("update_icon")

func set_icon_tint(t: Color):
	icon_tint = t
	call_deferred("update_icon")

func set_normal_icon_color():
	set_icon_tint(Color("#ffffffc0"))

func update_icon():
	if not is_ready:
		await self.ready
	
	if icon_node:
		icon_node.texture = display_icon 
		icon_node.modulate = icon_tint
		icon_node.flip_v = flip_icon
		icon_node.flip_h = flip_icon
	
	if icon_node2:
		icon_node2.texture = secondary_icon
	
	if display_icon:
		var min_scale =(28.0 / display_icon.get_width())
		min_scale= min( (18.0 / display_icon.get_height()),min_scale)
		icon_node.scale=min_scale*Vector2.ONE

func player_enter(area: Node2D) -> void:
	var player := Player.get_from_area(area)
	if player:
		screen.add_player(player)
		player.connect("inventory_changed", Callable(self, "reload_if_active"))

func player_exit(area: Node2D) -> void:
	var player := Player.get_from_area(area)
	if player:
		screen.remove_player(player)
		player.disconnect("inventory_changed", Callable(self, "reload_if_active"))

func refresh_color():
	if not highlight:
		return
	if highlight_red:
		if screen.can_use_computer():
			highlight.texture = highlight_green
			if colorize_highlight:
				highlight.modulate = Color.GREEN
		else:
			highlight.texture = highlight_red
			if colorize_highlight:
				highlight.modulate = Color.RED
	else:
		if screen.can_use_computer():
			highlight.modulate = Color.GREEN
		else:
			highlight.modulate = Color.RED

func set_disabled(d: bool):
	disabled = d
	set_power_disabled(d)

func set_power_disabled(d: bool):
	if icon_node:
		icon_node.visible = not d
	if icon_node2:
		icon_node2.visible = not d
	
	if disabled and not d:
		return
	
	detector.call_deferred("propagate_call", "set_disabled", [d])

func reload_if_active():
	if active:
		reload()

func _setup():
	pass

func _uninstall():
	pass

func _make():
	pass

func _long_make():
	pass

func _release_long_make():
	pass

func _fail():
	pass

func _can_use() -> bool:
	return true

func _can_use_long() -> bool:
	return _can_use()

func interact(player: Player):
	screen.current_player = player
	screen.interact()

func set_highlight(enabled: bool):
	active = enabled
	if not highlight:
		return
	
	highlight.visible = enabled

func _notification(what: int) -> void:
	if active and what == NOTIFICATION_TRANSLATION_CHANGED:
		reload()
