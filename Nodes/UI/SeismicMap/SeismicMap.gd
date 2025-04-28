extends SubViewportContainer

const INDICATOR_MAX_SIZE := 120.0

@onready var minimap := get_parent() as Control
@onready var sprite1 := $Viewport1/Sprite2D as Sprite2D
@onready var sprite2 := $Viewport2/Sprite2D as Sprite2D
@onready var viewport_1 = $Viewport1
@onready var viewport_2 = $Viewport2


var indicator: Vector3
var seismic_scale: Vector2

var seismic_map_size := Vector2.ZERO
var seismic_to_pixel_ratio  := 0.0

var update_diffuse := 0
var update_indicator := false

var indicator_array := PackedVector3Array()
var indicator_count := 0
var indicator_array_max_size := 60
var indicator_index := 0
var indicator_wraped_index := 0

func _ready():
	Utils.game.connect("map_changed", Callable(self, "on_map_changed"))
	
	sprite1.material.set_shader_parameter("resolution", size)
	sprite1.material.set_shader_parameter("resolution_inverse", Vector2.ONE/size)

	sprite1.texture = viewport_2.get_texture()
	viewport_2.get_texture().flags = Texture2D.FLAG_FILTER
	
	sprite2.material.set_shader_parameter("resolution", size)
	sprite2.material.set_shader_parameter("resolution_inverse", Vector2.ONE/size)

	sprite2.texture = viewport_1.get_texture()
	viewport_1.get_texture().flags = Texture2D.FLAG_FILTER
	
	indicator_array.resize(indicator_array_max_size)
	if Utils.game.map:
		on_map_changed()
		
	get_parent().seismic = self
	
func on_map_changed():
	seismic_scale = size / Utils.game.map.pixel_map.get_texture().get_size()
	scale = minimap.size / size
	sprite1.material.set_shader_parameter("resolution", size)
	sprite2.material.set_shader_parameter("resolution", size)
	sprite1.material.set_shader_parameter("resolution_inverse", Vector2.ONE/size)
	sprite2.material.set_shader_parameter("resolution_inverse", Vector2.ONE/size)

func add_indicator(indicator_coordinates: Vector2,indicator_size: float):
	if indicator_count <= indicator_array_max_size:
		indicator_array[wrapi(indicator_index + indicator_count, 0, indicator_array_max_size)] = Vector3(indicator_coordinates.x, indicator_coordinates.y, indicator_size)
		indicator_count += 1

func tick() -> void:
	update_diffuse = 2
#	sprite1.material.set_shader_param("propagate", update_diffuse)
#	sprite2.material.set_shader_param("propagate", update_diffuse)
#	prints("tick",str(randi()%10),indicator_count )

func _physics_process(delta) -> void:
#	rect_scale = minimap.rect_size / rect_size
#	sprite1.material.set_shader_param("resolution", rect_size)
#	sprite2.material.set_shader_param("resolution", rect_size)
#	sprite1.material.set_shader_param("resolution_inverse", Vector2.ONE/rect_size)
#	sprite2.material.set_shader_param("resolution_inverse", Vector2.ONE/rect_size)
#	prints(rect_size, Vector2.ONE/rect_size)
#	viewport_1.render_target_update_mode = Viewport.UPDATE_ONCE
#	viewport_2.render_target_update_mode = Viewport.UPDATE_ONCE
	
	if indicator_count > 0:
		indicator_wraped_index = wrapi(indicator_index, 0, indicator_array_max_size)
		indicator = Vector3(indicator_array[indicator_wraped_index].x * seismic_scale.x, indicator_array[indicator_wraped_index].y * seismic_scale.y, min(indicator_array[indicator_wraped_index].z * seismic_scale.x, INDICATOR_MAX_SIZE))
		
		indicator_index = indicator_wraped_index + 1
		indicator_count -= 1
#		indicator_array.remove(0)
		sprite1.material.set_shader_parameter("indicator_data", indicator)
		sprite2.material.set_shader_parameter("indicator_data", indicator)
		update_indicator = true
	elif update_indicator:
		sprite1.material.set_shader_parameter("indicator_data", Vector3.ZERO)
		sprite2.material.set_shader_parameter("indicator_data", Vector3.ZERO)
		update_indicator = false

	if update_diffuse:
		if update_diffuse == 2:
			sprite1.material.set_shader_parameter("propagate", true)
			sprite2.material.set_shader_parameter("propagate", true)
		else:
			sprite1.material.set_shader_parameter("propagate", false)
			sprite2.material.set_shader_parameter("propagate", false)
		update_diffuse -= 1
