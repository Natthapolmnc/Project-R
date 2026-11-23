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

# --- Timing ---
const MIN_GAP: float = 0.70
const START_DELAY: float = 0.35
const END_BUFFER: float = 0.80

# Desired action density; duration determines the approximate counts.
const ATTACK_INTERVAL: float = 2.00
const TRICK_INTERVAL: float = 2.80

# A phase pause is a TOTAL gap, not extra time added to a gap.
# Most importantly, it cannot swallow the time budget for burst two.
const MAX_BURST_PAUSE: float = 1.5
const BURST_PAUSE_RATIO: float = 0.12

# BURST_PAUSE is built as repeating clusters: a a a t | pause | a a a t.
# These durations determine the number of clusters and their rhythm.
const BURST_CYCLE_TIME: float = 5.0
const BURST_MIN_ATTACKS: int = 2
const BURST_MIN_PAUSE: float = 1.10
const BURST_TARGET_ATTACK_GAP: float = 1.00
const MAX_OPENING_DELAY: float = 2.40
const OPENING_DELAY_RATIO: float = 0.13

# Extra time kept available when choosing the move count, so a phase
# can actually have a distinct pause even at higher difficulties.
const PHASE_GAP_RESERVE: float = 1.00

# --- Fairness ---
const MIN_MISS_ALLOWANCE: int = 2
const MISS_ALLOWANCE_RATIO: float = 0.30


