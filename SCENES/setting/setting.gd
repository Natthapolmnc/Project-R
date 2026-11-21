extends Node


var slash_key: Button
var parry_key: Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	slash_key = $PanelContainer/VBoxContainer/HBoxContainer/SlashKey
	parry_key = $PanelContainer/VBoxContainer/HBoxContainer2/ParryKey


func on_back_button_pressed() -> void:
	SceneManager.change_scene("res://SCENES/main_menu/main_menu.tscn")
