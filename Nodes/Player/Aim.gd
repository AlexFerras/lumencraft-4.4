extends Marker2D

@onready var torso = get_parent()
@onready var player = torso.get_parent()
var heading:= Vector2()

func _ready():
	heading = Vector2.RIGHT.rotated(torso.global_rotation)
	
func _process(delta):
	if player.using_joypad() or player.assisted:
		rotation = 0
		return
	
	if player.get_global_transform_with_canvas().origin.distance_to(player.cursor.position) > 100: 
		var rot_difference = (player.cursor.position - player.get_global_transform_with_canvas().origin).angle_to(Vector2.RIGHT.rotated(torso.global_rotation))
		global_rotation = lerp_angle(global_rotation, (player.cursor.position - get_global_transform_with_canvas().origin).angle(), 0.25) + rot_difference * 0.4
	else:
		rotation = lerp_angle(rotation, 0.0, 0.05)
