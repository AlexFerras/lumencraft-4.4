extends PanelContainer

var current_enemy: BaseEnemy
var data: Dictionary

func inspect(enemy: BaseEnemy):
	current_enemy = enemy
	show()
	data = enemy.enemy_data
	set_process(true)

func _process(delta):
	if is_instance_valid(current_enemy):
		if current_enemy.has_method("_debug_process"):
			current_enemy.call("_debug_process")

		set_text("NodeName", "Node name", current_enemy.name)
		set_text("EnemyName", "Name", data.get("name", "N/A"))
		set_text("EnemyHP", "HP", str(current_enemy.hp, " / ", current_enemy.max_hp))
		set_text("EnemyThreat", "Threat", data.get("threat", "N/A"))
		set_text("EnemyDamage", "Damage", data.get("damage", "N/A"))
		set_text("EnemyFlags", "Flags", str(get_flag(data, "evade_heavy"), get_flag(data, "resist_weak")))
		set_text("EnemyCustom", "Debug", str(current_enemy._debug_get_text() if current_enemy.has_method("_debug_get_text") else "N/A"))
	else:
		set_process(false)

func set_text(label, field, value):
	$VBoxContainer.get_node(label).text = str(field, ": ", value)

func get_flag(fdata, flag):
	if flag in fdata:
		return str(" ", flag, " ")
	else:
		return ""
