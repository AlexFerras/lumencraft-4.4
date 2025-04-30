extends Node2D

const RING_THICC = 2.0

var active: bool: set = set_active

func set_active(a):
	active = a
	queue_redraw()

func _ready() -> void:
	z_index = ZIndexer.Indexes.FLOOR + 1

func _draw() -> void:
	if not active:
		return
	
	for expander in get_tree().get_nodes_in_group("range_draw"):
		var expanderange: float = expander.get_meta("range_expander_radius", 0.0)
		if is_zero_approx(expanderange) or not expander.visible:
			continue
		
		var pos = expander.global_position
		if expander.get_meta("custom_canvas", false):
			pos = get_viewport().canvas_transform.affine_inverse() * (pos)
		
		var color = Color.GREEN
		match int(expander.get_meta("range_expander_color", 0)):
			1:
				color = Color.ORANGE
			2:
				color = Color.DEEP_SKY_BLUE
		
		color.a = 0.5
		draw_arc(pos, expanderange - RING_THICC / 2, 0, TAU, 32, color, RING_THICC)
		color.a = 0.1
		draw_circle(pos, expanderange, color)
