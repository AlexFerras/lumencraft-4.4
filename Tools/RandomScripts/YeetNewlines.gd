@tool
extends EditorScript

func _run() -> void:
	var text = """Special rules for this map:
- Darkness is persistent and [color=#ff9010]light[/color] scares off monsters. Avoid shadows and use flares often.
- [color=#a000ff][shake rate=60 level=15]Fear[/shake][/color] system. When in darkness for too long, enemies will start to spawn and stalk you and your aim will be impaired.
- Sprinting and dashing is disabled.
- Your pistol has unlimited ammo, but requires reload if you have no bullets in your inventory.
- [color=#a000ff]Reactor Fuel[/color] system [img]res://Nodes/Unique/PowerBar.png[/img]
Keep supplying Lumens to your reactor. Depending on the power level:
	in [color=#dc2d54]red[/color] - buildings do not operate,
	in [color=#007b5b]green[/color] - normal operation,
	in [color=#09a17a]bright green[/color] - overdrive, extended range, buildings regenerate.

Victory conditions:
- Bring 3 Lumen chunks to the reactor.
- Survive 10th wave."""
	
	print(text.split("\n""\\n".join()).replace("\t", "\\t"))
