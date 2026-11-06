class_name SequenceGenerator
extends Resource

@export_category("LEVEL SCALING")
@export var trick_scaling: Dictionary = { 1: 1, 2: 2, 3: 2 }
@export var attack_scaling: Dictionary = { 1: 1, 2: 1, 3: 2 }


var distributed_duration: float  ## Full time duration distributed to this enemy


func roll_sequence(level: int) -> Array:
	var trick_size = trick_scaling[level]
	var attack_size = attack_scaling[level]
	var timestamp: Array[int]
	
	for i in range(0, trick_size + attack_size):
		var stamp: float = range(0, distributed_duration).pick_random()
		while timestamp.has(stamp):
			stamp = range(0, distributed_duration).pick_random()
		timestamp.append(stamp)
	
	timestamp.sort_custom(func(a, b): return a > b)
	
	return roll_sequence2(timestamp, trick_size, attack_size)

func roll_sequence2(timestamp: Array[int], trick_size: int, attack_size: int) -> Array:
	var sequence: Array[String] = []
	var total_act: Array[String] = []
	for t in trick_size:
		total_act.append("t")
	for a in attack_size - 1:
		total_act.append("s")
	
	for i in range(0, timestamp.size):
		var next_stamp: int = timestamp.pop_front()
		var next_act: String = total_act.pop_front() if not total_act.is_empty() else "s"
		
		sequence.append(str(next_stamp) + "," + next_act)
	
	return sequence


func duration_receive(duration: float) -> void:
	distributed_duration = duration


func get_duration() -> float:
	return distributed_duration