## -1 reads profile.sequence_pattern (0 = random).
## Returns {"type", "sequence", "attack_count", "trick_count",
##          "required_hits", "required_attacks", "miss_allowance",
##          "hp", "stability"}.
## Entries look like "2.50,a" and "3.20,t".
static func generate(
	profile: EnemyProfile,
	duration: float,
	sequence_type: int = -1
) -> Dictionary:
	var empty: Array[String] = []
	if profile == null or duration <= START_DELAY + END_BUFFER:
		push_warning("SequenceGenerator: missing profile or invalid duration")
		return {"type": "invalid", "sequence": empty}

	if sequence_type == -1:
		if profile.sequence_pattern == 0:
			sequence_type = randi_range(0, TYPE_NAMES.size() - 1)
		else:
			sequence_type = profile.sequence_pattern - 1

	if sequence_type < 0 or sequence_type >= TYPE_NAMES.size():
		push_warning("SequenceGenerator: invalid sequence type")
		return {"type": "invalid", "sequence": empty}

	var hp: int = profile.base_hp
	var stability: int = profile.max_stab
	var required_hits: int = maxi(hp, stability)
	if required_hits < 1:
		push_warning("SequenceGenerator: invalid HP/stability")
		return {"type": "invalid", "sequence": empty}

	var miss_allowance: int = maxi(
		MIN_MISS_ALLOWANCE,
		ceili(float(required_hits) * MISS_ALLOWANCE_RATIO)
	)
	var required_attacks: int = required_hits + miss_allowance

	# BURST_PAUSE has its own time-budgeted, repeating a...a,t,pause
	# design. A fixed two-phase split cannot create clustered attacks.
	if sequence_type == SequenceType.BURST_PAUSE:
		return _generate_clustered_bursts(
			profile, duration, required_hits,
			required_attacks, miss_allowance
		)

	# Duration chooses counts independently. More required attacks do
	# not automatically delete tricks or make a pattern all attacks.
	var usable_end: float = duration - END_BUFFER
	var timeline_span: float = usable_end - START_DELAY
	var minimum_tricks: int = maxi(1, ceili(duration / 8.0))

	var attack_count: int = maxi(
		required_attacks, roundi(timeline_span / ATTACK_INTERVAL)
	)
	var trick_count: int = maxi(
		minimum_tricks, roundi(timeline_span / TRICK_INTERVAL)
	)

	# Every bait must be followed by a real attack.
	if sequence_type == SequenceType.BAIT_AND_STRIKE:
		trick_count = mini(trick_count, attack_count)

	# Budget a little spare time for a distinct middle/opening pause.
	# No fixed number of attacks or tricks is imposed beyond fairness.
	var reserved_extra: float = 0.0
	if sequence_type == SequenceType.DELAY_BEFORE_ATTACK:
		reserved_extra = minf(PHASE_GAP_RESERVE, timeline_span * 0.08)

	var max_moves: int = floori(
		(timeline_span - reserved_extra) / MIN_GAP
	) + 1

	if required_attacks + minimum_tricks > max_moves:
		push_warning(
			"SequenceGenerator: %d attacks + %d tricks cannot fit in %.2fs with pattern '%s'"
			% [required_attacks, minimum_tricks, duration, TYPE_NAMES[sequence_type]]
		)
		return {
			"type": TYPE_NAMES[sequence_type], "sequence": empty,
			"attack_count": 0, "trick_count": 0,
			"required_hits": required_hits,
			"required_attacks": required_attacks,
			"miss_allowance": miss_allowance,
			"hp": hp, "stability": stability
		}

	# Reduce only OPTIONAL moves if we hit the physical time capacity.
	while attack_count + trick_count > max_moves:
		if attack_count > required_attacks and (
			attack_count >= trick_count or trick_count <= minimum_tricks
		):
			attack_count -= 1
		elif trick_count > minimum_tricks:
			trick_count -= 1
		else:
			attack_count -= 1

	var count: int = attack_count + trick_count

	# Pattern controls BOTH action placement and timing.
	var actions: Array[String] = _build_actions(
		count, trick_count, sequence_type
	)
	var times: Array[float] = _build_timestamps(
		actions, usable_end, sequence_type, duration
	)

	var sequence: Array[String] = []
	for i in range(count):
		sequence.append("%.2f,%s" % [times[i], actions[i]])

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
# BURST_PAUSE: tight attacks -> trick -> short pause -> repeat.
# --------------------------------------------------
## Tricks land at the END of each cluster, just before the pause.
## Time allocation includes every cluster and pause, so a later burst
## can never be squeezed out by one oversized gap.
static func _generate_clustered_bursts(
	profile: EnemyProfile,
	duration: float,
	required_hits: int,
	required_attacks: int,
	miss_allowance: int
) -> Dictionary:
	var timeline_span: float = duration - START_DELAY - END_BUFFER
	var empty: Array[String] = []

	# About one cluster every five seconds. Short fights can use one.
	var burst_count: int = maxi(1, roundi(duration / BURST_CYCLE_TIME))
	var wanted_pause: float = clampf(
		duration * BURST_PAUSE_RATIO,
		BURST_MIN_PAUSE,
		MAX_BURST_PAUSE
	)

	# Each cluster must contain several attacks, then one fake attack.
	# Reduce the number of clusters if stability demands more attacks
	# than would otherwise fit. Keep at least two if feasible.
	while burst_count > 1:
		var attacks_needed: int = maxi(
			required_attacks,
			burst_count * BURST_MIN_ATTACKS
		)
		var minimum_span: float = (
			float(attacks_needed) * MIN_GAP
			+ float(burst_count - 1) * BURST_MIN_PAUSE
		)
		if minimum_span <= timeline_span + 0.0001:
			break
		burst_count -= 1

	var minimum_attacks: int = maxi(
		required_attacks,
		burst_count * BURST_MIN_ATTACKS
	)
	var minimum_span: float = (
		float(minimum_attacks) * MIN_GAP
		+ float(burst_count - 1) * BURST_MIN_PAUSE
	)
	if minimum_span > timeline_span + 0.0001:
		push_warning(
			"SequenceGenerator: %d attacks cannot fit in %.2fs with BURST_PAUSE"
			% [required_attacks, duration]
		)
		return {
			"type": TYPE_NAMES[SequenceType.BURST_PAUSE],
			"sequence": empty,
			"attack_count": 0,
			"trick_count": 0,
			"required_hits": required_hits,
			"required_attacks": required_attacks,
			"miss_allowance": miss_allowance,
			"hp": profile.base_hp,
			"stability": profile.max_stab
		}

	# Calculate count from remaining time, not a fixed A/T ratio.
	# Every group has one trick after its attack cluster.
	var pause_count: int = burst_count - 1
	var target_attacks: int = roundi(
		(timeline_span - float(pause_count) * wanted_pause)
		/ BURST_TARGET_ATTACK_GAP
	)
	var max_attacks: int = floori(
		(timeline_span - float(pause_count) * BURST_MIN_PAUSE)
		/ MIN_GAP
	)
	var attack_count: int = clampi(
		target_attacks, minimum_attacks, max_attacks
	)
	var trick_count: int = burst_count

	# Divide attacks reasonably evenly; allow one extra attack in a
	# different burst each time, rather than always in the first.
	var attacks_per_burst: Array[int] = []
	for i in range(burst_count):
		attacks_per_burst.append(BURST_MIN_ATTACKS)
	var extra_attacks: int = attack_count - burst_count * BURST_MIN_ATTACKS
	var rotating_start: int = randi_range(0, burst_count - 1)
	for i in range(extra_attacks):
		attacks_per_burst[(rotating_start + i) % burst_count] += 1

	# Pauses have a hard cap and share the timeline with ALL attacks.
	# If stability is high, shorten pauses rather than crushing the
	# last attack cluster beyond the time limit.
	var pause_length: float = 0.0
	if pause_count > 0:
		var affordable_pause: float = (
			timeline_span - float(attack_count) * MIN_GAP
		) / float(pause_count)
		pause_length = minf(wanted_pause, affordable_pause)

	# The remaining time is allocated to gaps INSIDE the bursts.
	# Internal gaps remain short and have only mild variation.
	var internal_spare: float = (
		timeline_span
		- float(pause_count) * pause_length
		- float(attack_count) * MIN_GAP
	)
	var internal_weights: Array[float] = []
	var weight_sum: float = 0.0
	for i in range(attack_count):
		var weight: float = randf_range(0.88, 1.12)
		internal_weights.append(weight)
		weight_sum += weight

	var sequence: Array[String] = []
	var cursor: float = START_DELAY
	var gap_index: int = 0
	for burst in range(burst_count):
		for attack in range(attacks_per_burst[burst]):
			sequence.append("%.2f,a" % cursor)
			cursor += MIN_GAP + (
				internal_spare * internal_weights[gap_index] / weight_sum
			)
			gap_index += 1

		# The false alarm is the final event BEFORE the pause.
		sequence.append("%.2f,t" % cursor)
		if burst < burst_count - 1:
			cursor += pause_length

	return {
		"type": TYPE_NAMES[SequenceType.BURST_PAUSE],
		"sequence": sequence,
		"attack_count": attack_count,
		"trick_count": trick_count,
		"required_hits": required_hits,
		"required_attacks": required_attacks,
		"miss_allowance": miss_allowance,
		"hp": profile.base_hp,
		"stability": profile.max_stab
	}


