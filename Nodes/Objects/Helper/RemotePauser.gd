extends Node

@export var target: NodePath

#func _notification(what: int) -> void:
#	if what == NOTIFICATION_PAUSED:
#		handle_pause(get_node(target))
#	elif what == NOTIFICATION_UNPAUSED:
#		handle_unpause(get_node(target))

func pause_pauser():##
	if target.is_empty():
		for node in get_children():
			handle_pause(node)
	else:
		handle_pause(get_node(target))

func unpause_pauser():##
	if target.is_empty():
		for node in get_children():
			handle_unpause(node)
	else:
		handle_unpause(get_node(target))

func handle_pause(node: Node):
	if node is GPUParticles2D:
		if node.emitting:
			node.set_meta("_was_emitting_", node.emitting)
			node.emitting = false
		elif node.has_meta("_was_emitting_"):
			node.remove_meta("_was_emitting_")
	elif node is AudioStreamPlayer2D:##
		if node.playing:
			node.set_meta("_where_play_", node.get_playback_position())
			node.stop()
		elif node.has_meta("_where_play_"):
			node.remove_meta("_where_play_")
	elif node is AnimationPlayer:##
		node.stop(false)
	elif node is get_script():##
		node.pause_pauser()
	else:
		pass
#		node.pause_mode = Node.PAUSE_MODE_STOP_ALWAYS

func handle_unpause(node: Node):
	if node is GPUParticles2D:
		if node.has_meta("_was_emitting_"):
			node.emitting = true
	elif node is AudioStreamPlayer2D:##
		if node.has_meta("_where_play_"):
			node.play(node.get_meta("_where_play_"))
	elif node is AnimationPlayer:##
		if node.current_animation:
			node.play()
	elif node is Tween:##
		node.resume_all()
	elif node is get_script():##
		node.unpause_pauser()
	else:
		pass
#		node.pause_mode = Node.PAUSE_MODE_INHERIT
