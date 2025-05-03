extends VBoxContainer

var first_unfinished: int

@onready var nodes: GridContainer = $"%nodes"

var selected_node: Node

func _ready() -> void:
	var used_nodes: Array
	$"%ScrollContainer".scroll_vertical = 0
	
	for node in nodes.get_children():
		if node.get_index() == 3:
			used_nodes.append(node)
		
		if node.connects_to & 1:
			connect_to_neighbor(node, Vector2.DOWN, used_nodes)
		
		if node.connects_to & 2:
			connect_to_neighbor(node, Vector2.LEFT, used_nodes)
		
		if node.connects_to & 4:
			connect_to_neighbor(node, Vector2.RIGHT, used_nodes)
	
	var group := ButtonGroup.new()
	for node in nodes.get_children():
		if node is Line2D:
			break
		
		if not node in used_nodes:
			node.make_unused()
			continue
		
		node.set_group(group)
		node.connect("selected", Callable(self, "set_description_for_map").bind(node))
		
		if node.is_finished():
			node.currentState = node.NODE_STATE.COMPLETED
			node.update_state()
		else:
			var ok := true
			for dep in node.depends:
				if not dep.is_finished() or (Music.is_demo_build() and node.map_id == "something_something_wall"):
					node.currentState = node.NODE_STATE.LOCKED
					node.update_state()
					ok = false
					break
			
			if ok and first_unfinished == 0:
				first_unfinished = node.get_index()
	
	$"%Depth".hide()

func get_mission_node(coords: Vector2) -> Node:
	return nodes.get_child(coords.x + coords.y * nodes.columns)

func set_description_for_map(node: Node):
	selected_node = node
	var map: String = node.map_id
	
	var level_data: Dictionary = Const.CampaignLevels[map]
	
	for i in $"%Requirements".get_child_count():
		var req = $"%Requirements".get_child(i)
		req.modulate.a = 1
		
		if i >= level_data.requirements.size():
			if i == 0:
				req.set_text("No requirements", Color.WHITE)
			else:
				req.modulate.a = 0
		else:
			req.set_text(level_data.requirements[i], Color.RED)
	
	for i in $"%Rewards".get_child_count():
		var req = $"%Rewards".get_child(i)
		req.modulate.a = 1
		
		if i >= level_data.rewards.size():
			if i == 0:
				if node.is_unlocked():
					req.set_text("No rewards", Color.RED)
				else:
					req.set_text("???", Color.WHITE)
			else:
				req.modulate.a = 0
		else:
			if not node.is_unlocked():
				req.set_text("???", Color.WHITE)
				continue
			
			var reward = level_data.rewards[i]
			if reward is Dictionary:
				req.set_text("%s x%d" % [Utils.get_item_name(reward), reward.amount], Color.WHITE)
			else:
				if reward in Const.Technology:
					reward = Const.Technology[reward].name
				req.set_text(reward, Color.WHITE)
	
	var completed: float = Save.campaign.completed_levels.get(map, 0)
	if completed > 0:
		$"%Claimed".text = "%d%% Claimed" % int(completed * 100)
		$"%Claimed".modulate = Color.RED.lerp(Color.GREEN, completed)
		$"%BestScore".text = "Best Score: %d" % int(Save.campaign.level_scores.get(map, 0))
		$"%BestScore".modulate.a = 1
	else:
		$"%Claimed".modulate.a = 0
		$"%BestScore".modulate.a = 0
	
	if node.is_unlocked():
		$"%Title".text = level_data.level_name
		$"%Description".text = level_data.description
		$"%StartGame".disabled = false
		$"%Randomly".visible = node.big
		
		if node.map_id == "endless":
			$"%Depth".show()
			$"%Depth".text = tr("Depth: %d") % Save.campaign.endless_depth
		else:
			$"%Depth".hide()
	else:
		$"%Title".text = "Not Available"
		if Music.is_demo_build() and map == "something_something_wall":
			$"%Description".text = "Not available in demo"
		else:
			$"%Description".text = "Mission not available. Complete the previous one first."
		$"%StartGame".disabled = true
		$"%Depth".hide()

func connect_to_neighbor(node: Node, offset: Vector2, used_nodes: Array):
	var neighbor = get_mission_node(node.get_coords() + offset)
	used_nodes.append(neighbor)
	neighbor.depends.append(node)
	
	if offset == Vector2.DOWN:
		node.set_neighbor("bottom", neighbor)
		neighbor.set_neighbor("top", node)
	elif offset == Vector2.LEFT:
		node.set_neighbor("left", neighbor)
		neighbor.set_neighbor("right", node)
	elif offset == Vector2.RIGHT:
		node.set_neighbor("right", neighbor)
		neighbor.set_neighbor("left", node)
	
	var connection: Line2D
	if node.is_finished():
		connection = $"%ConnectionFinished".duplicate()
	else:
		connection = $"%ConnectionUnfinished".duplicate()
	
#	connection.points = [node.rect_position + Vector2(48, 104), neighbor.rect_position + Vector2(48, -8)]
	connection.points = [node.position + Vector2(48, 48) + offset * 56, neighbor.position + Vector2(48, 48) - offset * 56]
	nodes.add_child(connection)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		nodes.get_child(first_unfinished).call_deferred("select")
		await get_tree().process_frame
		$"%ScrollContainer".scroll_vertical = nodes.get_child(first_unfinished).position.y - $"%ScrollContainer".get_v_scroll_bar().page * 0.5
