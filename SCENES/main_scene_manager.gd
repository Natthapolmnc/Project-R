
class_name MainSceneManager
extends Node

# ==============================
# NODES
# ==============================
@onready var player_spawner: Marker3D = $"../player_spawner"
@onready var player: Player = $"../player_spawner/Player"
@onready var enemy_spawner: Marker3D = $"../enemy_spawner"
@onready var fx_panel: MeshInstance3D = $"../FxPanel"
@onready var clock: Label = $"../Label"
@onready var retry: CanvasLayer = $"../Retry"
@onready var win: CanvasLayer = $"../Win"
@onready var tutorial: Tutorial = $"../Tutorial"
@onready var level_number: Label = $"../LevelNumber"


# ==============================
# 20-SECOND COUNTER
# ==============================
const base_time: float = 20.0
@export var cur_time: float = base_time


# ==============================
# ENEMY / LEVEL DATA
# ==============================
@export var enemy_template: PackedScene = preload("res://scripts/enemy/prefabs/enemy.tscn")

@export var cur_level: int = 4
@export var level: String = "res://scripts/enemy/level/"

var cur_level_profiles: Array[EnemyProfile] = []
var generated_time: Array[float] = []

var cur_enemy: Enemy
var cur_index: int = 0

var is_game_over: bool = false
var level_cleared: bool = false


# ==============================
# RANDOM SPAWN ROTATION
# ==============================
@export_category("Spawn Rotation")

@export_range(0.0, 180.0, 1.0)
var min_turn_angle: float = 45.0

@export_range(0.0, 180.0, 1.0)
var max_turn_angle: float = 135.0

@export_range(0.1, 3.0, 0.05)
var turn_duration: float = 0.65


# ==============================
# ROTATION STATE
# ==============================
var initial_player_yaw: float = 0.0

var initial_enemy_transform: Transform3D
var initial_enemy_offset: Vector3

var initial_fx_transform: Transform3D
var initial_fx_offset: Vector3

var current_turn_angle: float = 0.0
var is_turning: bool = false
var turn_tween: Tween


# ==============================
# TUTORIAL
# ==============================
enum TutorialStep {
	NONE,
	TRICK,
	PARRY,
	SLASH,
	TIMEOUT
}

var first_trick: bool = true
var first_parry: bool = true
var first_slash: bool = true
var first_timeout: bool = true

var action_tutorial_done: bool = false
var tutorial_done: bool = false

var tutorial_step: TutorialStep = TutorialStep.NONE
var timeout_tween: Tween


# ==============================
# READY
# ==============================
func _ready() -> void:
	initial_player_yaw = player_spawner.rotation.y

	initial_enemy_transform = enemy_spawner.global_transform
	initial_enemy_offset = (
		enemy_spawner.global_position
		- player_spawner.global_position
	)

	initial_fx_transform = fx_panel.global_transform
	initial_fx_offset = (
		fx_panel.global_position
		- player_spawner.global_position
	)

	tutorial.initialize()

	signal_connect()
	level_initialization(false)


# ==============================
# SIGNAL CONNECTIONS
# ==============================
func signal_connect() -> void:
	win.next_level_pressed.connect(
		level_initialization.bind(true)
	)

	win.retry_cur_level_pressed.connect(
		level_initialization.bind(false)
	)

	retry.retry_cur_level_pressed.connect(
		level_initialization.bind(false)
	)

	# Connect player signals only once.
	if player.has_signal("parrying"):
		player.connect(
			"parrying",
			Callable(self, "on_first_parry_success")
		)
	else:
		push_warning(
            "Player needs a 'parrying' signal."
		)

	if player.has_signal("slashing"):
		player.connect(
			"slashing",
			Callable(self, "on_first_slash_success")
		)
	else:
		push_warning(
            "Player needs a 'slashing' signal."
		)


# ==============================
# LEVEL LOADING
# ==============================
func load_level_profiles() -> void:
	cur_level_profiles.clear()

	var folder_path: String = level.path_join(
		"level" + str(cur_level)
	)

	var dir := DirAccess.open(folder_path)

	if dir == null:
		push_error(
			"Could not open folder: " + folder_path
		)
		return

	dir.list_dir_begin()

	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			if (
				file_name.ends_with(".tres")
				or file_name.ends_with(".tres.remap")
			):
				var clean_name: String = (
					file_name.trim_suffix(".remap")
				)

				var full_path: String = (
					folder_path.path_join(clean_name)
				)

				var profile := load(full_path) as EnemyProfile

				if profile != null:
					cur_level_profiles.append(profile)

		file_name = dir.get_next()

	dir.list_dir_end()


