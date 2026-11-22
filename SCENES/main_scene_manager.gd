class_name MainSceneManager
extends Node

# ------ Node ------
@onready var player: Player = $"../player_spawner/Player"
@onready var enemy_spawner: Marker3D = $"../enemy_spawner"
@onready var clock: Label = $"../Label"
@onready var retry: CanvasLayer = $"../Retry"
@onready var win: CanvasLayer = $"../Win"
@onready var tutorial: CanvasLayer = $"../Tutorial"


# ------ 20 Secs Counter ------
const base_time: float = 20.0
@export var cur_time: float = base_time

# ------ Enemy Assigner ------
@export var enemy_template: PackedScene = preload("res://scripts/enemy/prefabs/enemy.tscn")
@export var cur_level: int = 1
@export var level: String = "res://scripts/enemy/level/"
var cur_level_profiles: Array[EnemyProfile] = []

var cur_enemy: Enemy
var cur_index: int = 0

# ------ Time Distributer ------
var generated_time: Array[float] = []


# Engine.set_time_scale(0)
var first_parry: bool = true
var first_slash: bool = true
var first_timeout: bool = true
var action_tutorial_done: bool = false
var tutorial_done: bool = false


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	signal_connect()
	level_initialization(false)


func signal_connect() -> void:
	win.next_level_pressed.connect(level_initialization.bind(true))
	win.retry_cur_level_pressed.connect(level_initialization.bind(false))
	retry.retry_cur_level_pressed.connect(level_initialization.bind(false))


func load_level_profiles() -> void:
	cur_level_profiles.clear()
	
	# Builds "res://scripts/enemy/level/level1"
	var folder_path: String = level.path_join("level" + str(cur_level))
	var dir := DirAccess.open(folder_path)
	
	if dir == null:
		push_error("Could not open folder: " + folder_path)
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		# Ignore hidden files and subfolders
		if not dir.current_is_dir():
			# IMPORTANT: Handle ".tres.remap" so it still works after exporting your game!
			if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
				var clean_name: String = file_name.trim_suffix(".remap")
				var full_path: String = folder_path.path_join(clean_name)
				var profile := load(full_path) as EnemyProfile
				if profile != null:
					cur_level_profiles.append(profile)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()


func level_initialization(advance: bool) -> void:
	player.is_dead = false
	player.reset_scale()
	player.anim.play(player.idle_anim)
	if advance:
		cur_level += 1
	
	cur_time = base_time
	cur_index = 0
	player.set_receive_input(true)
	load_level_profiles()
	generated_time = split_time_randomly(20.0, cur_level_profiles.size(), (20.0/cur_level_profiles.size()) - 1)
	spawn_enemy()


## instance new enemy -> distribute time -> assign new enemy to player
func spawn_enemy() -> void:
	var profile: EnemyProfile = cur_level_profiles[cur_index]
	var duration: float = generated_time[cur_index]
	cur_index += 1
	
	cur_enemy = enemy_template.instantiate()
	
	cur_enemy.set_profile(profile)
	cur_enemy.set_duration(duration)
	
	player.cur_enemy = cur_enemy
	
	cur_enemy.enemy_delta.connect(time_tick)
	cur_enemy.enemy_timeout.connect(game_over)
	cur_enemy.strike_reached.connect(game_over)
	cur_enemy.enemy_died.connect(on_enemy_died)
	
	display_enemy()
	
	if not tutorial_done:
		if not action_tutorial_done:
			cur_enemy.state_changed.connect(on_first_parry)
			cur_enemy.state_changed.connect(on_first_slash)
		cur_enemy.enemy_timeout.connect(on_enemy_timeout)


func display_enemy() -> void:
	if not enemy_spawner.get_children().is_empty():
		enemy_spawner.get_child(0).queue_free()
	enemy_spawner.add_child(cur_enemy)


func on_enemy_died() -> void:
	if not cur_index == cur_level_profiles.size():
		spawn_enemy()
	else:
		on_level_clear()


func on_level_clear() -> void:
	victory()


## Read size of level folder and randomly separate 20 secs into the size
func split_time_randomly(total_time: float, pieces: int, min_value: float) -> Array[float]:
	var result: Array[float] = []
	var remaining_time: float = total_time - (pieces * min_value)
	
	# Safety check if the minimum requirement exceeds total_time
	if remaining_time <= 0.0:
		var equal_share: float = total_time / pieces
		for i in range(pieces):
			result.append(equal_share)
		return result
	
	# Generate random weights for each piece
	var weights: Array[float] = []
	var weight_sum: float = 0.0
	for i in range(pieces):
		var w: float = randf()
		weights.append(w)
		weight_sum += w
	
	# Add each piece's proportional share of remaining_time on top of min_value
	for i in range(pieces):
		var piece: float = min_value + (weights[i] / weight_sum) * remaining_time
		result.append(piece)
	
	return result


# ==============================
# 20 SECS COUNTER
# ==============================
func time_tick(delta: float) -> void:
	cur_time = maxf(cur_time - delta, 0.0)
	clock.text = str(int(cur_time))
	if cur_time == 0.0 and not cur_index == (cur_level_profiles.size() - 1) and(
		player.cur_enemy.can_be_attacked() or player.cur_enemy.can_be_parried()
	):
		game_over()


# ==============================
# GAME STATE HANDLER
# ==============================
func game_over(_arg = null) -> void:
	CombatFx.trigger("blood", player.get_fx_panel())
	player.on_dead()
	
	retry.visible = true
	
	player.set_receive_input(false)


func victory() -> void:
	win.visible = true
	player.set_receive_input(false)


# ==============================
# TUTORIAL
# ==============================
func on_first_parry(state: Enemy.State) -> void:
	if not state == Enemy.State.ATTACK:
		return
	if player.is_stun:
		player.is_stun = false
	tutorial.visible = true
	tutorial.first_parry.visible = true
	player.parrying.connect(on_first_parry_success, CONNECT_ONE_SHOT)
	Engine.set_time_scale(1e-6)

func on_first_parry_success() -> void:
	if not cur_enemy.can_be_parried():
		print(cur_enemy.can_be_parried())
		return
	Engine.set_time_scale(1)
	first_parry = false
	tutorial.visible = false
	tutorial.first_parry.visible = false


func on_first_slash(state: Enemy.State) -> void:
	if not state == Enemy.State.DOWN:
		return
	tutorial.visible = true
	tutorial.first_slash.visible = true
	player.slashing.connect(on_first_slash_success, CONNECT_ONE_SHOT)
	Engine.set_time_scale(1e-6)

func on_first_slash_success() -> void:
	if not cur_enemy.state == Enemy.State.DOWN:
		return
	Engine.set_time_scale(1)
	first_slash = false
	tutorial.visible = false
	tutorial.first_slash.visible = false
	action_tutorial_done = true

func on_enemy_timeout() -> void:
	first_timeout = false
	tutorial.visible = true
	tutorial.first_timeout.visible = true
	var tween: Tween = get_tree().create_tween()
	Engine.set_time_scale(0.2)
	tween.tween_property(Engine, "time_scale", 1, 3)
	await tween.finished
	tutorial.visible = false
	tutorial_done = true
