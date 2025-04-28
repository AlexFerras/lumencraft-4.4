extends FogOfWar

@onready var fear_viewport_handle := $VP2 as SubViewport
@onready var darkness = $VP2/Darkness as Sprite2D
@onready var fear = $Fear

func _ready():
	Utils.game.connect("map_initialized", Callable(self, "parent_ready").bind(), CONNECT_ONE_SHOT)

func parent_ready():
	fear.texture = fear_viewport_handle.get_texture()
	fear.texture.flags = Texture2D.FLAG_FILTER
	darkness.texture = Utils.game.map.darkness.light_viewport.get_texture()
	Utils.game.map.darkness.connect("viewports_resized", Callable(self, "update_darkness"))
	sprite.visible = false
	scale = Vector2.ONE
#	for fog in get_tree().get_nodes_in_group("fog_of_war"):
#		if fog != self:
#			fog.queue_free()

func set_darkness(new_texture:ViewportTexture):
	darkness.texture = new_texture

func update_darkness():
	darkness.scale.x = Save.config.downsample/64.0
	darkness.scale.y = darkness.scale.x
	darkness.update()

func _process(delta):
	darkness.position = Utils.game.camera.get_camera_screen_center() / 8.0
	darkness.scale.x = Save.config.downsample/64.0 * (8.0*Utils.game.camera.zoom.x)
	darkness.scale.y = darkness.scale.x
