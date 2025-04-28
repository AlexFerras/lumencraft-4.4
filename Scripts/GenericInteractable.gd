extends Area2D
class_name GenericInteractable

@export var can_interact := true: set = set_can_interact
@export var one_player_only := false
@export var disable_icon := false

var players_inside: Array
var interacters: Array
var exceptions: Array
var focus: Array

signal interacted(player)

func _ready() -> void:
	Utils.set_collisions(self, Const.PLAYER_COLLISION_LAYER, Utils.ACTIVE)
	connect("area_entered", Callable(self, "on_enter"))
	connect("area_exited", Callable(self, "on_exit"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_INTERNAL_PHYSICS_PROCESS:
		update_interact()
		set_physics_process_internal(false)

func on_enter(area: Area2D):
	var player := Player.get_from_area(area)
	if not player:
		return
	
	if player in exceptions:
		return
	
	if not focus.is_empty() and not player in focus:
		return
	
	players_inside.append(player)
	_player_entered(player)
	refresh_interactions()

func on_exit(area: Area2D):
	var player := Player.get_from_area(area)
	if not player:
		return
	
	players_inside.erase(player)
	_player_exited(player)
	refresh_interactions()

func update_interact():
	if is_inside_tree() and get_tree().paused:
		set_physics_process_internal(true)
		return
	
	players_inside.clear()
	if _can_interact():
		for area in get_overlapping_areas():
			var player := Player.get_from_area(area)
			if player and not player in exceptions and (focus.is_empty() or player in focus):
				players_inside.append(player)
	refresh_interactions()

func refresh_interactions():
	for player in Utils.game.players:
		player.interactables.erase(self)
	
	if not _can_interact():
		return
	
	for player in players_inside:
		player.interactables.append(self)
		if one_player_only:
			break

func _can_interact() -> bool:
	return can_interact

func _interact(player: Player):
	pass

func _set_highlight(player: Player):
	pass

func interact(player: Player):
	_interact(player)
	emit_signal("interacted", player)

func set_can_interact(can: bool):
	can_interact = can
	if is_inside_tree():
		update_interact()

func add_interacter(player: Player):
	interacters.append(player)
	refresh_interacters()

func remove_interacter(player: Player):
	interacters.erase(player)
	refresh_interacters()

func refresh_interacters():
	if interacters.is_empty():
		_set_highlight(null)
	else:
		_set_highlight(interacters.front())

func _player_entered(player: Player):
	pass

func _player_exited(player: Player):
	pass
