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
	"balanced",
	"rush_then_slow",
	"delay_before_attack",
	"burst_pause",
	"slow_then_rush",
	"bait_and_strike",
	"chaotic"
]


# --------------------------------------------------
# TIMING
# --------------------------------------------------

## Minimum time between the STARTS of two moves.
const MIN_GAP: float = 0.70

## Reserve some time after the final move starts.
const END_BUFFER: float = 0.80


# --------------------------------------------------
# HP / STABILITY BALANCING
# --------------------------------------------------

## Minimum extra missed attacks the player can tolerate.
const MIN_MISS_ALLOWANCE: int = 2

## Additional attack opportunities relative to
## the greater of HP and stability.
const MISS_ALLOWANCE_RATIO: float = 0.30

## Preserve at least one trick in every sequence.
const MIN_TRICKS: int = 1


# --------------------------------------------------
# GENERATION
# --------------------------------------------------

## Returns:
## {
##   "type": String,
##   "sequence": Array[String],
##   "attack_count": int,
##   "trick_count": int,
##   "required_hits": int,
##   "required_attacks": int,
##   "miss_allowance": int,
##   "hp": int,
##   "stability": int
## }
##
## Example sequence entry: "2.50,a"
##
## sequence_type:
## -1 = use EnemyProfile.sequence_pattern
## 0-6 = explicitly select SequenceType

static func generate(
	profile: EnemyProfile,
	duration: float,
	sequence_type: int = -1
) -> Dictionary:

	var sequence: Array[String] = []

	if profile == null:
		push_warning("SequenceGenerator: missing EnemyProfile")
		return {
			"type": "invalid",
			"sequence": sequence
		}

	# ------ Enemy Stats ------

	var hp: int = profile.base_hp
	var stability: int = profile.max_stab

	if duration <= END_BUFFER:
		push_warning("SequenceGenerator: invalid duration")
		return {
			"type": "invalid",
			"sequence": sequence
		}

	if hp < 1 and stability < 1:
		push_warning("SequenceGenerator: invalid HP and stability")
		return {
			"type": "invalid",
			"sequence": sequence
		}

	# ------ Pattern Selection ------

	if sequence_type == -1:
		if profile.sequence_pattern == 0:
			sequence_type = randi_range(
				0,
				TYPE_NAMES.size() - 1
			)
		else:
			sequence_type = profile.sequence_pattern - 1

	if sequence_type < 0 or sequence_type >= TYPE_NAMES.size():
		push_warning("SequenceGenerator: invalid sequence type")
		return {
			"type": "invalid",
			"sequence": sequence
		}

	# ------ HP / Stability Requirements ------

	# Use whichever stat requires more successful hits.
	var required_hits: int = maxi(
		hp,
		stability
	)

	# Additional opportunities for missed attacks.
	var miss_allowance: int = maxi(
		MIN_MISS_ALLOWANCE,
		ceili(
			float(required_hits)
			* MISS_ALLOWANCE_RATIO
		)
	)

	# Minimum number of attack opportunities.
	var required_attacks: int = (
		required_hits + miss_allowance
	)

	# Minimum total moves, including tricks.
	var minimum_count: int = (
		required_attacks + MIN_TRICKS
	)

	# ------ Duration Capacity ------

	var usable_duration: float = (
		duration - END_BUFFER
	)

	var max_count: int = (
		floori(usable_duration / MIN_GAP) + 1
	)

	# Reject impossible configurations.
	if minimum_count > max_count:

		var minimum_time: float = (
			float(minimum_count - 1) * MIN_GAP
			+ END_BUFFER
		)

		push_warning(
			"SequenceGenerator: HP %d / Stability %d requires at least %.2f seconds"
			% [hp, stability, minimum_time]
		)

		return {
			"type": TYPE_NAMES[sequence_type],
			"sequence": sequence,
			"attack_count": 0,
			"trick_count": 0,
			"required_hits": required_hits,
			"required_attacks": required_attacks,
			"miss_allowance": miss_allowance,
			"hp": hp,
			"stability": stability
		}

	# ------ Move Count ------

	var target_gap: float = _get_target_gap(
		sequence_type
	)

	var target_count: int = roundi(
		usable_duration / target_gap
	)

	var count: int = clampi(
		target_count,
		minimum_count,
		max_count
	)

	# ------ Attack / Trick Distribution ------

	var attack_ratio: float = _get_attack_ratio(
		sequence_type
	)

	var attack_count: int = maxi(
		required_attacks,
		roundi(float(count) * attack_ratio)
	)

	# Reserve enough room for tricks.
	attack_count = mini(
		attack_count,
		count - MIN_TRICKS
	)

	var trick_count: int = (
		count - attack_count
	)

	# ------ Build Actions ------

	var actions: Array[String] = _build_actions(
		attack_count,
		trick_count,
		sequence_type
	)

	# ------ Timing Distribution ------

	var minimum_duration: float = (
		MIN_GAP * float(count - 1)
	)

	var spare_time: float = maxf(
		0.0,
		usable_duration - minimum_duration
	)

	var weights: Array[float] = []
	var total_weight: float = 0.0

	for slot in range(count + 1):

		var weight: float = _gap_weight(
			sequence_type,
			slot,
			actions
		)

		weights.append(weight)
		total_weight += weight

	# ------ Generate Timestamps ------

	var cursor: float = (
		spare_time * weights[0] / total_weight
	)

	for i in range(count):

		sequence.append(
			"%.2f,%s" % [cursor, actions[i]]
		)

		if i < count - 1:

			cursor += MIN_GAP

			cursor += (
				spare_time
				* weights[i + 1]
				/ total_weight
			)

	# ------ Return ------

	return {
		"type": TYPE_NAMES[sequence_type],
		"sequence": sequence,
		"attack_count": attack_count,
		"trick_count": trick_count,
		"required_hits": required_hits,
		"required_attacks": required_attacks,
		"miss_allowance": miss_allowance,
		"hp": hp,
		"stability": stability
	}


