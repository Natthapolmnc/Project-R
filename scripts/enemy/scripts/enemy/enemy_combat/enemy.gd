class_name Enemy
extends Node3D

signal enemy_timeout
signal state_changed(new_state: State)
signal vulnerability_changed(attackable: bool, parryable: bool)
signal action_started(move: EnemyMove)
signal strike_reached(move: EnemyMove)
signal trick_revealed(move: EnemyMove)
signal enemy_died


## Animation windows are independent of these broad enemy states.
enum State { PASSIVE, ATTACK, DOWN }

@export_category("Enemy Setup")
@export var resource: CharacterResource = CharacterResource.new()
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

@export_category("Animation")
@export var animation: AnimatedSprite3D
@export var timing_player: AnimationPlayer

@export_category("Effects")
## Optional Marker3D where this enemy's particles should originate.
@export var effect_origin: Node3D


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


func _ready() -> void:
	if profile == null or animation == null or timing_player == null:
		push_error("Enemy needs a Profile, AnimatedSprite3D and AnimationPlayer")
		set_process(false)
		return

	# Give each enemy its own HP/stability values even if scenes share a Resource.
	resource = CharacterResource.new() if resource == null else resource.duplicate(true) as CharacterResource
	animation.animation_finished.connect(_on_sprite_animation_finished)
	set_clocking(true)
	start_sequence()


func start_sequence(duration: float = -1.0) -> void:
	if profile == null or animation == null or timing_player == null:
		return
	if duration > 0.0:
		sequence_duration = duration

	_cancel_action()
	resource.on_start()
	_dead = false
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
			cur_level, sequence_duration, profile.sequence_pattern - 1
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
			push_warning("Sequence time %.2`f must be within [0, %.2f)" % [stamp, sequence_duration])
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

	var step: float = delta if clocking else delta * slow_down
	current_time = maxf(current_time - step, 0.0)
	elapsed_time += step

	if current_time <= 0.0:
		_timeout_emitted = true
		enemy_timeout.emit()
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
	if animation.sprite_frames == null or not animation.sprite_frames.has_animation(move.sprite_animation):
		push_warning("Missing SpriteFrames animation: %s" % move.sprite_animation)
		return false
	if not timing_player.has_animation(move.timing_animation):
		push_warning("Missing AnimationPlayer timing clip: %s" % move.timing_animation)
		return false

	current_move = move
	_set_windows(false, false)
	_set_state(State.ATTACK)
	animation.play(move.sprite_animation)
	timing_player.play(move.timing_animation)
	action_started.emit(move)
	return true


func _on_sprite_animation_finished() -> void:
	if _dead:
		return
	if state == State.DOWN:
		recover_from_down()
		return
	if current_move == null:
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
	if idle == &"" or animation.sprite_frames == null or not animation.sprite_frames.has_animation(idle):
		push_warning("No idle animation for stance '%s'" % current_stance)
		return
	animation.play(idle)


func _cancel_action() -> void:
	if timing_player != null:
		timing_player.stop()
	if animation != null:
		animation.stop()
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
	resource.cur_stab = maxi(resource.cur_stab - 1, 0)
	_cancel_action()
	if resource.cur_stab <= 0:
		_enter_down()
	else:
		_set_state(State.PASSIVE)
		_play_idle()
	return true


func got_parried() -> void:
	# Compatibility with the previous Enemy API.
	receive_parry()


func receive_hit() -> bool:
	if not can_be_attacked():
		return false
	resource.on_being_finished()
	if resource.is_dead():
		_die()
	return true


func _enter_down() -> void:
	_set_state(State.DOWN)
	_set_windows(true, false)
	if profile.down_animation != &"" and animation.sprite_frames.has_animation(profile.down_animation):
		animation.play(profile.down_animation)
	# The down animation should be non-looping. On finish, stability recovers.
	# If there is no down animation, call recover_from_down() externally.


func recover_from_down() -> void:
	if state != State.DOWN or _dead:
		return
	resource.recover_from_down()
	_set_windows(false, false)
	_set_state(State.PASSIVE)
	_play_idle()


func _die() -> void:
	_cancel_action()
	_dead = true
	if profile.death_animation != &"" and animation.sprite_frames.has_animation(profile.death_animation):
		animation.play(profile.death_animation)
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


func get_stability() -> int:
	return resource.cur_stab


func get_hp() -> int:
	return resource.get_hp()


func set_clocking(enabled: bool) -> void:
	clocking = enabled
	var speed: float = 1.0 if enabled else slow_down
	if animation != null:
		animation.speed_scale = speed
	if timing_player != null:
		timing_player.speed_scale = speed


func is_clocking() -> bool:
	return clocking


func _duration_receive(duration: float) -> void:
	start_sequence(duration)
