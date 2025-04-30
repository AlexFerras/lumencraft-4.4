extends RefCounted

enum Dir {U, R, D, L}
const OPPOSITE = [Dir.D, Dir.L, Dir.U, Dir.R]
const MIRRORED = [Dir.U, Dir.L, Dir.D, Dir.R]
const SHIFT = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]

const PIECE_DATA = []

var bounds: Vector2
var pieces: Array
var place_queue: Array
var finish: bool

var draw_color := Color.WHITE

var final_image: Image
var final_texture: Texture2D
var world_offset: Vector2

signal bake_finished

func _init() -> void:
	if PIECE_DATA.is_empty():
		var dir = DirAccess.open("res://Nodes/Map/Generator/MapPieces")
		dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
		
		var file := dir.get_next()
		while not file.is_empty():
			if file.begins_with("Piece"):
				PIECE_DATA.append(load(dir.get_current_dir().path_join(file)))
			file = dir.get_next()

func reset():
	pieces.clear()
	finish = false
	final_texture = null

func generate(from: Vector2, size_limit: int):
	assert(pieces.is_empty())
	generate_piece(from)
	
	for i in 1000:
		while not place_queue.is_empty():
			var spot: Vector2 = place_queue.pop_back()
			if get_piece_at(spot):
				continue
			
			generate_piece(spot)
			if pieces.size() > size_limit:
				finish = true
		
		if pieces.size() >= 10:
			break
		
		var replace = pieces[randi() % pieces.size()]
		pieces.erase(replace)
		generate_piece(replace.position)

func generate_piece(pos: Vector2):
	var need_exits: Array
	var locked_exits: Array
	var blocked_pieces: Array
	
	for i in 4:
		var piece := get_piece_at(pos + SHIFT[i])
		if piece:
			blocked_pieces.append(piece.piece)
			
			if OPPOSITE[i] in piece.get_exits():
				need_exits.append(i)
			else:
				locked_exits.append(i)
		elif bounds != Vector2() and not Rect2(Vector2(), bounds).has_point(pos + SHIFT[i]):
			locked_exits.append(i)
		elif finish:
			locked_exits.append(i)
	
	var piece := get_random_piece(blocked_pieces, need_exits, locked_exits)
	if not piece:
		return
	
	piece.position = pos
	piece.cache_texture()
	pieces.append(piece)
	place_queue.append_array(piece.get_neighbors(locked_exits))

func get_random_piece(blocked_pieces: Array, need_exits: Array, locked_exits: Array) -> Piece:
	var possible: Array
	
	for i in PIECE_DATA.size():
		if PIECE_DATA[i] in blocked_pieces:
			continue
		
		for j in 4:
			for k in 2:
				var piece := Piece.new()
				piece.piece = PIECE_DATA[i]
				
				if piece.validate(need_exits, locked_exits):
					possible.append(piece)
	
	if possible.is_empty():
		if not blocked_pieces.is_empty():
			return get_random_piece([], need_exits, locked_exits)
		else:
			return null
	
	return possible[randi() % possible.size()]

func get_piece_at(pos: Vector2) -> Piece:
	for piece in pieces:
		if piece.position == pos:
			return piece
	return null

func bake() -> CanvasItem:
	if final_texture:
		return null
	
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	
	for piece in pieces:
		min_pos.x = min(min_pos.x, piece.position.x)
		min_pos.y = min(min_pos.y, piece.position.y)
		max_pos.x = max(max_pos.x, piece.position.x)
		max_pos.y = max(max_pos.y, piece.position.y)
	
#	var rect := Rect2(min_pos, max_pos - min_pos + Vector2.ONE)
	
	for piece in pieces:
		piece.position -= min_pos
	
	var inner_size := (max_pos - min_pos + Vector2.ONE) * Piece.PIECE_SIZE
#	var size := max(nearest_po2(inner_size.x), nearest_po2(inner_size.y))
	var size := inner_size
	if true: # TODO: opcjonalnie
		size = Vector2.ONE * max(inner_size.x, inner_size.y)
	world_offset = size * 0.5 - inner_size * 0.5
	
	var viewport := SubViewport.new()
	viewport.size = size
	#viewport.usage = SubViewport.USAGE_2D
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.render_target_v_flip = true
	viewport.own_world = true
	viewport.transparent_bg = true
	
	var viewport_container := SubViewportContainer.new()
	viewport_container.size = size
#	viewport_container.rect_position = world_offset
	
	var viewport2 := SubViewport.new()
	viewport2.size = size
	#viewport2.usage = SubViewport.USAGE_2D
	viewport2.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport2.own_world = true
	viewport.transparent_bg = true
	
	var canvas := Node2D.new()
	canvas.connect("draw", Callable(self, "draw_bake").bind(canvas, viewport))
	
	viewport2.add_child(canvas)
	viewport_container.add_child(viewport2)
	viewport.add_child(viewport_container)
	Utils.add_child(viewport)
	
	return canvas

func bake_terrain(material: int):
	final_texture = null
	
	draw_color = Color(1, material / 255.0, 255 if material == Const.Materials.TAR else 0, 1)
	var canvas := bake()
	canvas.modulate = draw_color
	canvas.get_parent().get_parent().material = preload("res://Nodes/Map/Generator/RemoveBlack.material")

func draw_bake(canvas: CanvasItem, viewport: SubViewport):
	canvas.draw_rect(Rect2(Vector2(), viewport.size), Color.WHITE)
	
	for piece in pieces:
		piece.draw(canvas)
	
	await RenderingServer.frame_post_draw
	
	final_image = viewport.get_texture().get_data()
	final_texture = ImageTexture.new()
	final_texture.create_from_image(final_image)
	viewport.queue_free()
	
	if canvas.material:
		draw_color = Color.WHITE
		canvas.modulate = Color.WHITE
		canvas.material = null
	
	emit_signal("bake_finished")

class Piece:
	const PIECE_SIZE = Vector2(256, 256)

	var piece: MapPiece
	var position: Vector2
	var borders: Array
	
	var cached_texture: Texture2D
	
	func _init() -> void:
		borders.resize(4)
		borders.fill(0)
	
	func get_neighbors(locked := []) -> Array:
		var neighs: Array
		for e in get_exits():
			if not e in locked:
				neighs.append(position + SHIFT[e])
		
		return neighs
	
	func get_exits() -> Array:
		var exits: Array
		
		for i in 4:
			if borders[i] != 0:
				exits.append(i)
		
		return exits
	
	func validate(need_exits: Array, locked_exits: Array) -> bool:
		for i in 4:
			if i in need_exits or not i in locked_exits and randi() % 3 == 0:
				borders[i] = -1
		
		return true
	
	func cache_texture():
		cached_texture = piece.get_merged_texture(borders)
	
	func draw(canvas: CanvasItem):
		canvas.draw_texture_rect(cached_texture, Rect2(position * PIECE_SIZE, PIECE_SIZE), false)
	
	func get_center() -> Vector2:
		return (position + Vector2(0.5, 0.5)) * PIECE_SIZE
