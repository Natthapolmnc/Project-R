extends Node

@onready var parry_success: AudioStreamPlayer = $ParrySuccess
@onready var parry: AudioStreamPlayer = $Parry
@onready var slash: AudioStreamPlayer = $Slash
@onready var slash_2: AudioStreamPlayer = $Slash2
@onready var slash_fail: AudioStreamPlayer = $Slash_fail

@onready var bgm: AudioStreamPlayer

@export_range(0.0, 1.0, 0.05) var max_volume: float = 0.5

func set_bus_volume(bus_name: String, value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)

	if bus_index == -1:
		push_warning("Audio bus not found: " + bus_name)
		return

	var volume: float = clampf(value * max_volume, 0.0, 1.0)

	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(volume)
	)


func _ready() -> void:
	set_bus_volume("Master", 1)
	set_bus_volume("Music", 0.7)
	set_bus_volume("SFX", 1)


func play_slash() -> void:
	var slashes: Array[AudioStreamPlayer] = [slash, slash_2]
	slashes.pick_random().play()

func play_parry() -> void:
	parry.play()

func play_parry_success() -> void:
	parry_success.play()

func play_slash_fail() -> void:
	slash_fail.play()
