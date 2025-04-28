extends "res://Nodes/Buildings/Common/Computer/GenericComputer.gd"

@export var upgrade: String
@export var description: String # (String, MULTILINE)
@export var prices = [50, 100, 150, 200]

@onready var farm := get_parent() as BaseBuilding

func _setup():
	if is_max():
		set_finished_item()
		return
	
	if active:
		screen.add_cost(Const.ItemIDs.METAL_SCRAP, prices[get_level()])
		screen.set_title(tr(upgrade) + " " + str(get_level()))
		screen.set_description(description)
		screen.set_icon(icon_node.texture)
		screen.set_interact_action("Upgrade")

func _make():
	do_upgrade()
	if is_max():
		set_finished_item()
	else:
		reload()

func do_upgrade():
	pass

func get_level() -> int:
	return 0

func is_max() -> bool:
	return false
