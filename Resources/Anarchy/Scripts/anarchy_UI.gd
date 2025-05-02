@tool
extends CanvasLayer

@export var show_all: bool: set = set_show
@export var hide_all: bool: set = set_hide

func _ready():
#	for node in $InventoryItemsInGameGroup.get_children():
#		node.get_node("AnimationPlayer").play("loop")
#	$WarningWindow/VBoxContainer/PanelContainer/MarginContainer2/VBoxContainer/HBoxContainer/ButtonOk.grab_focus()
	pass # Replace with function body.

func _on_playshow_pressed():
	for node in $ExampleUI.get_children():
		node.show()
		node.showme()

func _on_playhide_pressed():
	for node in $ExampleUI.get_children():
		node.hideme()

func set_show(s):
	if s:
		propagate_call("play", ["show"])
		
func set_hide(s):
	if s:
		propagate_call("play_backwards", ["show"])
