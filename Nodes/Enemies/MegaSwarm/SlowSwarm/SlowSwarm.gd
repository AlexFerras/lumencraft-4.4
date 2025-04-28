@tool
extends SwarmSpider
func setup_attacks():
	addNewAttack(attack_range, attack_delay, self, "terrain_attack", 192.0, attacks_terrain, true, true, 0.5, 3*PI/4)
