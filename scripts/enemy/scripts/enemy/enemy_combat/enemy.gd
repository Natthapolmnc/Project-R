class_name Enemy
extends Node3D

signal enemy_delta(delta: float)
signal enemy_timeout
signal state_changed(new_state: State)
signal vulnerability_changed(attackable: bool, parryable: bool)
signal action_started(move: EnemyMove)
signal strike_reached(move: EnemyMove)
signal trick_revealed(move: EnemyMove)
signal enemy_is_finished
signal enemy_died
signal stability_changed(current: float, maximum: float)

func _emit_stability_changed() -> void:
	stability_changed.emit(profile.cur_stab, profile.max_stab)

## Animation windows are independent of these broad enemy states.
enum State { PASSIVE, ATTACK, DOWN }

@export_category("Enemy Setup")
@export var profile: EnemyProfile

@export_category("Sequence")
@export_range(1, 99, 1) var cur_level: int = 1
@export_range(1.0, 120.0, 0.1) var sequence_duration: float = 12.0
@export var auto_generate_sequence: bool = true
## Manual entries are absolute timestamps: "1.0,t", "3.5,a", etc.
## Used only when Auto Generate Sequence is turned off in the Inspector.
@export var manual_sequence: Array[String] = []

@export_category("Time Manager")
@export_range(0.05, 1.0, 0.05) var slow_down: float = 0.5

@export_category("Stability Recovery")
## Real seconds after the most recent parry before recovery begins.
@export_range(0.0, 30.0, 0.1) var stability_recovery_delay: float = 3.0
## Stability points restored per real second (smooth fractional recovery).
@export_range(0.1, 10.0, 0.1) var stability_recovery_rate: float = 1.0

var timing_player: AnimationPlayer

@export_category("Effects")
## Optional Marker3D where this enemy's particles should originate.
@export var effect_origin: Node3D
@export var count_down_visual: Clocking


var state: State = State.PASSIVE
var current_stance: StringName = &""
var current_move: EnemyMove

var current_time: float = 0.0   ## Countdown until the player loses.
var elapsed_time: float = 0.0   ## Absolute time since this sequence began.
var clocking: bool = true

var timeline: Array[Dictionary] = []
var next_action_index: int = 0
var active_pattern: String = ""

var _attackable: bool = false
var _parryable: bool = false
var _dead: bool = false
var _timeout_emitted: bool = false
var _stability_recovery_start_usec: int = -1
var _last_stability_recovery_usec: int = -1



func _ready() -> void:
	for i in get_children():
		if i is AnimationPlayer:
			timing_player = i
			break
	
	if profile == null or timing_player == null:
		push_error("Enemy needs an EnemyProfile and AnimationPlayer")
		set_process(false)
		return
	timing_player.animation_finished.connect(_on_animation_finished)
	count_down_visual.countdown_time=sequence_duration
	count_down_visual.clocking=true
	set_clocking(true)
	
	start_sequence()


func start_sequence(duration: float = -1.0) -> void:
	if profile == null or timing_player == null:
		return
	if duration > 0.0:
		sequence_duration = duration

	_cancel_action()
	profile.on_start()
	_dead = false
	_stability_recovery_start_usec = -1
	_last_stability_recovery_usec = -1
	_emit_stability_changed()
	current_stance = profile.initial_stance
	current_time = sequence_duration
	elapsed_time = 0.0
	next_action_index = 0
	_timeout_emitted = false
	timeline.clear()
	_set_windows(false, false)
	_set_state(State.PASSIVE)

	var entries: Array[String] = []
	if auto_generate_sequence:
		# Profile pattern 0 = random. Others map to the generator enum.
		var generated: Dictionary = SequenceGenerator.generate(
			profile, sequence_duration, profile.sequence_pattern - 1
		)
		active_pattern = str(generated["type"])
		for entry: String in generated["sequence"]:
			entries.append(entry)
	else:
		active_pattern = "manual"
		entries = manual_sequence.duplicate()
	_load_timeline(entries)
	_play_idle()


func _load_timeline(entries: Array[String]) -> void:
	for entry in entries:
		var parts: PackedStringArray = entry.split(",")
		if parts.size() != 2:
			push_warning("Invalid sequence entry '%s' (expected 'time,a' or 'time,t')" % entry)
			continue

		var time_text: String = parts[0].strip_edges()
		if not time_text.is_valid_float():
			push_warning("Invalid sequence timestamp in '%s'" % entry)
			continue

		var stamp: float = time_text.to_float()
		if stamp < 0.0 or stamp >= sequence_duration:
			push_warning("Sequence time %.2f must be within [0, %.2f)" % [stamp, sequence_duration])
			continue

		var code: String = parts[1].strip_edges().to_lower()
		if code != "a" and code != "t":
			push_warning("Invalid action '%s' (use 'a' or 't')" % code)
			continue

		timeline.append({
			"time": stamp,
			"code": code
		})

	# Manual entries can be entered in any order.
	timeline.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["time"]) < float(b["time"])
	)


