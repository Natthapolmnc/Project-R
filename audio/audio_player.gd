extends Node

@onready var parry_success: AudioStreamPlayer = $ParrySuccess
@onready var parry: AudioStreamPlayer = $Parry
@onready var slash: AudioStreamPlayer = $Slash
@onready var slash_2: AudioStreamPlayer = $Slash2
@onready var slash_fail: AudioStreamPlayer = $Slash_fail

@onready var bgm: AudioStreamPlayer




func play_slash() -> void:
	var slashes: Array[AudioStreamPlayer] = [slash, slash_2]
	slashes.pick_random().play()

func play_parry() -> void:
	parry.play()

func play_parry_success() -> void:
	parry_success.play()

func play_slash_fail() -> void:
	slash_fail.play()
