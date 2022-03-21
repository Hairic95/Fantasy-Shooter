extends Control


func _process(delta):
	if Input.is_action_just_pressed("ui_accept"):
		EventBus.emit_signal("change_scene", "level_select")

