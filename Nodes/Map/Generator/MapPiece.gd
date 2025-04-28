@tool
extends Resource
class_name MapPiece

const FORMAT = Image.FORMAT_RGBA8

@export var main_image: Image
@export var border_images: Array

var untouched: bool

func setup():
	main_image = create_image(Color.BLACK)
	
	border_images = [[], [], [], []]

func new_border(dir: int):
	border_images[dir].append(create_image(Color(0, 0, 0, 0)))

func create_image(fill: Color) -> Image:
	var image := Image.new()
	image.create(256, 256, false, FORMAT)
	image.fill(fill)
	return image

func get_merged_texture(borders: Array, rng: RandomNumberGenerator = null) -> Texture2D:
	assert(borders.size() == 4)
	
	var image := Image.new()
	image.create(main_image.get_width(), main_image.get_height(), false, FORMAT)
	
	image.blend_rect(main_image, Rect2(Vector2(), main_image.get_size()), Vector2())
	
	for i in 4:
		if borders[i] == 0:
			continue
		
		var idx: int = borders[i]
		if idx <= 0:
			if rng:
				idx = rng.randi() % border_images[i].size()
			else:
				idx = randi() % border_images[i].size()
		image.blend_rect(border_images[i][idx], Rect2(Vector2(), main_image.get_size()), Vector2())
	
	var texture := ImageTexture.new()
	texture.create_from_image(image) #,0
	return texture
