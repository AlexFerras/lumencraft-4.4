@tool
extends Node2D
class_name LightSprite

@export var texture: Texture2D
@export var offset: Vector2
@export var drop_shadow: bool
@export var follow_rotation: bool
@export var fov_angle: float = TAU
@export var radius: float = 150
@export var is_static: bool: set = set_static
var dirty: bool = true

var reveal_fog: bool

func _enter_tree() -> void:
	add_to_group("lights")

func _ready() -> void:
	dirty = true # bugfix, usunąć kiedyś
	reveal()

func set_static(s: bool):
	is_static = s
	dirty = true

#func _ready():
#	Utils.add_to_tracker(self, Utils.map.lights_tracker, 200, 999999)

func execute_action(action: String, data: Dictionary):
	visible = not visible
	dirty = true
	reveal()

func reveal():
	if visible and reveal_fog and Utils.game.map.pixel_map.fog_of_war:
		Utils.game.map.pixel_map.fog_of_war.call_deferred("clear_circular_area", global_position, scale.x * 128, Color.WHITE)
