@tool
extends Node2D

var keep_after_finished: bool
var texture: Texture2D

var _size: Vector2
var _bake_pending: bool

signal finished(result)

static func create(size: Vector2):
	var baker = load("res://Scripts/TextureBaker.gd").new()
	baker._size = size
	baker.bake()
	return baker

func add_target(node, offset := Vector2(), duplicate_target := false):
	if node is Texture2D:
		var trect := TextureRect.new()
		trect.texture = node
		duplicate_target = false
		node = trect
	
	var original = node
	if duplicate_target:
		node = node.duplicate()
	elif node.get_parent():
		node.get_parent().remove_child(node)
	
	add_child(node)
	
	if node is Node2D:
		node.position = offset
	elif node is Control:
		node.position = offset

func bake():
	if _bake_pending:
		return
	_bake_pending = true
	
	call_deferred("_bake")

func _bake():
	var viewport := SubViewport.new()
	viewport.size = _size
	viewport.usage = SubViewport.USAGE_2D
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.render_target_v_flip = true
	viewport.own_world = true
	viewport.transparent_bg = true
	
	Const.add_child(viewport)
	viewport.add_child(self)
	
	await RenderingServer.frame_post_draw
	
	texture = ImageTexture.new()
	texture.create_from_image(viewport.get_texture().get_data())
#	texture.get_data().save_png("dupa.png")
	
	emit_signal("finished", texture)
	
	if not keep_after_finished:
		viewport.queue_free()
