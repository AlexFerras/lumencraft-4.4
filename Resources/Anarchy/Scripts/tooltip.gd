extends PanelContainer

@export var assigned_action: String
@export var assigned_text: String
@export var ignore_mouse: bool

func _ready() -> void:
	if not assigned_action.is_empty():
		set_action(assigned_action)
		set_text(assigned_text)
		set_hold(false)

func showme():
	$AnimationPlayer.play("show")

func hideme():
	$AnimationPlayer.play_backwards("show")

func set_action(action: String):
	for i in $"%MainHB".get_child_count():
		var control: Control = $"%MainHB".get_child(i)
		match i:
			0, 8:
				pass
			3:
				control.action_name = action
				control.favor_mouse = not ignore_mouse
				control.refresh()
			_:
				control.hide()

func set_text(text: String):
	$"%TooltipText".text = text

func set_hold(hold: bool):
	$"%Hold".visible = hold
