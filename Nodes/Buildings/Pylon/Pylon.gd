extends BaseBuilding

signal lost_power

const RANGE = 120.0

@onready var animator := $AnimationPlayer as AnimationPlayer
@onready var lights := $Lights

func add_to_tracker():
	Utils.add_to_tracker(self, Utils.game.map.power_expander_buildings_tracker, radius, 999999)


			
func apply_mask(type):
	if type==Const.Materials.STOP:
		type=Const.Materials.LOW_BUILDING
	super.apply_mask(type)

func set_disabled(disabled: bool, force := false):
	super.set_disabled(disabled, force)
	if disabled:
		$AnimationPlayer.play("PowerOFF")
		emit_signal("lost_power")
		init_range_extender(0.0)
	else:
		$AnimationPlayer.play("PowerON")
		init_range_extender(RANGE)
	
	if force:
		$AnimationPlayer.advance(99999)
		
		
func destroy(explode := true):
	super.destroy(explode)
	Utils.game.map.post_process.set_deferred("range_dirty", true)
