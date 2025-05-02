extends TextureButton

var COLOR_ACTIVE: Color
var COLOR_ACTIVE_ICON: Color
var COLOR_INACTIVE: Color
var COLOR_INACTIVE_ICON: Color

var COLOR_ACTIVE_CANT_AFFORD: Color
var COLOR_ACTIVE_ICON_CANT_AFFORD: Color
var COLOR_INACTIVE_CANT_AFFORD: Color
var COLOR_INACTIVE_ICON_CANT_AFFORD: Color

@onready var center: Control = $Center

var active: bool
var can_afford: bool: set = set_can_afford

func _ready() -> void:
	COLOR_ACTIVE = Const.UI_MAIN_COLOR
	COLOR_ACTIVE_ICON = Const.UI_MAIN_COLOR
	COLOR_INACTIVE = Color("#1e1b15ef")
	COLOR_INACTIVE_ICON = Color.WHITE

	COLOR_ACTIVE_CANT_AFFORD = Const.UI_MAIN_COLOR
	COLOR_ACTIVE_ICON_CANT_AFFORD = Const.UI_MAIN_COLOR
	COLOR_INACTIVE_CANT_AFFORD = Color("403e3b")
	COLOR_INACTIVE_ICON_CANT_AFFORD = Color("616161")

func _on_PieRow1Button_mouse_entered():
	make_active()

func _on_PieRow1Button_mouse_exited():
	make_disactive()

func _on_PieRow1Button_focus_entered():
	make_active()

func _on_PieRow1Button_focus_exited():
	make_disactive()

func make_active():
	active = true
	update_colors()

func make_disactive():
	active = false
	update_colors()

func set_can_afford(c: bool):
	can_afford = c
	update_colors()

func update_colors():
	if not has_node("Icon"): ## ??
		return
	
	if active:
		$Select.self_modulate = COLOR_ACTIVE if can_afford else COLOR_ACTIVE_CANT_AFFORD
		$Icon.self_modulate = COLOR_ACTIVE_ICON if can_afford else COLOR_ACTIVE_ICON_CANT_AFFORD
	else:
		$Select.self_modulate = COLOR_INACTIVE if can_afford else COLOR_INACTIVE_CANT_AFFORD
		$Icon.self_modulate = COLOR_INACTIVE_ICON if can_afford else COLOR_INACTIVE_ICON_CANT_AFFORD
	$Center.modulate = $Icon.self_modulate

func _on_PieButton_toggled(button_pressed):
	if button_pressed:
		make_active()
	else:
		make_disactive()
