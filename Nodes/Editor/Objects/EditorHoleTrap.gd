@tool
extends EditorObject

func _init_data():
	defaults.enemy = "Swarm/Spider Swarm"
	defaults.enemy_count = 10
	defaults.max_enemies_at_once = 6
	defaults.spawn_batch = 3
	defaults.spawn_interval = 1.0
	defaults.auto_trigger = true

func _configure(editor):
	var texture_rect := TextureRect.new()
	texture_rect.texture = get_enemy_texture()
	texture_rect.expand = true
	texture_rect.custom_minimum_size = Vector2(50, 50)
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	editor.add_object_setting(texture_rect)
	
	var label := Label.new()
	label.autowrap = true
	label.text = "Select a monster from the enemy list and Ctrl+click this object to assign it."
	editor.add_object_setting(label)
	
	create_checkbox(editor, "Triggered by Player?", "auto_trigger")
	create_numeric_input(editor, "Enemy Count", "enemy_count")
	create_numeric_input(editor, "Max Enemies at Once", "max_enemies_at_once")
	create_numeric_input(editor, "Spawn Batch", "spawn_batch")
	
	var interval := create_numeric_input(editor, "Spawn Interval", "spawn_interval", 0.1, 300)
	interval.step = 0.1
	interval.value = object_data.spawn_interval
	interval.suffix = "s"

func on_radius_changed(value):
	object_data.radius = value
	emit_signal("data_changed")
	_refresh()

func _get_tooltip() -> Control:
	var texture_rect := TextureRect.new()
	texture_rect.texture = get_enemy_texture()
	texture_rect.expand = true
	texture_rect.custom_minimum_size = Vector2(50, 50)
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return texture_rect

func _push_object(object: EditorObject) -> bool:
	if object.object_type == "Enemy":
		object_data.enemy = object.object_name
		emit_signal("data_changed")
		tooltip_dirty = true
	elif object.object_type == "Enemy Swarm":
		object_data.enemy = "Swarm/" + object.object_name
		emit_signal("data_changed")
		tooltip_dirty = true
	return tooltip_dirty

func get_enemy_texture() -> Texture2D:
	if object_data.enemy.begins_with("Swarm"):
		return Utils.editor.get_object_icon("EnemiesGroup", object_data.enemy.get_slice("/", 1))
	else:
		return load(Const.Enemies[object_data.enemy].placeholder_sprite) as Texture2D

func get_condition_list() -> Array:
	return ["triggered"]

func action_get_events() -> Array:
	return ["trigger_trap"]