# --------------------------------------------------
# MOVE DENSITY
# --------------------------------------------------

## Lower gap = more moves in the same duration.

static func _get_target_gap(
	sequence_type: int
) -> float:

	match sequence_type:

		SequenceType.BALANCED:
			return 1.8

		SequenceType.RUSH_THEN_SLOW:
			return 1.5

		SequenceType.DELAY_BEFORE_ATTACK:
			return 2.1

		SequenceType.BURST_PAUSE:
			return 1.7

		SequenceType.SLOW_THEN_RUSH:
			return 1.7

		SequenceType.BAIT_AND_STRIKE:
			return 1.5

		SequenceType.CHAOTIC:
			return randf_range(1.3, 2.5)

	return 1.8


# --------------------------------------------------
# ATTACK RATIO
# --------------------------------------------------

## Preferred proportion of attacks.
## HP/stability requirements can override this ratio.

static func _get_attack_ratio(
	sequence_type: int
) -> float:

	match sequence_type:

		SequenceType.BALANCED:
			return 0.50

		SequenceType.RUSH_THEN_SLOW:
			return 0.65

		SequenceType.DELAY_BEFORE_ATTACK:
			return 0.60

		SequenceType.BURST_PAUSE:
			return 0.65

		SequenceType.SLOW_THEN_RUSH:
			return 0.65

		SequenceType.BAIT_AND_STRIKE:
			return 0.55

		SequenceType.CHAOTIC:
			return 0.60

	return 0.50


# --------------------------------------------------
# ACTION GENERATION
# --------------------------------------------------

static func _build_actions(
	attack_count: int,
	trick_count: int,
	sequence_type: int
) -> Array[String]:

	var actions: Array[String] = []

	match sequence_type:

		SequenceType.BALANCED, SequenceType.BURST_PAUSE:

			actions = _build_spaced_actions(
				attack_count,
				trick_count
			)

		SequenceType.RUSH_THEN_SLOW:

			# Attack phase followed by trick phase.
			for i in range(attack_count):
				actions.append("a")

			for i in range(trick_count):
				actions.append("t")

		SequenceType.DELAY_BEFORE_ATTACK, SequenceType.SLOW_THEN_RUSH:

			# Trick phase followed by attack phase.
			for i in range(trick_count):
				actions.append("t")

			for i in range(attack_count):
				actions.append("a")

		SequenceType.BAIT_AND_STRIKE:

			# Place tricks before attacks where possible.
			var remaining_attacks: int = attack_count
			var remaining_tricks: int = trick_count

			while remaining_attacks > 0:

				if remaining_tricks > 0:
					actions.append("t")
					remaining_tricks -= 1

				actions.append("a")
				remaining_attacks -= 1

			while remaining_tricks > 0:
				actions.append("t")
				remaining_tricks -= 1

		SequenceType.CHAOTIC:

			for i in range(attack_count):
				actions.append("a")

			for i in range(trick_count):
				actions.append("t")

			actions.shuffle()

	return actions


# --------------------------------------------------
# EVENLY MIXED ACTIONS
# --------------------------------------------------

## Spread tricks across attacks rather than placing
## all tricks at the beginning or end.

static func _build_spaced_actions(
	attack_count: int,
	trick_count: int
) -> Array[String]:

	var actions: Array[String] = []

	var count: int = attack_count + trick_count
	var used_tricks: int = 0
	var phase: float = randf()

	for i in range(count):

		var expected_tricks: int = floori(
			float(i + 1)
			* float(trick_count)
			/ float(count)
			+ phase
		)

		if expected_tricks > used_tricks:
			actions.append("t")
			used_tricks += 1
		else:
			actions.append("a")

	return actions


# --------------------------------------------------
# TIMING WEIGHTS
# --------------------------------------------------

static func _gap_weight(
	sequence_type: int,
	slot: int,
	actions: Array[String]
) -> float:

	var count: int = actions.size()

	if slot == count:
		return 0.5

	match sequence_type:

		SequenceType.BALANCED:
			return 1.0

		SequenceType.RUSH_THEN_SLOW:

			if slot == 0:
				return 0.15

			return lerpf(
				0.2,
				3.0,
				float(slot - 1) / float(maxi(1, count - 2))
			)

		SequenceType.DELAY_BEFORE_ATTACK:

			if slot == 0:
				return 0.5

			# Large pause between tricks and first attack.
			if actions[slot] == "a" and actions[slot - 1] == "t":
				return 5.0

			return 0.4

		SequenceType.BURST_PAUSE:

			var midpoint: int = ceili(float(count) / 2.0)

			if slot == midpoint:
				return 5.0

			return 0.25

		SequenceType.SLOW_THEN_RUSH:

			if slot == 0:
				return 0.3

			return lerpf(
				3.0,
				0.2,
				float(slot - 1) / float(maxi(1, count - 2))
			)

		SequenceType.BAIT_AND_STRIKE:

			if slot == 0:
				return 0.5

			# Quick attack after a trick.
			if actions[slot] == "a" and actions[slot - 1] == "t":
				return 0.15

			# Longer pause before the next bait.
			if actions[slot] == "t":
				return 2.5

			return 0.7

		SequenceType.CHAOTIC:
			return randf_range(0.15, 3.0)

	return 1.0
