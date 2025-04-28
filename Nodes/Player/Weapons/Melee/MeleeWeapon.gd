extends Node2D

var player: Player
var data: Dictionary
var damage_data: Dictionary
var is_attacking_on_start: bool

func set_player(p: Player):
	player = p
	is_attacking_on_start = is_player_melee_attacking()

func init(id: int, collider: Area2D):
	## można podpiąć jakiś sygnał w razie upgradu
	data = player.get_upgraded_data(Const.Items[id])
	damage_data = {damage = get_damage_with_powered_stand(data.damage)}
	Utils.init_player_projectile(self, collider, damage_data)

func is_player_melee_attacking():
	return not player.tired and player.is_just_shooting()

func use_stamina():
	player.expend_stamina(data.stamina_cost)

func use_all_stamina():
	player.expend_stamina(player.stamina)

func get_damage_with_powered_stand(damage: int):
	return damage + ceil(damage * (0.2 if player.on_stand >= 2 else 0.0))
