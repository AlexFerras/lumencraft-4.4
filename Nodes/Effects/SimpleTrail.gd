extends Sprite2D

@export var start_point : Vector2
@export var fadeout_random := Vector2(0.3, 1.0)
@export var constant_fade := 0.5
@export var unit_size := 1.0

var texture_width_inv: float

func _ready():
	start_point = get_parent().global_position
	set_as_top_level(true)
	texture_width_inv = 1.0 / texture.get_width()
	get_parent().connect("tree_exiting", Callable(self, "stop"))

func stop():
	set_physics_process(false)
	get_parent().remove_child(self)
	Utils.game.map.call_deferred("add_child", self)
	
	var seq := Utils.create_tween()
	seq.tween_property(self, "modulate:a", 0.0, randf_range(fadeout_random[0], fadeout_random[1]))
	seq.parallel().tween_property(self, "scale:y", scale.y * 3.0, randf_range(fadeout_random[0], fadeout_random[1]))
	seq.tween_callback(Callable(self, "queue_free"))

func dup():
	var next := duplicate()
	get_parent().add_child(next)
	stop()
	return next

func _physics_process(delta: float):
	var diff: Vector2 = get_parent().global_position - start_point
	global_position = lerp(start_point, start_point + diff, 1 - unit_size * 0.5)
	global_scale.x = diff.length() * texture_width_inv * unit_size
	global_rotation = diff.angle()
	modulate.a -= delta * constant_fade