# --------------------------------------------------
# ACTION PLACEMENT: the selected pattern matters.
# --------------------------------------------------
static func _build_actions(
	count: int,
	trick_count: int,
	sequence_type: int
) -> Array[String]:
	var actions: Array[String] = []
	for i in range(count):
		actions.append("a")
	if trick_count == 0:
		return actions

	# When possible avoid back-to-back tricks. Bait explicitly requires
	# t -> a, so never place its trick in the last slot.
	var separation: int = 1
	if count >= trick_count * 2 - 1:
		separation = 2
	if sequence_type == SequenceType.BAIT_AND_STRIKE:
		separation = 2

	var last_allowed: int = count - 1
	if sequence_type == SequenceType.BAIT_AND_STRIKE:
		last_allowed = count - 2

	# Weighted quantiles put tricks throughout the full fight, but
	# shift their frequency forward/backward depending on the pattern.
	var centers: Array[float] = []
	var total_weight: float = 0.0
	for i in range(count):
		var p: float = float(i) / float(maxi(1, count - 1))
		var weight: float = _trick_weight(sequence_type, p)
		centers.append(total_weight + weight * 0.5)
		total_weight += weight

	var previous_index: int = -separation
	for j in range(trick_count):
		var remaining: int = trick_count - j - 1
		var low: int = previous_index + separation
		var high: int = last_allowed - remaining * separation
		var target: float = (
			(float(j) + 0.5) / float(trick_count) * total_weight
		)

		var best_index: int = low
		var best_distance: float = INF
		for candidate in range(low, high + 1):
			var distance: float = absf(centers[candidate] - target)
			if distance < best_distance:
				best_distance = distance
				best_index = candidate

		# These patterns have a deliberate opening bait.
		if j == 0 and (
			sequence_type == SequenceType.BAIT_AND_STRIKE
			or sequence_type == SequenceType.DELAY_BEFORE_ATTACK
		):
			best_index = 0

		actions[best_index] = "t"
		previous_index = best_index

	return actions