# ==============================
# LEVEL INITIALIZATION
# ==============================
func level_initialization(advance: bool) -> void:
	reset_tutorial_overlay()
	reset_spawn_rotation()
	clear_enemy()
	show_level()

	is_game_over = false
	level_cleared = false

	player.is_dead = false
	player.reset_scale()
	player.anim.play(player.idle_anim)

	if advance:
		cur_level += 1

	cur_time = base_time
	cur_index = 0

	clock.text = str(int(cur_time))

	retry.visible = false
	win.visible = false

	load_level_profiles()

	if cur_level_profiles.is_empty():
		push_warning(
            "No enemy profiles found for level "
			+ str(cur_level)
		)
		player.set_receive_input(false)
		return

	generated_time = split_time_randomly(
		base_time,
		cur_level_profiles.size(),
		(base_time / float(cur_level_profiles.size())) - 0.5
	)

	player.set_receive_input(true)
	spawn_enemy()


# ==============================
# ENEMY SPAWNING
# ==============================
func spawn_enemy(pause_enemy: bool = false) -> void:
	if cur_index >= cur_level_profiles.size():
		return
	if cur_level == 3:
		spawn_boss(false)
		return
	
	var profile: EnemyProfile = cur_level_profiles[cur_index]
	var duration: float = generated_time[cur_index]

	cur_index += 1

	cur_enemy = enemy_template.instantiate() as Enemy
	if cur_level_profiles.size() == 1:
		cur_enemy.resource.base_hp = 3

	if cur_enemy == null:
		push_error(
            "Enemy template must instantiate an Enemy."
		)
		return

	cur_enemy.set_profile(profile)
	cur_enemy.set_duration(duration)

	if pause_enemy:
		cur_enemy.process_mode = Node.PROCESS_MODE_DISABLED

	player.cur_enemy = cur_enemy

	cur_enemy.enemy_delta.connect(time_tick)
	cur_enemy.enemy_timeout.connect(game_over)
	cur_enemy.strike_reached.connect(game_over)
	cur_enemy.enemy_died.connect(on_enemy_died)

	display_enemy()
	
	# Connect tutorial events until completed.
	if not tutorial_done:
		if not action_tutorial_done:
			cur_enemy.state_changed.connect(on_first_parry)
			cur_enemy.state_changed.connect(on_first_slash)

		if first_timeout:
			cur_enemy.enemy_timeout.connect(on_enemy_timeout)
		
		if first_trick:
			cur_enemy.timing_player.animation_started.connect(on_first_trick)


func spawn_boss(pause_enemy: bool = false) -> void:
	if cur_index >= cur_level_profiles.size():
		return

	#var profile: EnemyProfile = cur_level_profiles[cur_index]
	#var duration: float = generated_time[cur_index]

	cur_index += 1

	#cur_enemy = enemy_template.instantiate() as Enemy

	#if cur_enemy == null:
		#push_error(
			#"Enemy template must instantiate an Enemy."
		#)
		#return
#
	#cur_enemy.set_profile(profile)
	#cur_enemy.set_duration(duration)

	if pause_enemy:
		cur_enemy.process_mode = Node.PROCESS_MODE_DISABLED

	player.cur_enemy = cur_enemy

	cur_enemy.enemy_delta.connect(time_tick)
	cur_enemy.enemy_timeout.connect(game_over)
	cur_enemy.strike_reached.connect(game_over)
	cur_enemy.enemy_died.connect(on_enemy_died)

	display_enemy()


func display_enemy() -> void:
	clear_enemy()
	enemy_spawner.add_child(cur_enemy)


func clear_enemy() -> void:
	for child in enemy_spawner.get_children():
		if child is Enemy:
			enemy_spawner.remove_child(child)
			child.queue_free()


func on_enemy_died() -> void:
	if is_game_over or level_cleared or is_turning:
		return

	if cur_index < cur_level_profiles.size():
		rotate_to_next_enemy.call_deferred()
	else:
		on_level_clear()


func on_level_clear() -> void:
	victory()


# ==============================
# RANDOM TURN ANGLE
# ==============================
func get_random_turn_angle() -> float:
	var upper_angle: float = clampf(
		max_turn_angle,
		0.0,
		180.0
	)

	var lower_angle: float = clampf(
		min_turn_angle,
		0.0,
		upper_angle
	)

	var angle: float = randf_range(
		lower_angle,
		upper_angle
	)

	# 50% left and 50% right.
	if randf() < 0.5:
		angle = -angle

	return angle


