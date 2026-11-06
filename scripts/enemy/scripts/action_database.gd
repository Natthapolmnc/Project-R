class_name ActionDatabase
extends Resource


@export var possible_next_trick: Dictionary[StringName, Array] = {}
@export var possible_next_attack: Dictionary[StringName, Array] = {}
@export var possible_next_idle: Dictionary[StringName, Array] = {}

@export var all_tricks: Array[StringName] = []
@export var all_attack: Array[StringName] = []
@export var all_idle: Array[StringName] = []

func random_attack() -> StringName:
	if (all_attack.is_empty()):
		return ""
	return all_attack.pick_random()

func random_trick() -> StringName:
	if (all_attack.is_empty()):
		return ""
	return all_tricks.pick_random()


func get_next_attack(previous: StringName) -> StringName:
	return possible_next_attack[previous].pick_random()

func get_next_trick(previous: StringName) -> StringName:
	return possible_next_trick[previous].pick_random()
