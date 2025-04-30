@tool
extends "res://Nodes/Map/Generator/ChunkGenerator.gd"

enum Dir {U, R, D, L}
const OPPOSITE = [Dir.D, Dir.L, Dir.U, Dir.R]
const SHIFT = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]

const PIECE_DATA = []

var bounds: Vector2
var pieces: Array
var place_queue: Array
var finish: bool
var piece_chances: Dictionary

var draw_color := Color.WHITE

var tunnel_size: Vector2

func _init() -> void:
	if PIECE_DATA.is_empty():
		var dir = DirAccess.open("res://Nodes/Map/Generator/MapPieces")
		dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
		
		var file := dir.get_next()
		while not file.is_empty():
			if file.begins_with("Piece"):
				PIECE_DATA.append(load(dir.get_current_dir().path_join(file)))
			file = dir.get_next()
	
	for piece in PIECE_DATA:
		piece_chances[piece] = 1000

func generate(max_size: Vector2):
#	if max_size.x > 128 and max_size.y > 128:
#		tunnel_size = Vector2(128, 128)
#	else:
#		tunnel_size = Vector2(64, 64)
	
	var tsize: int = min(rng.randf_range(64, 128), min(max_size.x, max_size.y))
	tunnel_size = Vector2.ONE * tsize
	
	bounds = (max_size / tunnel_size).floor()
	var size_limit = rng.randi() % int(bounds.x * bounds.y) + 1
	
	generate_piece(Vector2(rng.randi() % int(bounds.x), rng.randi() % int(bounds.y)))
	
	print(" ===== ")
	for i in 100:
		while not place_queue.is_empty():
			var spot: Vector2 = place_queue.pop_back()
			if get_piece_at(spot):
				continue
			
			generate_piece(spot)
			if pieces.size() > size_limit:
				finish = true
		
		if pieces.size() >= bounds.x * bounds.y * 0.8:
			break
		
		var replace = pieces[rng.randi() % pieces.size()]
		pieces.erase(replace)
		generate_piece(replace.position)
	
	bake()

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
				piece.rng = rng
				
				if piece.validate(need_exits, locked_exits):
					possible.append(piece)
	
	if possible.is_empty():
		if not blocked_pieces.is_empty():
			return get_random_piece([], need_exits, locked_exits)
		else:
			return null
	
	var chances: Dictionary
	for piece in possible:
		chances[piece] = piece_chances[piece.piece]
	
	var piece: Piece
	if Engine.is_editor_hint():
		piece = pick_random_with_chances(chances)
	else:
		piece = Utils.pick_random_with_chances(chances, 0, rng)
	piece_chances[piece.piece] = 0
	
	for p in piece_chances:
		piece_chances[p] += 50
	
	return piece

func get_piece_at(pos: Vector2) -> Piece:
	for piece in pieces:
		if piece.position == pos:
			return piece
	return null

func bake():
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	
	for piece in pieces:
		min_pos.x = min(min_pos.x, piece.position.x)
		min_pos.y = min(min_pos.y, piece.position.y)
		max_pos.x = max(max_pos.x, piece.position.x)
		max_pos.y = max(max_pos.y, piece.position.y)
	
	for piece in pieces:
		piece.position -= min_pos
	
	var inner_size := (max_pos - min_pos + Vector2.ONE) * tunnel_size
	var size := inner_size
	
	var baker = preload("res://Scripts/TextureBaker.gd").create(inner_size)
	for piece in pieces:
		var trect := TextureRect.new()
		trect.texture = piece.cached_texture
		trect.expand = true
		trect.size = tunnel_size
		baker.add_target(trect, piece.position * tunnel_size)
	
	await baker.finished
	
	texture = baker.texture
	material = preload("res://Nodes/Map/Generator/RemoveWhite.material")
	is_ready = true

class Piece:
	const PIECE_SIZE = Vector2(256, 256)

	var piece: MapPiece
	var position: Vector2
	var borders: Array
	
	var cached_texture: Texture2D
	var rng: RandomNumberGenerator
	
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
			if i in need_exits or not i in locked_exits and rng.randi() % 3 == 0:
				borders[i] = -1
		
		return true
	
	func cache_texture():
		cached_texture = piece.get_merged_texture(borders, rng)
	
	func draw(canvas: CanvasItem):
		canvas.draw_texture_rect(cached_texture, Rect2(position * PIECE_SIZE, PIECE_SIZE), false)
	
	func get_center() -> Vector2:
		return (position + Vector2(0.5, 0.5)) * PIECE_SIZE

func create_content(generator, pixel_map: PixelMap) -> Array:
	return generic_create_content(generator, pixel_map)

func pick_random_with_chances(chances: Dictionary, complement := 0):
	chances = chances.duplicate()
	
	var sum := 0
	for p in chances:
		sum += chances[p]
	
	if complement > 0:
		chances[null] = complement - sum
		sum = complement
	
	var keys := chances.keys()
	
	var random := rng.randi() % (sum + 1)
	
	var partial: int = chances[keys[0]]
	var i := 0
	
	while partial < random:
		i += 1
		partial += chances[keys[i]]
	
	return keys[i]
