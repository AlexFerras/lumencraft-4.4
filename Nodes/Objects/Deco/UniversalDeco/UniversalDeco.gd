extends Node2D

@onready var collider := get_node_or_null("Collider") as Area2D
@onready var on_hit := get_node_or_null("OnHit")
@onready var on_dead := get_node_or_null("OnDead")

@export var max_hp: int
@export var absolute_damage: bool

var hp: int
var dead: bool

signal died

func _ready():
	if collider:
		Utils.set_collisions(collider, Const.ENEMY_COLLISION_LAYER, Utils.PASSIVE)
		collider.connect("area_entered", Callable(self, "on_enter"))
	
	hp = max_hp
	
	Utils.game.map.pixel_map.update_damage_circle(global_position, 30, 999999, 999999) ## TODO: usunąć kiedyś

func on_enter(area: Area2D) -> void:
	if dead:
		return
	
	if area.is_in_group("player_projectile"):
		Utils.on_hit(area)
		
		if absolute_damage:
			hp -= 1
		else:
			var data: Dictionary = area.get_meta("data")
			hp -= data.damage
			if Save.config.show_damage_numbers:
				Utils.game.map.add_dmg_number().setup(self, data.damage, Color.ORANGE_RED)
		
		if hp <= 0:
			dead = true
			emit_signal("died")
			
			if on_dead:
				execute(on_dead)
		else:
			if on_hit:
				execute(on_hit)

func execute(node: Node):
	for action in node.get_children():
		if not can_execute(action):
			continue
		
		if action is CPUParticles2D or action is GPUParticles2D:
			action.emitting = true
		elif action is AudioStreamPlayer2D or action is AudioStreamPlayer:
			action.play()
		elif action is AnimationPlayer:
			if action.is_playing():
				action.stop(true)
				action.advance(0)
			action.play(action.get_animation_list()[0])
		elif action is AnimatedSprite2D:
			action.show()
			if not action.is_connected("animation_finished", Callable(action, "hide")):
				action.connect("animation_finished", Callable(action, "hide"))
			action.frame = 0
			action.play()
		else:
			if action.name.begins_with("AudioGroup"):
				Utils.get_audio_manager(action.get_meta("_editor_description_")).play(self)
			elif action.name == "Free":
				queue_free()
			elif action.name == "KillMe":
				action.queue_free()
			elif action.name == "Execute":
				action.execute()
			elif action.name == "Hide":
				get_node(action.get_meta("_editor_description_")).hide()
			elif action.name.begins_with("ShowMe"):
				action.show()
			else:
				push_error("Zły węzeł, napraw")

func can_execute(action: Node) -> bool:
	if not action.has_meta("_editor_description_"):
		return true
	
	var conditions: PackedStringArray = action.get_meta("_editor_description_").split("\n")
	for condition in conditions:
		if condition == "high_hp" and hp < max_hp * 0.3:
			return false
		elif condition == "low_hp" and hp > max_hp * 0.3:
			return false
	
	return true

func free_on_animation(anim):
	queue_free()

func _get_save_data() -> Dictionary:
	return {dead = dead}

func _set_save_data(data: Dictionary):
	await self.ready
	
	if data.dead:
		dead = true
		if on_dead:
			execute(on_dead)
