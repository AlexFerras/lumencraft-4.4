extends PanelContainer

signal confirmed
signal was_hidden

func showme():
	show()
	$AnimationPlayer.play("show")

func hideme():
	$AnimationPlayer.play_backwards("show")
	await $AnimationPlayer.animation_finished
	hide()
	await get_tree().idle_frame
	emit_signal("was_hidden")

func _on_ButtonOk_pressed() -> void:
	emit_signal("confirmed")
