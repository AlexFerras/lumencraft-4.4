extends Control

const VERSION = int(preload("res://Tools/version.gd").VERSION)
const SAVE_DIRECTORY = "user://Saves"

@export var hide_autosave: bool
@export var reverse_sort: bool
@export var list_path := "%SaveList"
@export var slot_path := "%SaveSlot"

@onready var list: VBoxContainer = get_node(list_path)
var slot_prefab: PackedScene

var is_any_save: bool
var campaign_slots: Array

func _ready() -> void:
	slot_prefab = Prefab.create(get_node(slot_path))
	refresh()

func refresh():
	for slot in list.get_children():
		if slot.has_meta("slot"):
			slot.queue_free()
	
	var slot_list: Array
	
	var dir : DirAccess = Utils.safe_open(Utils.DIR, SAVE_DIRECTORY)
	if dir:
		dir.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
		
		var f := dir.get_next()
		while not f.is_empty():
			if hide_autosave and (f == "Autosave" or f == "CampaignAutosave"):
				f = dir.get_next()
				continue
			
			if dir.current_is_dir():
				slot_list.append(f)
				
				var dir2 = DirAccess.open(SAVE_DIRECTORY.path_join(f))
				dir2.list_dir_begin() # TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
				
				var f2 := dir2.get_next()
				while not f2.is_empty():
					if f2 == "campaign_progress.tres":
						campaign_slots.append(f)
						break
					
					f2 = dir2.get_next()
				
				dir2.list_dir_end()
			
			f = dir.get_next()
		
		dir.list_dir_end()
	
	slot_list.sort_custom(Callable(self, "sort_slots"))
	
	for slot in slot_list:
		create_save_slot(slot)

func create_save_slot(slot: String) -> Button:
	if not DirAccess.dir_exists_absolute(SAVE_DIRECTORY.path_join(slot)):
		return null
	
	var slot_instance: Button = slot_prefab.instance()
	slot_instance.set_meta("slot", slot)
	
	var slot_data := Save.get_slot_string(slot)
	slot_instance.get_child(0).text = slot_data[0]
	if slot_data[1]:
		is_any_save = true
		slot_instance.set_meta("timestamp", slot_data[1])
		slot_instance.set_meta("game_version", slot_data[2])
		slot_instance.connect("pressed", Callable(self, "click_slot").bind(slot))
		slot_instance.name = slot
	
	list.add_child(slot_instance)
	return slot_instance

func click_slot(slot: String):
	pass

func sort_slots(slot1: String, slot2: String) -> bool:
	
	var mod_time1 = FileAccess.get_modified_time(Save.get_save_dir(slot1).path_join("data.tres"))
	var mod_time2 = FileAccess.get_modified_time(Save.get_save_dir(slot2).path_join("data.tres"))
	
	if mod_time1 == mod_time2: # bug
		return slot1.casecmp_to(slot2) < 0
	
	return (mod_time1 < mod_time2) != (not reverse_sort)

func _notification(what: int) -> void:
	if not is_visible_in_tree():
		return
	
	if what == NOTIFICATION_THEME_CHANGED:
		for slot in list.get_children():
			if not slot.has_meta("slot"):
				continue
			slot.get_child(0).text = Save.get_slot_string(slot.get_meta("slot"))[0]