func _process(delta: float) -> void:
	if _dead or _timeout_emitted:
		return

	# Use monotonic real time, not delta/slow_down/Engine.time_scale.
	_process_stability_recovery()

	var step: float = delta if clocking else delta * slow_down
	current_time = maxf(current_time - step, 0.0)
	elapsed_time += step
	enemy_delta.emit(step)

	if current_time <= 0.0 and (
		not timing_player.current_animation.begins_with("slash")
		and not timing_player.current_animation.begins_with("down")
		):
		_timeout_emitted = true
		enemy_timeout.emit()
		timing_player.play("timeout")
		CombatFx.trigger("timeout")
		return

	# A move must finish before the next one starts. Overdue moves queue up.
	if current_move != null or state == State.DOWN:
		return

	while next_action_index < timeline.size():
		var event: Dictionary = timeline[next_action_index]
		if elapsed_time < float(event["time"]):
			break
		next_action_index += 1
		if _start_move(str(event["code"])):
			break


func _start_move(code: String) -> bool:
	var move: EnemyMove = profile.pick_move(code, current_stance)
	if move == null:
		push_warning("No %s move available from stance '%s'" % [code, current_stance])
		return false
	var animation_name: StringName = move.get_animation_name()
	if animation_name == &"" or not timing_player.has_animation(animation_name):
		push_warning("Missing AnimationPlayer move: %s" % animation_name)
		return false

	current_move = move
	_set_windows(false, false)
	if move.kind == EnemyMove.Kind.TRICK:
		_set_state(State.PASSIVE)
	else:
		_set_state(State.ATTACK)
	timing_player.play(animation_name)
	action_started.emit(move)
	return true


func _on_animation_finished(_animation_name: StringName) -> void:
	if _dead:
		return
	if state == State.DOWN:
		recover_from_down()
		return
	if current_move == null:
		_play_idle()
		return
	var completed_move: EnemyMove = current_move
	timing_player.stop()
	current_move = null
	current_stance = completed_move.to_stance
	_set_windows(false, false)
	_set_state(State.PASSIVE)
	_play_idle()


func _play_idle() -> void:
	var idle: StringName = profile.get_idle(current_stance)
	if idle == &"" or not timing_player.has_animation(idle):
		push_warning("No idle animation for stance '%s'" % current_stance)
		return
	timing_player.play(idle)


func _cancel_action() -> void:
	if timing_player != null:
		timing_player.stop()
	current_move = null
	_set_windows(false, false)


# ----------------------------------------------------
# ANIMATIONPLAYER METHOD-TRACK HOOKS
# ----------------------------------------------------

## One animation hook for all global effects. CombatFX is an Autoload scene.
func animation_effect(effect_id: StringName) -> void:
	var global_fx: Node = get_node_or_null("/root/CombatFX")
	if global_fx == null:
		push_warning("Enemy: register combat_fx.tscn as Autoload 'CombatFX'")
		return
	var origin: Node3D = effect_origin if is_instance_valid(effect_origin) else self
	global_fx.call("trigger", effect_id, origin)

## Legacy method tracks may still call this; phases are no longer necessary.
func animation_set_phase(_unused: int) -> void:
	pass


func animation_set_parryable(value: bool) -> void:
	if current_move == null:
		return
	# Feints cannot become real, parryable attacks by accident.
	var allowed: bool = value and current_move.kind == EnemyMove.Kind.ATTACK
	_set_windows(_attackable, allowed)


func animation_set_attackable(value: bool) -> void:
	if current_move == null:
		return
	_set_windows(value, _parryable)


## Call at the exact impact frame of a real attack.
func animation_strike() -> void:
	if current_move == null or current_move.kind != EnemyMove.Kind.ATTACK:
		return
	_set_windows(_attackable, false)
	strike_reached.emit(current_move)


## Call at the moment a trick is revealed (no damage is dealt).
func animation_reveal_trick() -> void:
	if current_move == null or current_move.kind != EnemyMove.Kind.TRICK:
		return
	trick_revealed.emit(current_move)


# ----------------------------------------------------
# PLAYER-FACING COMBAT API
# ----------------------------------------------------

func can_be_parried() -> bool:
	return _parryable and current_move != null and not _dead


func can_be_attacked() -> bool:
	return _attackable and not _dead


