extends CanvasLayer


signal next_level_pressed
signal retry_cur_level_pressed

var next_level: Button


func _ready() -> void:
	next_level = $NextLevel
	visible = false


func _on_retry_pressed() -> void:
	retry_cur_level_pressed.emit()
	visible = false


func _on_main_menu_pressed() -> void:
	SceneManager.change_scene("res://SCENES/main_menu/main_menu.tscn")



func _on_next_level_pressed() -> void:
	visible = false
	next_level_pressed.emit()


func set_advance(value: bool) -> void:
	if value == true:
		next_level.visible = true
		return
	
	next_level.visible = false