# ==============================
# ROTATE TO NEXT ENEMY
# ==============================
func rotate_to_next_enemy() -> void:
	if is_game_over or level_cleared or is_turning:
		return

	if cur_index >= cur_level_profiles.size():
		return

	is_turning = true

	player.set_receive_input(false)
	clear_enemy()

	# Remember the previous rotation.
	var previous_turn_angle: float = current_turn_angle

	# Generate and accumulate random rotation.
	current_turn_angle += deg_to_rad(
		get_random_turn_angle()
	)

	var rotation_basis := Basis(
		Vector3.UP,
		current_turn_angle
	)

	# Rotate enemy position around the player.
	var next_transform: Transform3D = initial_enemy_transform

	next_transform.origin = (
		player_spawner.global_position
		+ rotation_basis * initial_enemy_offset
	)

	# Rotate enemy orientation.
	next_transform.basis = (
		rotation_basis * initial_enemy_transform.basis
	)

	enemy_spawner.global_transform = next_transform

	# Spawn enemy but disable its processing.
	spawn_enemy(true)

	# Smoothly rotate player and FX panel together.
	turn_tween = create_tween()

	turn_tween.set_trans(Tween.TRANS_SINE)
	turn_tween.set_ease(Tween.EASE_IN_OUT)

	turn_tween.tween_method(
		apply_turn_angle,
		previous_turn_angle,
		current_turn_angle,
		turn_duration
	)

	turn_tween.finished.connect(on_turn_finished)


# ==============================
# APPLY ROTATION TO PLAYER + FX
# ==============================
func apply_turn_angle(angle: float) -> void:
	# Rotate player.
	player_spawner.rotation.y = initial_player_yaw + angle

	# Rotate FX panel around player.
	var rotation_basis := Basis(
		Vector3.UP,
		angle
	)

	var fx_transform: Transform3D = initial_fx_transform

	# Preserve the FX panel's offset from player.
	fx_transform.origin = (
		player_spawner.global_position
		+ rotation_basis * initial_fx_offset
	)

	# Rotate FX panel orientation.
	fx_transform.basis = (
		rotation_basis * initial_fx_transform.basis
	)

	fx_panel.global_transform = fx_transform


# ==============================
# ROTATION FINISHED
# ==============================
func on_turn_finished() -> void:
	if not is_turning or is_game_over or level_cleared:
		return

	is_turning = false

	# Reactivate enemy after rotation.
	if is_instance_valid(cur_enemy):
		cur_enemy.process_mode = Node.PROCESS_MODE_INHERIT

	player.set_receive_input(true)


# ==============================
# RESET ROTATION
# ==============================
func reset_spawn_rotation() -> void:
	if turn_tween != null and turn_tween.is_valid():
		turn_tween.kill()

	is_turning = false
	current_turn_angle = 0.0

	player_spawner.rotation.y = initial_player_yaw
	enemy_spawner.global_transform = initial_enemy_transform

	# Restore FX panel to its original position and rotation.
	fx_panel.global_transform = initial_fx_transform


# ==============================
# TIME DISTRIBUTION
# ==============================
func split_time_randomly(
	total_time: float,
	pieces: int,
	min_value: float
) -> Array[float]:

	var result: Array[float] = []

	if pieces <= 0:
		return result

	var remaining_time: float = (
		total_time - float(pieces) * min_value
	)

	if remaining_time <= 0.0:
		for i in range(pieces):
			result.append(total_time / float(pieces))

		return result

	var weights: Array[float] = []
	var weight_sum: float = 0.0

	for i in range(pieces):
		var weight: float = randf_range(0.001, 1.0)

		weights.append(weight)
		weight_sum += weight

	for i in range(pieces):
		var piece: float = (
			min_value
			+ (weights[i] / weight_sum) * remaining_time
		)
		result.append(piece)

	return result


# ==============================
# 20-SECOND COUNTER
# ==============================
func time_tick(delta: float) -> void:
	if is_game_over or level_cleared:
		return

	cur_time = maxf(cur_time - delta, 0.0)
	clock.text = str(int(cur_time))

	if cur_time <= 0.0 and is_instance_valid(cur_enemy):
		if (
			cur_enemy.can_be_attacked()
			or cur_enemy.can_be_parried()
		):
			game_over()


# ==============================
# GAME OVER
# ==============================
func game_over(_arg = null) -> void:
	if is_game_over or level_cleared:
		return

	is_game_over = true

	CombatFx.trigger(
		"blood",
		player.get_fx_panel()
	)

	player.on_dead()

	retry.visible = true
	player.set_receive_input(false)


