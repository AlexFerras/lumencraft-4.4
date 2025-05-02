@tool
extends EditorScript

enum {R, G, B, A}

const PIXEL_MAP = "Floor2"
const FROM_CHANNEL = A
const TO_CHANNEL = B

func _run() -> void:
	RealPodmieniacz.podmien_channel(get_editor_interface().get_edited_scene_root().get_node(PIXEL_MAP), FROM_CHANNEL, TO_CHANNEL)

class RealPodmieniacz:
	static func podmien_channel(pixelmap: PixelMap, from: int, to: int):
		var w: int = pixelmap.get_texture().get_width()
		
		var pixel_data = pixelmap.get_pixel_data()
		for x in w:
			for y in pixelmap.get_texture().get_height():
				var idx: int = (x + y * w) * 4
				pixel_data[idx + to] = pixel_data[idx + from]
				pixel_data[idx + from] = 0
		
		pixelmap.set_pixel_data(pixel_data, pixelmap.get_texture().get_size())
