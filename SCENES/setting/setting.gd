extends Node


var slash_key: Button
var parry_key: Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	slash_key = $HBoxContainer/SlashKey
	parry_key = $HBoxContainer2/ParryKey


func on_back_button_pressed() -> void:
	SceneManager.change_scene("res://SCENES/main_menu/main_menu.tscn")



func _on_maxter_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))


func _on_music_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(value))


func _on_sfx_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value))
