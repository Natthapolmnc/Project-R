class_name SceneManager
extends Node

# ------ Node ------
@onready var player: Player = $"../player_spawner/Player"
@onready var enemy_spawner: Marker3D = $"../enemy_spawner"
@onready var clock: Label3D = $"../Label3D"


# ------ 20 Secs Counter ------
const base_time: float = 20.0
@export var cur_time: float = base_time

# ------ Enemy Assigner ------
@export var enemy_template: PackedScene = preload("res://scripts/enemy/prefabs/enemy.tscn")
@export var cur_level: int = 1
@export var level_1: Array[EnemyProfile] = [
	preload("res://scripts/enemy/level/basic_enemy1.tres"),
	preload("res://scripts/enemy/level/basic_enemy2.tres"),
	preload("res://scripts/enemy/level/basic_enemy3.tres"),
	preload("res://scripts/enemy/level/basic_enemy4.tres"),
	preload("res://scripts/enemy/level/basic_enemy5.tres")]

var cur_enemy: Enemy
var cur_index: int = 0

# ------ Time Distributer ------
var generated_time: Array[float] = []



## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	level_initialization()


func level_initialization() -> void:
	generated_time = split_time_randomly(20.0, level_1.size(), (20.0/level_1.size()) - 1)
	spawn_enemy()


## instance new enemy -> distribute time -> assign new enemy to player
func spawn_enemy() -> void:
	var profile: EnemyProfile = level_1[cur_index]
	var duration: float = generated_time[cur_index]
	cur_index += 1
	
	cur_enemy = enemy_template.instantiate()
	
	cur_enemy.set_profile(profile)
	cur_enemy.set_duration(duration)
	
	player.cur_enemy = cur_enemy
	
	cur_enemy.enemy_is_finished
	cur_enemy.enemy_delta.connect(time_tick)
	cur_enemy.enemy_timeout.connect(game_over)
	cur_enemy.strike_reached.connect(game_over)
	cur_enemy.enemy_died.connect(on_enemy_died)
	
	display_enemy()


func display_enemy() -> void:
	if not enemy_spawner.get_children().is_empty():
		enemy_spawner.get_child(0).queue_free()
	enemy_spawner.add_child(cur_enemy)


func on_enemy_died() -> void:
	if not cur_index == level_1.size():
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
	if cur_time == 0.0:
		game_over()


# ==============================
# GAME STATE HANDLER
# ==============================
func game_over(_arg = null) -> void:
	CombatFx.trigger("blood", player.get_fx_panel())
	print("GAMEOVER")


func victory() -> void:
	print("WON")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
