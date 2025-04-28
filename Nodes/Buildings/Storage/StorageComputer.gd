@tool
extends "res://Nodes/Buildings/Common/Computer/GenericComputer.gd"

@onready var storage := get_parent() as BaseBuilding
@onready var icon2 := $computer/icon

enum Mode {LUMEN, SCRAPS}
@export var mode: Mode

var releasing: bool

func _ready() -> void:
	set_physics_process(false)

func _setup():
	if not active:
		return
	
	if mode == Mode.LUMEN:
		screen.set_title("Store Lumen")
	elif mode == Mode.SCRAPS:
		screen.set_title("Store metal")
	
	screen.set_icon(icon2.texture)
	if storage.get_free_storage() > 0:
		screen.set_interact_action("Store")
	screen.set_long_action("Extract")

func _make():
	var store_amount = min(50, storage.get_free_storage())
	if mode == Mode.LUMEN:
		var not_have = screen.current_player.subtract_item(Const.ItemIDs.LUMEN, store_amount)
		storage.store_lumen(store_amount - not_have)
	elif mode == Mode.SCRAPS:
		var not_have = screen.current_player.subtract_item(Const.ItemIDs.METAL_SCRAP, store_amount)
		storage.store_metal(store_amount-not_have)

func _physics_process(delta):
	if releasing:
		if mode == Mode.LUMEN:
			storage.release_lumen()
		elif mode == Mode.SCRAPS:
			storage.release_metal()

func _long_make():
	releasing = true
	set_physics_process(true)

func _release_long_make():
	releasing = false
	set_physics_process(false)
	
