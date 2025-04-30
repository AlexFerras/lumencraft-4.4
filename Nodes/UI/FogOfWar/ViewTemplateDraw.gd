extends Node2D

var clear_fog_markers := PackedVector3Array()
var color_fog_markers := PackedColorArray()
var add_fog_markers   := PackedVector3Array()
var load_fog: RID

var player_sight      :float
var additional_reveal := 40.0

const segments:=37
const segments_half := segments / 2
const player_fov := deg_to_rad(120)
const reveal_range := 170.0
var dir:=Vector2.ZERO
var end:=Vector2.ZERO
var last_vertex:=Vector2.ZERO
var current_vertex:=Vector2.ZERO

@onready var fog_of_war = $"../.."

var fog_clear_strength=0.0

func _ready():
	Utils.connect_to_lazy(self)

func _lazy_process():
	if get_tree().paused:
		return 
	get_parent().render_target_update_mode = SubViewport.UPDATE_ONCE 
	fog_clear_strength+=Utils.get_lazy_delta()
	queue_redraw()

func clear_fog( marker:Vector3, color:=Color.WHITE ) -> void:
	clear_fog_markers.append( marker )
	color_fog_markers.append( color )
	
func add_fog( marker:Vector3 ) -> void:
	add_fog_markers.append( marker )

func _draw() -> void:
	if load_fog:
		RenderingServer.canvas_item_add_texture_rect(get_canvas_item(), Rect2(Vector2(), Vector2(1024, 1024)), load_fog)
		load_fog = RID()
	
	for player in Utils.game.players:
#		if Music.is_switch_build():
#			draw_circle( player.global_position/ fog_of_war.coords_scale, player_sight * 4, Color( 1, 1, 1, 1.44*fog_clear_strength ) )
#			continue
		
		if not Utils.game.map.pixel_map.is_pixel_solid(player.global_position, Utils.walkable_collision_mask):
			var player_visibility_vertices := PackedVector2Array()
			
			var look_angle: float = player.get_shoot_rotation()
			if look_angle == INF:
				look_angle = player.torso.global_rotation
			var player_heading := Vector2.RIGHT.rotated(look_angle)
			
			player_visibility_vertices.push_back((player.global_position - player_heading * player_sight * fog_of_war.coords_scale) / fog_of_war.coords_scale)
			for i in segments:
				dir = Vector2.RIGHT.rotated(look_angle +  (i-segments/2) * player_fov / segments )
				end = player.global_position + dir * reveal_range * player_heading.dot(dir)
				var ray = Utils.game.map.pixel_map.rayCastQTFromTo(player.global_position, end, Utils.game.map.get_material_occlusion_mask(player.on_stand), false)
				if ray:
					current_vertex=(dir*additional_reveal +ray.hit_position) / fog_of_war.coords_scale
				else:
					current_vertex=(dir*additional_reveal +end ) / fog_of_war.coords_scale
				if last_vertex!= current_vertex :
					player_visibility_vertices.push_back(current_vertex)
					last_vertex=current_vertex
			if player_visibility_vertices.size() >13:
				draw_colored_polygon( player_visibility_vertices, Color8(255,255,255,min(500.0*fog_clear_strength,255.0)) ,  PackedVector2Array())
		
		draw_circle( player.global_position/ fog_of_war.coords_scale, player_sight, Color( 1, 1, 1, 1.44*fog_clear_strength ) )

	for i in clear_fog_markers.size():
		draw_circle( Vector2( clear_fog_markers[i].x, clear_fog_markers[i].y ), clear_fog_markers[i].z, color_fog_markers[i] )
	clear_fog_markers = PackedVector3Array()
	color_fog_markers = PackedColorArray()
	
	for marker in add_fog_markers:
		draw_circle( Vector2( marker.x, marker.y ), marker.z, Color.BLACK )
	add_fog_markers = PackedVector3Array()
	fog_clear_strength=0.0

