extends PanelContainer

@onready var minimap := $Minimap as TextureRect
@onready var overlay := minimap.overlay as Control

func _ready() -> void:
	Utils.game.connect("map_changed", Callable(self, "on_map_changed"))
	
	if Utils.game.map:
		on_map_changed()
	
	Utils.connect_to_lazy(minimap.overlay, "update")

func on_map_changed():
	if Utils.game.map.pixel_map.fog_of_war:
		var sprite := $"%FogOfWarFull" as Sprite2D
		sprite.texture = Utils.game.map.pixel_map.fog_of_war.get_texture_for_map()
		sprite.position = minimap.position
		sprite.scale = 8.0 * minimap.size / Utils.game.map.pixel_map.get_texture().get_size()
		sprite.region_rect.size = minimap.size / sprite.scale
		sprite.connect("visibility_changed", Callable(self, "update_fog_visibility"))
		
		$"%FullMapViewportContainer".material.set_shader_parameter("fog_texture", $"%FullFogViewport".get_texture())
#		$"%FullMapViewportContainer".material.set_shader_param("fog_scale", sprite.scale.x)
	
	minimap.margin = 0
	minimap.zoom = Utils.game.map.pixel_map.get_texture().get_size().x / minimap.size.x
	minimap.target_zoom = minimap.zoom
	overlay.draw_screen_rect = false
	minimap.update_view()
	update_fog_visibility()

func update_fog_visibility():
	$"%FullMapViewportContainer".material.set_shader_parameter("hide_fog", not $"%FogOfWarFull".visible)
