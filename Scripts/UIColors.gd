extends Node

enum {SCHEME_RAINBOW, SCHEME_GRAYSCALE, SCHEME_DANGER, SCHEME_GLITCH, SCHEME_UV, SCHEME_GHOST, SCHEME_INVISIBLE}
var color_scheme: int

var original_color: Color
var original_color2: Color

func _process(delta: float) -> void:
	match color_scheme:
		SCHEME_RAINBOW:
			var h = Time.get_ticks_msec() * 0.0001
			var h2 = Time.get_ticks_msec() * 0.0001 + 0.5
			Utils.recolor_theme(Color.from_hsv(h, 1, 1), Color.from_hsv(h2, 1, 1))
		SCHEME_GRAYSCALE:
			var v = abs(fmod(Time.get_ticks_msec() * 0.001, 2) - 1)
			var v2 = abs(fmod(Time.get_ticks_msec() * 0.001 + 0.5, 2) - 1)
			Utils.recolor_theme(Color.from_hsv(1, 0, v), Color.from_hsv(1, 0, v2))
		SCHEME_DANGER:
			var c = Color.from_hsv(round(Time.get_ticks_msec() % 1000 * 0.001) * 0.166667, 1, 1)
			Utils.recolor_theme(c, Color.WHITE)
		SCHEME_GLITCH:
			var color1 = Const.UI_MAIN_COLOR
			if randf() < 0.2:
				color1 = Color(randf(), randf(), randf(), randf())
			var color2 = Const.UI_SECONDARY_COLOR
			if randf() < 0.2:
				color2 = Color(randf(), randf(), randf(), randf())
			Utils.recolor_theme(color1, color2)
		SCHEME_UV:
			var uv := get_viewport().get_mouse_position() / get_viewport().get_visible_rect().size
			Utils.recolor_theme(Color(uv.x, uv.y, 1), Color(1, 1 - uv.y, uv.x))
		SCHEME_GHOST:
			if Const.UI_MAIN_COLOR.a == 1:
				_enter_tree()
				var color1 = Const.UI_MAIN_COLOR
				color1.a = 0.5
				var color2 = Const.UI_SECONDARY_COLOR
				color2.a = 0.5
				Utils.recolor_theme(color1, color2)
		SCHEME_INVISIBLE:
			if Const.UI_MAIN_COLOR.a == 1:
				_enter_tree()
				var color1 = Const.UI_MAIN_COLOR
				color1.a = 0.1
				var color2 = Const.UI_SECONDARY_COLOR
				color2.a = 0.1
				Utils.recolor_theme(color1, color2)

func _enter_tree() -> void:
	original_color = Const.UI_MAIN_COLOR
	original_color2 = Const.UI_SECONDARY_COLOR

func _exit_tree() -> void:
	if not get_tree().current_scene:
		return
	
	Utils.recolor_theme(original_color, original_color2)
