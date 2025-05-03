extends TextureRect

@export var overlay_path: NodePath

var overlay: Control
@onready var seismic = $"SeismicMap"
@onready var zoom_label: Label = get_node_or_null("../../Buttons/Label")

@export var no_zoom: bool

var screen_center_position: Vector2: set = set_view_center
var minimap_size: Vector2

var zoom: float
var target_zoom: float

var minimap_bounds: Rect2
var margin := 64.0

signal view_changed

func _ready() -> void:
	if not overlay_path.is_empty():
		overlay = get_node(overlay_path)
	else:
		overlay = $"../Overlay"
	
	Utils.game.connect("map_changed", Callable(self, "on_map_change"))
	material.set_shader_parameter("material_colors_texture", Const.material_colors_texture)
	#texture.flags = 0
	
	minimap_size = size

func on_map_change():
	texture = Utils.game.map.pixel_map.get_texture()
	
	if not no_zoom:
		zoom = max(1, int(texture.get_size().x / 1024))
		target_zoom = zoom
		update_view()
	
	if zoom_label:
		zoom_label.text = str("x", target_zoom)

#func _process(delta: float) -> void:
#	prints(get_parent().name, overlay.scale)

func set_view_center(center: Vector2):
	screen_center_position = center
	update_view()
	
	material.set_shader_parameter("screen_center_position", screen_center_position)
	material.set_shader_parameter("size", size)
	material.set_shader_parameter("zoom", zoom)

func project_on_minimap(coordinates: Vector2) -> Vector2:
	return Vector2()
#	var minimap_coordinates = coordinates * minimap_texture_size / texture.atlas.get_size()
#	return minimap_coordinates

#func refresh_buffs():
#	material.set_shader_param("highlight_materials", Utils.game.map.buffs.has(Const.Buffs.SEISMOGRAPH)) ## TODO: można użyć tego

func update_view():
	if is_nan(get_viewport_rect().size.y):
		return
	zoom = lerp(zoom, target_zoom, 0.1)
	if not no_zoom:
		size = minimap_size * zoom
	
	var unit_center := screen_center_position / texture.get_size()
	var view_size := size - Vector2.ONE * margin * 2
	
	if size > minimap_size - Vector2.ONE * margin * 2:
		position = Vector2.ONE * margin - unit_center * view_size
	else:
		position = minimap_size / 2 - size / 2
	
	emit_signal("view_changed")
	
#	seismic.rect_position = - minimap_bounds.position / zoom + minimap_size
#	seismic.rect_scale = (seismic.seismic_map_size / rect_size) * (minimap_size / seismic.seismic_map_size)
	
#	$Label.text = str( floor(minimap_bounds.position.x) ) + " + " + str( floor(minimap_bounds.size.x) ) + " > " + str( Utils.game.map.pixel_map_size.x )
#	seismic.rect_scale = (seismic.rect_size / minimap_texture_size) * (Utils.game.map.pixel_map_size / seismic.seismic_map_size * (minimap_size / seismic.seismic_map_size))
	# debug
#	$Label.text = str( minimap_texture_size )
#	$Label.text = str( (Utils.game.map.pixel_map_size / seismic.seismic_map_size * (minimap_size / seismic.seismic_map_size) ) )
#	$Label.text = str( (screen_center_position / zoom).round() ) + " " + str(minimap_texture_size.round())
#	$Label2.text = str( minimap_bounds.position.round() ) + " " + str( minimap_bounds.size.round() )
#	$Label3.text = str( seismic_offset.round() )

func get_view_scale() -> float:
	return size.y / texture.get_height()

func get_center():
	return minimap_size * 0.5 - position

func zoom_out():
	if target_zoom > 0.25:
		target_zoom -= 0.25
		zoom_label.text = str("x", target_zoom)

func zoom_in():
	if target_zoom < 20:
		target_zoom += 0.25
		zoom_label.text = str("x", target_zoom)
