extends Node2D

@export_node_path("Node") var primary_animator
@export_node_path("Node") var secondary_animator

var reactor_fuel:Node2D
#var reactor_state :int = 1

func _ready():
	if Utils.game.core:
		get_parent().connect("ready", Callable(self, "parent_ready").bind(), CONNECT_ONE_SHOT)
	else:
		Utils.game.connect("map_initialized", Callable(self, "parent_ready").bind(), CONNECT_ONE_SHOT)

func parent_ready():
	if not Utils.game.core or (not Utils.game.core.has_node("ReactorFuel") and Save.current_map != "res://Maps/Campaign/Hub.tscn"):
		queue_free()
	else:
		if  Save.current_map != "res://Maps/Campaign/Hub.tscn":
			reactor_fuel = Utils.game.core.get_node("ReactorFuel")
			reactor_fuel.connect("reactor_state_changed", Callable(self, "reactor_state_changed"))

			primary_animator.connect("animation_finished", Callable(self, "_primary_animation_finished"))
		else:
			primary_animator.connect("animation_finished", Callable(self, "_primary_animation_finished_on_hub"))
			
#			if get_parent().is_running:
#				secondary_animator.play("PowerON")
#				if has_node("LightSprite2"):
#					$LightSprite2.self_modulate.a = 0.05
#				if has_node("LampaHalo3"):
#					$LampaHalo3.self_modulate.a = 0.04


func _primary_animation_finished_on_hub(anim_name):
	if anim_name == "PowerON" and secondary_animator.current_animation != "PowerON":
		secondary_animator.play("PowerON")
		if has_node("LightSprite2"):
			$LightSprite2.self_modulate.a = 0.05
		if has_node("LampaHalo3"):
			$LampaHalo3.self_modulate.a = 0.04

func reactor_state_changed(state):
	_primary_animation_finished("")

func _primary_animation_finished(anim_name):
	match reactor_fuel.reactor_mode:
		0:
			secondary_animator.play("PowerOFF")
			get_parent().regenerate = 0
		1:
			secondary_animator.play("AlarmON")
			get_parent().regenerate = 0
		2:
			secondary_animator.play("PowerON")
			get_parent().regenerate = 1
		3:
			secondary_animator.play("PowerON")
			get_parent().regenerate = 2   
