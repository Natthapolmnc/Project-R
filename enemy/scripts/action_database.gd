class_name ActionDatabase
extends Node


@export var possible_next_trick: Dictionary[StringName, Array] = {}
@export var possible_next_attack: Dictionary[StringName, Array] = {}

@export var all_tricks: Array[StringName] = []
@export var all_attack: Array[StringName] = []


func random_attack() -> StringName:
	return all_attack.pick_random()

func random_trick() -> StringName:
	return all_tricks.pick_random()


func get_next_attack(previous: StringName) -> StringName:
	return possible_next_attack[previous].pick_random()

func get_next_trick(previous: StringName) -> StringName:
	return possible_next_trick[previous].pick_random()
