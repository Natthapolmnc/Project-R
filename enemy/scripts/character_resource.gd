class_name CharacterResource
extends Resource


@export var base_hp: int = 1
var current_hp: int


# ----- TRICKS & THREATS -----


func on_start() -> void:
	current_hp = get_base_hp()


func on_being_finished() -> void:
	current_hp = maxi(current_hp - 1, 0)


func is_dead() -> bool:
	return current_hp == 0

func get_hp() -> int:
	return current_hp

func get_base_hp() -> int:
	return base_hp
