extends CanvasLayer


signal retry_cur_level_pressed


func _ready() -> void:
	visible = false


func _on_retry_pressed() -> void:
	retry_cur_level_pressed.emit()
	visible = false


func _on_main_menu_pressed() -> void:
	SceneManager.change_scene("res://SCENES/main_menu/main_menu.tscn")
