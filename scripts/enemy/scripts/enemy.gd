class_name Enemy
extends Node3D


@export_category("Resoruces")
@export var resource :CharacterResource= CharacterResource.new()
@export var seq_gen :SequenceGenerator = SequenceGenerator.new() ### ฝากแก้
@export var act_data :ActionDatabase = ActionDatabase.new()


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
var current_time: float ## Time always tick

var action_clock: float = 0.0  ## To think the wait before actions
var clocking: bool = true

@export var slow_down: float = 0.5


# ------ ANIMATION ------
@export_category("ANIMATION")
@export var animation: AnimatedSprite3D
var animation_counter: float = 0.0


## emit when this enemy is alive when its current_time is fully depleted, indicating the player has lost
signal enemy_timeout 


# ------------------------------
# INTERFACE
# ------------------------------
func _ready() -> void:
	var animation_names: PackedStringArray = animation.sprite_frames.get_animation_names()
	
	for name in animation_names:
		
		var prefix = name.split("_")[0]
		var suffix = name.split("_")[1]
		act_data.possible_next_idle[name]=[]
		if (prefix=="idle"):
			act_data.all_idle.append(name)
			act_data.possible_next_attack[name]=[]

			act_data.possible_next_trick[name]=[]
	
	for name in animation_names:
		
		var prefix = name.split("_")[0]
		var suffix = name.split("_")[1]

		if (prefix=="slash"):
			act_data.all_attack.append(name)
			act_data.possible_next_attack["idle_"+suffix].append(name)
			act_data.possible_next_idle[name].append("idle_"+suffix)
		if (prefix=="trick"):
			act_data.all_tricks.append(name)
			var sufsuf=suffix.split("2")
			act_data.possible_next_trick["idle_"+sufsuf[0]].append(name)
			act_data.possible_next_idle[name].append("idle_"+sufsuf[0])
			
	animation.animation_finished.connect(_on_animation_finish_handler)
	animation.play(act_data.all_idle.pick_random())
	on_start()
	
		

func on_start() -> void:
	current_time = seq_gen.get_duration()
	#timeline = seq_gen.roll_sequence(cur_level)
	#print (timeline)
	timeline = ["2,t", "2,s","1,t","1,s"]


func set_cur_state(s: STATE) -> void:  ## 0 = PASSIVE, 1 = ATTACK, 2 = DOWN
	state = s

func get_cur_state() -> STATE:
	return state


func set_clocking(switch: bool) -> void:  ## false to slow down time
	clocking = switch

func is_clocking() -> bool:
	return clocking


func get_stability() -> int:
	return resource.cur_stab

func get_hp() -> int:
	return resource.get_hp()

func got_parried()->void:
	resource.cur_stab-=1
	if resource.cur_stab<=0:
		set_cur_state(Enemy.STATE.DOWN)
		resource.recover_from_down()

# ------------------------------
# INITIALIZING
# ------------------------------

func _duration_receive(duration: float) -> void:
	seq_gen.duration_receive(duration)



# ------------------------------
# SOLE ANIMATION PLAYER
# ------------------------------

func _play_animation(anim: StringName) -> void:
	if animation:
		animation.play(anim)

func _on_animation_finish_handler():
	animation.play(act_data.possible_next_idle[animation.animation].pick_random())
	
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
		action_clock = float(cur_act[0])
		cur_act.pop_front()
	elif cur_act.size() == 1:
		_take_action(cur_act.pop_front())
