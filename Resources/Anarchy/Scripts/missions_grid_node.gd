@tool
extends Control

@export var map_id: String = "": set = set_map_id
@export var connects_to: int = 0 # (int, FLAGS, "Down", "Left", "Right")
@export var big: bool

enum NODE_STATE {AVAIL, COMPLETED, LOCKED}
var currentState = NODE_STATE.AVAIL
var depends: Array

signal selected

func _ready():
	if Engine.is_editor_hint():
		return
	
#	if big:
#		modulate = Color(0.760784, 0.180392, 0.541176)
#		$ring4.show()
	
	update_state()

func update_state():
	for i in 3:
		set_ring_color(i + 1, false)
	
	if currentState == NODE_STATE.COMPLETED:
		$Finished.show()

func set_ring_color(idx: int, hover: bool):
	var ring: Control = get_node("ring%s" % idx)
	
	match currentState:
		NODE_STATE.AVAIL:
			if hover and idx == 1:
				ring.self_modulate = Color(0.64, 1.0, 0.93, 1.0)
			elif hover and idx == 2:
				ring.self_modulate = Color(1.0, 0.72, 0.0, 1.0)
			else:
				if big:
					ring.self_modulate = Color(1, 0.415686, 0.439216)
				else:
					ring.self_modulate = Color(0.04, 0.63, 0.52, 1.0)
		NODE_STATE.COMPLETED:
			if idx == 3:
				ring.self_modulate = Color(1.0, 0.72, 0.0, 1.0)
			elif hover and idx == 1:
				ring.self_modulate = Color(0.64, 1.0, 0.93, 1.0)
			elif hover and idx == 2:
				ring.self_modulate = Color(1.0, 0.72, 0.0, 1.0)
			else:
				if big:
					ring.self_modulate = Color(1, 0.415686, 0.439216)
				else:
					ring.self_modulate = Color(0.04, 0.63, 0.52, 1.0)
		NODE_STATE.LOCKED:
			if hover and idx == 1:
				ring.self_modulate = Color(0.72, 0.72, 0.72, 1.0)
			elif hover and idx == 2:
				ring.self_modulate = Color(0.72, 0.72, 0.72, 1.0)
			else:
				ring.self_modulate = Color(0.42, 0.42, 0.42, 1.0)

func set_map_id(id: String):
	map_id = id
	
	if not Engine.is_editor_hint():
		return
	
	if map_id.is_empty():
		$grad.modulate = Color.WHITE
	else:
		$grad.modulate = Color.TURQUOISE * 10

func _on_Button_mouse_entered():
	set_ring_color(1, true)
	
	match currentState:
		NODE_STATE.AVAIL:
			$grad.set_self_modulate(Color(0.64, 1.0, 0.93, 0.8))
		NODE_STATE.COMPLETED:
			$grad.set_self_modulate(Color(0.64, 1.0, 0.93, 0.8))
		NODE_STATE.LOCKED:
			$grad.set_self_modulate(Color(0.54, 0.54, 0.54, 0.8))	

func _on_Button_mouse_exited():
	set_ring_color(1, false)
	
	match currentState:
		NODE_STATE.AVAIL:
			$grad.set_self_modulate(Color(0.64, 1.0, 0.93, 0.2))
		NODE_STATE.COMPLETED:
			$grad.set_self_modulate(Color(0.64, 1.0, 0.93, 0.2))
		NODE_STATE.LOCKED:
			$grad.set_self_modulate(Color(0.54, 0.54, 0.54, 0.2))	

func _on_Button_toggled(button_pressed):
	if button_pressed:
		$AnimationPlayer.play("bongo")
		emit_signal("selected")
	else:
		$AnimationPlayer.stop(false)
	
	set_ring_color(2, button_pressed)

func make_unused():
	modulate.a = 0
	$Button.focus_mode = Control.FOCUS_NONE

func set_group(group: ButtonGroup):
	$Button.group = group

func get_coords() -> Vector2:
	return Vector2(get_index() % get_parent().columns, get_index() / get_parent().columns)

func select():
	$Button.button_pressed = true
	await get_tree().process_frame
	$Button.grab_focus()

func is_unlocked():
	return currentState != NODE_STATE.LOCKED

func is_finished() -> bool:
	return Save.campaign.is_level_completed(map_id)

func set_neighbor(neighbor: String, control: Control):
	$Button.set("focus_neighbour_%s" % neighbor, $Button.get_path_to(control.get_node("Button")))
