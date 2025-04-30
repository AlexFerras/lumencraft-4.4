@tool
extends Marker2D

@export var amount: int = 1
@export var tier: int = 1
@export var radius := 50.0: set = set_radius

func _ready() -> void:
	assert(amount > 0)
	assert(tier > 0 and tier < 6)
	
	if not Engine.is_editor_hint():
		var possible_artifacts := []
		for artifact in Const.Artifacts:
			if artifact.tier == tier:
				possible_artifacts.append(artifact.id)
		
		var pixel_map: PixelMap = Utils.game.map.pixel_map
		for i in amount:
			var artifact := preload("res://Nodes/Pickups/Artifact/Artifact.tscn").instantiate() as Pickup
			artifact.type = possible_artifacts[randi() % possible_artifacts.size()]
			
			var j: int # Zabezpieczenie...
			while not artifact.position or not pixel_map.is_pixel_solid(artifact.position, Utils.walkable_collision_mask):
				artifact.position = global_position + Utils.random_point_in_circle(radius)
				j += 1
				if j >= 10000:
					push_error("Spawner artefaktów musi być pod ziemią!")
			
			Utils.game.map.call_deferred("add_child", artifact)
		
		queue_free()

func set_radius(r: float):
	radius = r
	
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_arc(Vector2(), radius, 0, TAU, 64, Color.YELLOW, 2)