static func _trick_weight(sequence_type: int, progress: float) -> float:
	match sequence_type:
		SequenceType.RUSH_THEN_SLOW:
			# Early attacks; relatively more tricks toward the end.
			return lerpf(0.55, 1.45, progress)
		SequenceType.SLOW_THEN_RUSH:
			# Early tricks; relatively more attacks toward the end.
			return lerpf(1.45, 0.55, progress)
		SequenceType.DELAY_BEFORE_ATTACK:
			return lerpf(1.35, 0.75, progress)
		SequenceType.CHAOTIC:
			return randf_range(0.35, 1.65)
		_:
			return 1.0


# --------------------------------------------------
# TIME PLACEMENT: no phase gets to use all free time.
# --------------------------------------------------
static func _build_timestamps(
	actions: Array[String],
	usable_end: float,
	sequence_type: int,
	duration: float
) -> Array[float]:
	var result: Array[float] = []
	var count: int = actions.size()
	if count == 0:
		return result
	if count == 1:
		result.append(START_DELAY)
		return result

	var gap_count: int = count - 1
	var span: float = usable_end - START_DELAY
	var extra: float = maxf(0.0, span - MIN_GAP * float(gap_count))

	# Special gap is a fixed, capped portion of the entire duration.
	# Remaining time is spread across ALL other gaps, including those
	# after the pause: this protects the second burst.
	var special_slot: int = -1
	var special_gap: float = 0.0

	if sequence_type == SequenceType.DELAY_BEFORE_ATTACK:
		# The first trick is followed by a noticeable, bounded delay.
		special_slot = 1
		var wanted: float = minf(
			MAX_OPENING_DELAY, duration * OPENING_DELAY_RATIO
		)
		special_gap = _capped_phase_gap(
			wanted, span, gap_count, MAX_OPENING_DELAY
		)

	var weights: Array[float] = []
	var weight_sum: float = 0.0
	for slot in range(1, count):
		var weight: float = _gap_weight(
			sequence_type, slot, count, actions
		)
		weights.append(weight)
		if slot != special_slot:
			weight_sum += weight

	var distributable_extra: float = extra
	if special_slot != -1:
		distributable_extra -= special_gap - MIN_GAP
		distributable_extra = maxf(distributable_extra, 0.0)

	var cursor: float = START_DELAY
	result.append(cursor)
	for slot in range(1, count):
		var gap: float
		if slot == special_slot:
			gap = special_gap
		else:
			gap = MIN_GAP + (
				distributable_extra * weights[slot - 1] / weight_sum
			)
		cursor += gap
		result.append(cursor)

	return result


static func _capped_phase_gap(
	wanted: float,
	span: float,
	gap_count: int,
	max_pause: float
) -> float:
	# Cap the TOTAL pause while preserving MIN_GAP for every other move.
	var largest_possible: float = maxf(
		MIN_GAP,
		span - MIN_GAP * float(gap_count - 1)
	)
	var normal_gap: float = span / float(gap_count)
	var distinctive_gap: float = maxf(wanted, normal_gap + 0.35)
	return clampf(
		distinctive_gap,
		MIN_GAP,
		minf(max_pause, largest_possible)
	)


static func _gap_weight(
	sequence_type: int,
	slot: int,
	count: int,
	actions: Array[String]
) -> float:
	var progress: float = (
		float(slot - 1) / float(maxi(1, count - 2))
	)
	match sequence_type:
		SequenceType.RUSH_THEN_SLOW:
			# Intervals steadily grow, but never exponentially.
			return lerpf(0.65, 1.35, progress)
		SequenceType.SLOW_THEN_RUSH:
			return lerpf(1.35, 0.65, progress)
		SequenceType.BAIT_AND_STRIKE:
			# Short follow-up after every bait, longer between pairs.
			if actions[slot - 1] == "t" and actions[slot] == "a":
				return 0.20
			return 1.30
		SequenceType.CHAOTIC:
			return randf_range(0.50, 1.50)
		_:
			return 1.0
