@tool
extends EditorScript

func _run() -> void:
	var sprite: Sprite2D
	var animator: AnimationPlayer
	
	for node in get_editor_interface().get_selection().get_selected_nodes():
		if node is Sprite2D:
			sprite = node
		if node is AnimationPlayer:
			animator = node
	
	if not sprite:
		sprite = get_scene().get_node("Sprite2D")
	if not animator:
		animator = get_scene().get_node("AnimationPlayer")
	
	assert(sprite and animator)
	
	var frames = sprite.hframes * sprite.vframes
	
	var anim_name = sprite.texture.resource_path.get_file().get_basename()
	if not animator.has_animation(anim_name):
		animator.add_animation(anim_name, Animation.new())
	
	var animation = animator.get_animation(anim_name)
	animation.length = frames
	
	var base_path = str(animator.get_node(animator.root_node).get_path_to(sprite))
	
	animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(0, base_path + ":frame")
	animation.value_track_set_update_mode(0, Animation.UPDATE_DISCRETE)

	
	for i in frames:
		animation.track_insert_key(0, i, i)
	
	animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(1, base_path + ":texture")
	animation.track_insert_key(1, 0, sprite.texture)
	
	animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(2, base_path + ":hframes")
	animation.track_insert_key(2, 0, sprite.hframes)
	
	animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(3, base_path + ":vframes")
	animation.track_insert_key(3, 0, sprite.vframes)
