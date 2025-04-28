extends Area2D

const RANGE = 200

@onready var  lightnings:= [$Lightning,$Lightning2,$Lightning3,$Lightning4]
@onready var ball := $"../LightningBall"
@onready var ballpos := $ballpos
@onready var collider := $CollisionShape2D as CollisionShape2D
var working= false: set = set_working
var damage_interval :int =8


func _ready() -> void:
	var data =Player.init_weapon(self, self, Const.ItemIDs.LASER)
	data.keep=true
	data.damage_timeout=damage_interval
	for i in lightnings:
		i.frame= randi() % i.frames.get_frame_count("anime")

func set_working(yes):
	self.visible=yes
	ball.visible=yes
	if working!=yes:
		collider.disabled=!yes
	working=yes

func _physics_process(delta):
	if working:

		var dir = Vector2.RIGHT.rotated(global_rotation)
		var xlength=RANGE+randf_range(-1,1)
		var pixel_map_raycast_result := Utils.game.map.pixel_map.rayCastQTDistance(global_position, dir, xlength,Utils.turret_bullet_collision_mask)

		if pixel_map_raycast_result:
			xlength=pixel_map_raycast_result.hit_distance
		
		var enemies_raycast_result = Utils.game.map.enemies_group.ray_cast_objects_distance(global_position, dir, xlength, true, true, true)

		if enemies_raycast_result:
			xlength = enemies_raycast_result.hit_distance

		if pixel_map_raycast_result:
			Utils.explode_circle(global_position + dir*(xlength+2), 5, 40, 5, 10)

		if (Utils.game.frame_from_start % damage_interval/2) == 0:
			collider.disabled=!collider.disabled

		scale.x =scale.x*0.1+ 0.9*(xlength+2) /7.4
		ball.global_position=ballpos.global_position
		ball.global_rotation=randf_range(-1,1)
		ball.global_scale=Vector2.ONE*0.13

		get_meta("data").velocity = dir * 60
