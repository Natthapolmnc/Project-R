class_name CharacterResource
extends Resource


@export var base_hp: int = 1
var cur_hp: int=base_hp
@export var max_stab: int = 1
var cur_stab:int=max_stab

# ----- TRICKS & THREATS -----


func on_start() -> void:
	cur_hp = get_base_hp()


func on_being_finished() -> void:
	cur_hp = maxi(cur_hp - 1, 0)

func recover_from_down() -> void:
	cur_stab = max_stab

func is_dead() -> bool:
	return cur_hp == 0

func get_hp() -> int:
	return cur_hp

func get_base_hp() -> int:
	return base_hp