# ==============================
# VICTORY
# ==============================
func victory() -> void:
	if is_game_over or level_cleared:
		return

	level_cleared = true

	if cur_level == 5:
		win.set_advance(false)
	else:
		win.set_advance(true)
	
	win.visible = true
	player.set_receive_input(false)


#==============================
#TUTORIAL: FIRST Trick
#==============================
func on_first_trick(anim_name: String) -> void:
	if not anim_name.begins_with("trick"):
		return

	if tutorial_done or not first_trick:
		return

	if tutorial_step != TutorialStep.NONE:
		return

	cur_enemy.timing_player.animation_started.disconnect(on_first_trick)

	tutorial_step = TutorialStep.TRICK

	tutorial.visible = true
	tutorial.first_trick.visible = true

	player.set_receive_input(false)

	Engine.time_scale = 1e-6

	await get_tree().create_timer(1.5, true, false, true).timeout
	on_trick_tutorial_finished()


func on_trick_tutorial_finished() -> void:
	if tutorial_step != TutorialStep.TRICK:
		return

	first_trick = false
	tutorial_step = TutorialStep.NONE

	player.set_receive_input(true)

	Engine.time_scale = 1.0
	hide_tutorial()


# ==============================
# TUTORIAL: FIRST PARRY
# ==============================
func on_first_parry(state: Enemy.State) -> void:
	
	if tutorial_done or action_tutorial_done or not first_parry:
		return

	if (
		tutorial_step != TutorialStep.NONE
		or state != Enemy.State.ATTACK
	):
		return
	if not player.has_signal("parrying"):
		return

	player.on_first_parry()

	tutorial_step = TutorialStep.PARRY

	tutorial.visible = true
	tutorial.first_parry.visible = true

	Engine.time_scale = 0.000001


func on_first_parry_success() -> void:
	if tutorial_step != TutorialStep.PARRY:
		return

	first_parry = false
	tutorial_step = TutorialStep.NONE

	hide_tutorial()
	Engine.time_scale = 1.0

	# The enemy may already have entered DOWN.
	if is_instance_valid(cur_enemy):
		if cur_enemy.state == Enemy.State.DOWN:
			on_first_slash(Enemy.State.DOWN)


# ==============================
# TUTORIAL: FIRST SLASH
# ==============================
func on_first_slash(state: Enemy.State) -> void:
	if (
		tutorial_done
		or action_tutorial_done
		or not first_slash
		or first_parry
	):
		return

	if (
		tutorial_step != TutorialStep.NONE
		or state != Enemy.State.DOWN
	):
		return

	if not player.has_signal("slashing"):
		return

	player.on_first_slash()
	
	tutorial_step = TutorialStep.SLASH

	tutorial.visible = true
	tutorial.first_slash.visible = true

	Engine.time_scale = 0.000001


func on_first_slash_success() -> void:
	if tutorial_step != TutorialStep.SLASH:
		return

	first_slash = false
	action_tutorial_done = true
	tutorial_step = TutorialStep.NONE

	hide_tutorial()
	Engine.time_scale = 1.0


# ==============================
# TUTORIAL: FIRST TIMEOUT
# ==============================
func on_enemy_timeout() -> void:
	if tutorial_done or not first_timeout:
		return

	if tutorial_step != TutorialStep.NONE:
		return

	tutorial_step = TutorialStep.TIMEOUT

	tutorial.visible = true
	tutorial.first_timeout.visible = true

	Engine.time_scale = 0.2

	# Tween uses real time, ignoring Engine.time_scale.
	timeout_tween = create_tween()
	timeout_tween.set_ignore_time_scale(true)

	timeout_tween.tween_property(
		Engine,
		"time_scale",
		1.0,
		5
	)

	timeout_tween.finished.connect(
		on_timeout_tutorial_finished
	)


func on_timeout_tutorial_finished() -> void:
	if tutorial_step != TutorialStep.TIMEOUT:
		return

	first_timeout = false
	tutorial_done = true
	tutorial_step = TutorialStep.NONE

	Engine.time_scale = 1.0
	hide_tutorial()


# ==============================
# TUTORIAL UI
# ==============================
func hide_tutorial() -> void:
	tutorial.first_parry.visible = false
	tutorial.first_slash.visible = false
	tutorial.first_timeout.visible = false
	tutorial.first_trick.visible = false

	tutorial.visible = false


func reset_tutorial_overlay() -> void:
	if timeout_tween != null and timeout_tween.is_valid():
		timeout_tween.kill()

	tutorial_step = TutorialStep.NONE
	Engine.time_scale = 1.0

	hide_tutorial()


# ==============================
# SHOW LEVEL NUMBER
# ==============================
func show_level() -> void:
	level_number.text = str("Level: ", cur_level)
