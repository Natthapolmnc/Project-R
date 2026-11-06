class_name Enemy
extends Node3D


# ------ @onready ------
@onready var resource := $CharacterResource
@onready var seq_gen := $SequenceGenerator
@onready var act_data := $ActionDatabase


# ------ STAGE ------
@export_category("LEVEL SCALING")
@export var cur_level: int = 1  ## Used in determining amount of tricks and attack


# ------ STATE ------
enum STATE { PASSIVE , ATTACK , DOWN }
var state: STATE = STATE.PASSIVE


# ------ ACTION ------
var timeline: Array[String]
var cur_act: Array
var cur_idle: StringName = &""


# ------ TIME ------
@export_category("TIME MANAGER")
var current_time: float = 0.0  ## Time always tick

var action_clock: float = 0.0  ## To think the wait before actions
var clocking: bool = true

@export var slow_down: float = 0.5


# ------ ANIMATION ------
@export_category("ANIMATION")
@export var animation: AnimationPlayer
var animation_counter: float = 0.0


## emit when this enemy is alive when its current_time is fully depleted, indicating the player has lost
signal enemy_timeout 


# ------------------------------
# INTERFACE
# ------------------------------

func on_start() -> void:
	current_time = seq_gen.get_duration()
	timeline = seq_gen.roll_sequence(cur_level)


func set_cur_state(s: STATE) -> void:  ## 0 = PASSIVE, 1 = ATTACK, 2 = DOWN
	state = s

func get_cur_state() -> STATE:
	return state


func set_clocking(switch: bool) -> void:  ## false to slow down time
	clocking = switch

func is_clocking() -> bool:
	return clocking


func get_stability() -> int:
	var stability: int = 0
	for t: String in timeline:
		var act: String = t.split(",")[1]
		if act == "s":
			stability += 1
	return stability

func get_hp() -> int:
	return resource.get_hp()


# ------------------------------
# INITIALIZING
# ------------------------------

func _duration_receive(duration: float) -> void:
	seq_gen.duration_receive(duration)



# ------------------------------
# SOLE ANIMATION PLAYER
# ------------------------------

func _play_animation(anim: StringName) -> void:
	animation.play(anim)


# ------------------------------
# ANIMATION SEQUENCING
# ------------------------------

func _get_random_trick() -> StringName:
	return act_data.random_trick()

func _get_random_attack() -> StringName:
	return act_data.random_attack()


func _get_next_trick(previous) -> StringName:
	return act_data.get_next_trick(previous)

func _get_next_attack(previous) -> StringName:
	return act_data.get_next_attack(previous)


# ------------------------------
# LOOP PROCESSORS
# ------------------------------

func _tick_time(delta) -> void:
	current_time = maxf(current_time - delta, 0.0)

func _tick_action_clock(delta) -> void:
	action_clock = maxf(action_clock - delta, 0.0)


func _next_action() -> Array:
	return timeline[0].split(",")

func _pop_front() -> void:
	timeline.pop_front()


func _take_action(act: String) -> void:
	if act == "t":
		if cur_idle == &"":
			cur_idle = _get_random_trick()
		else:
			cur_idle = _get_next_trick(cur_idle)
		_play_animation(cur_idle)
	
	if act == "s":
		if cur_idle == &"":
			cur_idle = _get_random_attack()
		else:
			cur_idle = _get_next_attack(cur_idle)
		_play_animation(cur_idle)


# ------------------------------
# MAIN LOOP
# ------------------------------

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not current_time <= 0.0:
		if not is_clocking():
			_tick_time(delta * slow_down)
		else:
			_tick_time(delta)
	else:
		enemy_timeout.emit()
		_play_animation(_get_random_attack())
		return
	
	if not action_clock == 0.0:
		if not is_clocking():
			_tick_action_clock(delta * slow_down)
		else:
			_tick_action_clock(delta)
		return
	
	if cur_act.is_empty():
		cur_act = _next_action()
		_pop_front()
	
	if cur_act.size() == 2:
		action_clock = cur_act[0]
		cur_act.pop_front()
	elif cur_act.size() == 1:
		_take_action(cur_act.pop_front())
