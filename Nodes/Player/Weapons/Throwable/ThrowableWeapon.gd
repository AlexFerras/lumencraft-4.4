extends PixelMapRigidBody

const RISE_TIME = 0.25

var high: bool
var falling: bool
var original_scale: Vector2


var player: Player
func set_player(p: Player):
	player = p



func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	linear_velocity *= 0.95
	pixel_map_physics(state, Player.get_weapon_mask({high = high}) & Utils.walkable_collision_mask)
	
	if falling and not Utils.game.map.pixel_map.is_pixel_solid(global_position, Utils.walkable_collision_mask):
		falling = false
		fall()

func thrown(by: Node2D):
	add_collision_exception_with(by)
	high = true
	
	var spr: Sprite2D = get_node_or_null("Sprite2D")
	assert(spr)
	original_scale = spr.scale
	
	if not is_inside_tree():
		await self.ready
	
	var seq := create_tween()
	seq.tween_property(spr, "scale", spr.scale * 1.8, RISE_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	seq.parallel().tween_property(self, "z_index", ZIndexer.Indexes.BUILDING_HIGH + 10, 0.05)
	seq.tween_interval(0.2)
	seq.connect("finished", Callable(self, "top_height").bind(by))

func top_height(thrower: Node2D):
	remove_collision_exception_with(thrower)
	if Utils.game.map.pixel_map.is_pixel_solid(global_position, Utils.walkable_collision_mask):
		falling = true
	else:
		fall()

func fall():
	var spr: Sprite2D = get_node_or_null("Sprite2D")
	var seq := create_tween()
	seq.tween_property(spr, "scale", original_scale, RISE_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	seq.parallel().tween_property(self, "z_index", ZIndexer.Indexes.OBJECTS, RISE_TIME)
	high = false
