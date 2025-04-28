extends Node2D
class_name GenericVehicle

var player: Player

var player_in: bool
var driving: bool
var velocity: Vector2

func _ready() -> void:
	var enter := $EnterArea as Area2D
	enter.connect("area_entered", Callable(self, "area_enter"))
	enter.connect("area_exited", Callable(self, "area_exit"))
	assign_player(Utils.game.main_player) ## multiplayer

func assign_player(p: Player):
	player = p

func area_enter(area: Area2D):
	if Player.get_from_area(area):
		player_in = true

func area_exit(area: Area2D):
	if Player.get_from_area(area):
		player_in = false

func _input(event: InputEvent) -> void:
	if not player_in and not driving:
		return
	
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_SPACE:
			if driving:
				driving = false
				player.exit_vehicle()
				exit_player()
			else:
				driving = true
				player.enter_vehicle()
				enter_player()

func enter_player():
	pass

func exit_player():
	pass
