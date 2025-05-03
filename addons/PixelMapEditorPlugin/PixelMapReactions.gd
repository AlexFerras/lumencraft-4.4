@tool
extends Control

var plugin: EditorPlugin

@onready var reactions := $VBoxContainer/VBoxContainer

var reaction_prefab: Control

signal reaction_added
signal reaction_updated(idx, mat1, mat2, result)
signal reaction_deleted(idx)

func initialize():
	reaction_prefab = reactions.get_node("Reaction")
	reaction_prefab.get_parent().remove_child(reaction_prefab)

func update_material_list(reaction: Control):
	plugin.update_material_list(reaction.get_node("HBoxContainer/OptionButton"))
	plugin.update_material_list(reaction.get_node("HBoxContainer/OptionButton2"))
	plugin.update_material_list(reaction.get_node("OptionButton"))

func add_reaction(mat1, mat2, result):
	var reaction := reaction_prefab.duplicate()
	reactions.add_child(reaction)
	var idx = reaction.get_child_count() - 1
	
	update_material_list(reaction)
	reaction.get_node("HBoxContainer/OptionButton").selected = mat1
	reaction.get_node("HBoxContainer/OptionButton2").selected = mat2
	reaction.get_node("OptionButton").selected = result
	
	reaction.get_node("HBoxContainer/OptionButton").connect("item_selected", Callable(self, "update_reaction").bind(reaction))
	reaction.get_node("HBoxContainer/OptionButton2").connect("item_selected", Callable(self, "update_reaction").bind(reaction))
	reaction.get_node("OptionButton").connect("item_selected", Callable(self, "update_reaction").bind(reaction))
	reaction.get_node("Button").connect("pressed", Callable(self, "delete_reaction").bind(reaction))

func on_add_pressed() -> void:
	add_reaction(0, 0, 0)
	emit_signal("reaction_added")

func update_reaction(item, reaction: Control):
	emit_signal("reaction_updated", reaction.get_index(), reaction.get_node("HBoxContainer/OptionButton").selected, reaction.get_node("HBoxContainer/OptionButton2").selected, reaction.get_node("OptionButton").selected)

func delete_reaction(reaction: Control):
	var idx := reaction.get_index()
	reactions.get_child(idx).queue_free()
	emit_signal("reaction_deleted", idx)

func clear():
	for i in reactions.get_child_count():
		reactions.get_child(0).free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(reaction_prefab):
			reaction_prefab.free()
