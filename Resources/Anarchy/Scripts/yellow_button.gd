extends Button

func _on_YellowButton_button_down():
	$MainHB2/TooltipText.self_modulate = Color8(0,0,0,255)
	pass # Replace with function body.


func _on_YellowButton_button_up():
	$MainHB2/TooltipText.self_modulate = Color8(255,255,255,255)
	pass # Replace with function body.
