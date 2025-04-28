extends CanvasLayer

func start() -> void:
	if Music.is_switch_build():
		$"%VideoStreamPlayer".hide()
		$"%VideoStreamPlayer".stream = null
	else:
		$"%VideoStreamPlayer".play()
