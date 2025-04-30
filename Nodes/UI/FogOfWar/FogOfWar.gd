extends Node2D
class_name FogOfWar

var player: Player
var coords_scale := Vector2.ZERO

@onready var sprite = $FogOfWar
@onready var draw_node := $VP/clear_fog_draw as Node2D
@onready var viewport_handle := $VP as SubViewport
var pixel_map: PixelMap
#onready var darkness = $VP/Darkness as Sprite

func _ready():
	
	sprite.texture = viewport_handle.get_texture()
	# TODO
	#sprite.texture.flags = Texture2D.FLAG_FILTER
	
	if Utils.game.map:
		await Utils.game.map_changed
	pixel_map = Utils.game.map.pixel_map
	
	coords_scale = 8.0*Vector2.ONE
	draw_node.player_sight = 50.0 / coords_scale.x
#	print(coords_scale)
	scale = coords_scale
#	darkness.texture = Utils.game.map.darkness.light_viewport.get_texture()

#func set_darkness(new_texture:ViewportTexture):
#	darkness.texture = new_texture

# here be dragons if map is not square
func clear_circular_area( coordinates:Vector2, radius:float, color := Color.WHITE ) ->void :
	draw_node.clear_fog( Vector3( coordinates.x / coords_scale.x, coordinates.y / coords_scale.y, radius / coords_scale.x ), color )
	
# here be dragons if map is not square
func cover_circular_area( coordinates:Vector2, radius:float ) ->void :
	draw_node.add_fog( Vector3( coordinates.x / coords_scale.x, coordinates.y / coords_scale.y , radius / coords_scale.x ) )

func get_texture_for_minimap():
	return sprite.texture

func get_texture_for_map():
	return sprite.texture


#func _process(delta):
#	darkness.position = Utils.game.camera.get_camera_screen_center() / coords_scale