func is_dead() -> bool:
	return _dead


func receive_parry() -> bool:
	if not can_be_parried():
		return false

	profile.cur_stab = maxf(profile.cur_stab - 1.0, 0.0)
	_emit_stability_changed()

	_cancel_action()

	if profile.cur_stab <= 0:
		_enter_down()
	else:
		_restart_stability_recovery()
		_set_state(State.PASSIVE)
		_play_idle()

	return true


# ----------------------------------------------------
# STABILITY RECOVERY (REAL ELAPSED TIME)
# ----------------------------------------------------

func _restart_stability_recovery() -> void:
	# Successful parries reset the real-time delay.
	if _dead or state == State.DOWN or profile.cur_stab >= profile.max_stab:
		_stability_recovery_start_usec = -1
		_last_stability_recovery_usec = -1
		return

	_stability_recovery_start_usec = Time.get_ticks_usec() + roundi(stability_recovery_delay * 1000000.0)
	_last_stability_recovery_usec = _stability_recovery_start_usec


func _process_stability_recovery() -> void:
	if _stability_recovery_start_usec < 0 or state == State.DOWN:
		return

	var now_usec: int = Time.get_ticks_usec()
	if now_usec <= _stability_recovery_start_usec:
		return

	# Wall-clock time: unaffected by combat slowdown or Engine.time_scale.
	# Recover fractional points every frame, not one integer point per interval.
	var elapsed_real_seconds: float = float(now_usec - _last_stability_recovery_usec) / 1000000.0
	_last_stability_recovery_usec = now_usec
	if elapsed_real_seconds <= 0.0:
		return

	var previous_stability: float = profile.cur_stab
	profile.cur_stab = minf(
		profile.cur_stab + stability_recovery_rate * elapsed_real_seconds,
		profile.max_stab
	)
	if not is_equal_approx(previous_stability, profile.cur_stab):
		_emit_stability_changed()

	if profile.cur_stab >= profile.max_stab:
		_stability_recovery_start_usec = -1
		_last_stability_recovery_usec = -1


func on_dodge() -> void:
	timing_player.play("dodge")


#func got_parried() -> void:
	## Compatibility with the previous Enemy API.
	#receive_parry()


func receive_hit() -> bool:
	if not can_be_attacked():
		return false
	profile.on_being_finished()
	enemy_is_finished.emit()
	if profile.is_dead():
		_die()
	return true


func _enter_down() -> void:
	_stability_recovery_start_usec = -1
	_last_stability_recovery_usec = -1
	_set_state(State.DOWN)
	_set_windows(true, false)
	if profile.down_animation != &"" and timing_player.has_animation(profile.down_animation):
		timing_player.play(profile.down_animation)
	# The down AnimationPlayer clip should be non-looping. On finish, stability recovers.
	# If there is no down animation, call recover_from_down() externally.


func recover_from_down() -> void:
	if state != State.DOWN or _dead:
		return
	profile.recover_from_down()
	# Refill only after the down animation finishes, not immediately on parry.
	profile.cur_stab = profile.max_stab
	_stability_recovery_start_usec = -1
	_last_stability_recovery_usec = -1
	_emit_stability_changed()
	_set_windows(false, false)
	_set_state(State.PASSIVE)
	_play_idle()


func _die() -> void:
	_stability_recovery_start_usec = -1
	_last_stability_recovery_usec = -1
	_cancel_action()
	_dead = true
	if profile.death_animation != &"" and timing_player.has_animation(profile.death_animation):
		timing_player.play(profile.death_animation)
	timing_player.animation_finished.connect(dead_anim_finished, CONNECT_ONE_SHOT)


func dead_anim_finished(_arg = null) -> void:
	enemy_died.emit()


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)


func _set_windows(allow_attack: bool, allow_parry: bool) -> void:
	if _attackable == allow_attack and _parryable == allow_parry:
		return
	_attackable = allow_attack
	_parryable = allow_parry
	vulnerability_changed.emit(_attackable, _parryable)


func get_cur_state() -> State:
	return state


func get_stability() -> float:
	return profile.cur_stab


func get_hp() -> int:
	return profile.get_hp()


func set_clocking(enabled: bool) -> void:
	clocking = enabled
	var speed: float = 1.0 if enabled else slow_down
	if timing_player != null:
		timing_player.speed_scale = speed


func is_clocking() -> bool:
	return clocking


func set_duration(duration: float) -> void:
	sequence_duration = duration


func set_profile(prof: EnemyProfile) -> void:
	profile = prof


func play_spark() -> void:
	CombatFx.trigger("spark", $weapon)


func play_slash() -> void:
	AudioPlayer.play_slash()
