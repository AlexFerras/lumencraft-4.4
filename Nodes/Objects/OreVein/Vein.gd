extends Node2D

@export var resource: int = Const.ItemIDs.METAL_SCRAP
@export var count: int = 3000: set = set_count
var used=false

var give_timer=0.0
var hit_counter=0
var miner: BaseBuilding

@onready var glare= $glare
@onready var computer = $VeinComputer

signal miner_placed

func _ready():
	Utils.set_collisions($Detector, Const.ENEMY_COLLISION_LAYER, Utils.PASSIVE)
	Utils.set_collisions(glare, Const.ENEMY_COLLISION_LAYER, Utils.PASSIVE)
	refresh_glare()

func give():
	count -= 1
	Utils.play_sample("res://Nodes/Buildings/Storage/bottle_pop.wav", global_position, false, 1.5)
	var giver = $giver.get_child(randi() % $giver.get_child_count())
	Utils.game.map.pickables.spawn_premium_pickable_nice(giver.global_position,	resource, Vector2.RIGHT.rotated(giver.rotation + randf_range(-0.3, 0.3)) * randf_range(80, 130))

func set_count(new_count):
	count = new_count
	
	if not is_inside_tree():
		await self.ready
	
	computer.reload()
	
	if count<=0 and !used:
		used=true
		computer.set_disabled(true)
		var seq := create_tween()
		seq.tween_property(self, "modulate:a", 0.0, 2.0)
		seq.tween_callback(Callable(self, "queue_free"))

func _physics_process(delta):
	give_timer-=delta

func _on_Detector_area_entered(area):
	if miner:
		return
	if area.is_in_group("player_projectile"):
		area.get_meta("data").blood=false
		Utils.on_hit(area)
		Utils.play_sample(Utils.random_sound("res://SFX/Bullets/pick_axe_stone_small_hit_mine_impact"), global_position,false,1.1,hit_counter*0.05+0.7)

func _on_glare_hit(area):
	if miner or count == 0:
		return
	
	hit_counter+=1
	if hit_counter > 10 and give_timer <= 0.0:
		Utils.play_sample(Utils.random_sound("res://SFX/Player/Mining (Hitting Stone With Pickaxe) 1.wav"), global_position, false, 1.3)
		give_timer=1.0
		hit_counter=0
		give()
		glare.global_position=$giver.get_child(randi()%$giver.get_child_count()).to_global(Vector2(-3,0))
		refresh_glare()

func create_miner():
	miner = preload("res://Nodes/Buildings/Miner/Miner.tscn").instantiate()
	miner.vein = self
	miner.connect("destroyed", Callable(self, "on_miner_destroyed"))
	
	if glare:
		refresh_glare()

func on_miner_destroyed():
	miner = null
	refresh_glare()

func refresh_glare():
	glare.visible = not miner and count > 0
