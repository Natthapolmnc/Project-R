
extends Node




var slash_key: Button
var parry_key: Button


# ------ Audio Settings ------

func _ready() -> void:
	slash_key = $HBoxContainer/SlashKey
	parry_key = $HBoxContainer2/ParryKey


func on_back_button_pressed() -> void:
	SceneManager.change_scene("res://SCENES/main_menu/main_menu.tscn")


func _on_maxter_slider_value_changed(value: float) -> void:
	AudioPlayer.set_bus_volume("Master", value)


func _on_music_slider_value_changed(value: float) -> void:
	AudioPlayer.set_bus_volume("Music", value)


func _on_sfx_slider_value_changed(value: float) -> void:
	AudioPlayer.set_bus_volume("SFX", value)
