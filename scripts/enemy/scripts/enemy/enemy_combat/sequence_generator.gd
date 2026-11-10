class_name SequenceGenerator
extends RefCounted

enum SequenceType {
	BALANCED,
	RUSH_THEN_SLOW,
	DELAY_BEFORE_ATTACK,
	BURST_PAUSE,
	SLOW_THEN_RUSH,
	BAIT_AND_STRIKE,
	CHAOTIC
}

const TYPE_NAMES: Array[String] = [
	"balanced", "rush_then_slow", "delay_before_attack", "burst_pause",
	"slow_then_rush", "bait_and_strike", "chaotic"
]

const TRICK_SCALING: Dictionary = {1: 1, 2: 2, 3: 2}
const ATTACK_SCALING: Dictionary = {1: 1, 2: 1, 3: 2}

## Minimum time between the *starts* of moves; raise this for long animations.
const MIN_GAP: float = 0.75


## Returns { "type": String, "sequence": Array[String] }.
## Entries have the format "seconds_since_start,a" or "seconds_since_start,t".
static func generate(level: int, duration: float, sequence_type: int = -1) -> Dictionary:
	var sequence: Array[String] = []
	if not TRICK_SCALING.has(level) or not ATTACK_SCALING.has(level) or duration <= 0.0:
		push_warning("SequenceGenerator: invalid level or duration")
		return {"type": "invalid", "sequence": sequence}

	if sequence_type == -1:
		sequence_type = randi_range(0, TYPE_NAMES.size() - 1)
	if sequence_type < 0 or sequence_type >= TYPE_NAMES.size():
		push_warning("SequenceGenerator: invalid sequence type")
		return {"type": "invalid", "sequence": sequence}

	var attacks: Array[String] = []
	var tricks: Array[String] = []
	for i in range(int(ATTACK_SCALING[level])):
		attacks.append("a")
	for i in range(int(TRICK_SCALING[level])):
		tricks.append("t")

	var actions: Array[String] = []
	match sequence_type:
		SequenceType.RUSH_THEN_SLOW:
			actions.append_array(attacks)
			actions.append_array(tricks)
		SequenceType.BAIT_AND_STRIKE:
			while not tricks.is_empty() or not attacks.is_empty():
				if not tricks.is_empty():
					actions.append(tricks.pop_back())
				if not attacks.is_empty():
					actions.append(attacks.pop_back())
		_:
			actions.append_array(attacks)
			actions.append_array(tricks)
			actions.shuffle()

	var count: int = actions.size()
	var minimum_duration: float = MIN_GAP * float(count - 1)
	if duration < minimum_duration:
		push_warning("SequenceGenerator: duration is too short for the move count")
		return {"type": TYPE_NAMES[sequence_type], "sequence": sequence}

	var weights: Array[float] = []
	var total_weight: float = 0.0
	for slot in range(count + 1):
		var weight: float = _gap_weight(sequence_type, slot, actions)
		weights.append(weight)
		total_weight += weight

	var spare_time: float = duration - minimum_duration
	var cursor: float = spare_time * weights[0] / total_weight
	for i in range(count):
		sequence.append("%.2f,%s" % [cursor, actions[i]])
		if i < count - 1:
			cursor += MIN_GAP + spare_time * weights[i + 1] / total_weight

	return {"type": TYPE_NAMES[sequence_type], "sequence": sequence}


static func _gap_weight(sequence_type: int, slot: int, actions: Array[String]) -> float:
	var count: int = actions.size()
	if slot == count:
		return 0.5
	match sequence_type:
		SequenceType.BALANCED:
			return 1.0
		SequenceType.RUSH_THEN_SLOW:
			if slot == 0:
				return 0.25
			return lerpf(0.25, 3.0, float(slot - 1) / float(maxi(1, count - 2)))
		SequenceType.DELAY_BEFORE_ATTACK:
			return 3.5 if actions[slot] == "a" else 0.3
		SequenceType.BURST_PAUSE:
			return 5.0 if slot == int(ceil(float(count) / 2.0)) else 0.3
		SequenceType.SLOW_THEN_RUSH:
			if slot == 0:
				return 0.3
			return lerpf(3.0, 0.25, float(slot - 1) / float(maxi(1, count - 2)))
		SequenceType.BAIT_AND_STRIKE:
			return 0.15 if actions[slot] == "a" else 2.5
		SequenceType.CHAOTIC:
			return randf_range(0.15, 3.0)
		_:
			return 1.0
