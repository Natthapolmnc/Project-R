extends Node3D
class_name Player

signal parrying
signal slashing


@onready var fx_panel: MeshInstance3D = $"../../FxPanel"
@onready var player_fx_panel: MeshInstance3D = $MeshInstance3D


@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var visual: AnimatedSprite3D = $visual
@onready var weapon: Sprite3D = $weapon

@export var idle_anim: StringName = &"idle"
@export var parry_anim: StringName = &"parry"
@export var stun_anim: StringName = &"stun_lock"
@export var slash_anim_lst: Array[String] = [
	&"slash_d2u",
	&"slash_u2d",
	&"slash_l2r"
	
]
@export var cur_enemy:Enemy


var is_stun: bool = false
var receive_input: bool = true
var is_dead: bool = true

# Tutorial
var is_on_first_parry: bool = false
var is_on_first_slash: bool = false


func _ready() -> void:
	anim.animation_finished.connect(_animation_ending_handler)
	anim.play(idle_anim)

func _action_handler()->void:
	if is_stun or not receive_input:
		return
	
	if is_on_first_parry and not Input.is_action_just_pressed("parry"):
		return
	
	if is_on_first_slash and not Input.is_action_just_pressed("slash"):
		return
	
	if Input.is_action_just_pressed("slash"):
		if not cur_enemy: anim.play(slash_anim_lst.pick_random()); return
		
		anim.play(slash_anim_lst.pick_random())
		if (cur_enemy.state==Enemy.State.DOWN):
			slashing.emit()
			cur_enemy.receive_hit()
			CombatFx.trigger("blood", cur_enemy.effect_origin)
			AudioPlayer.play_slash()
			if is_on_first_slash:
					is_on_first_slash = false
		elif (cur_enemy.timing_player.current_animation.begins_with("idle")):
			cur_enemy.on_dodge()
			if not anim.animation_changed.is_connected(set_stun):
				anim.animation_changed.connect(set_stun.bind(true), CONNECT_ONE_SHOT)
			anim.queue(stun_anim)
			AudioPlayer.play_slash_fail()
		else:
			anim.play(stun_anim)
			is_stun = true
			AudioPlayer.play_slash_fail()
		
	if Input.is_action_just_pressed("parry"):
		if not cur_enemy: anim.play(parry_anim); return
		if (cur_enemy.state==Enemy.State.ATTACK):
			parrying.emit()
			AudioPlayer.play_parry()
			if cur_enemy.receive_parry():
				anim.play(parry_anim)
				CombatFx.trigger("parry", fx_panel)
				AudioPlayer.play_parry_success()
				if is_on_first_parry:
					is_on_first_parry = false
			else:
				anim.play(stun_anim)
				is_stun = true
		else:
			anim.play(stun_anim)
			is_stun = true


func _animation_ending_handler(_arg)->void:
	if not is_dead:
		anim.play(idle_anim)
	if is_stun:
		is_stun = false


func _process(_delta: float) -> void:
	_action_handler()
	pass


# ==============================
# TUTORIAL: FIRST PARRY
# ==============================

func on_first_parry() -> void:
	is_stun = false
	is_on_first_parry = true


# ==============================
# TUTORIAL: FIRST SLASH
# ==============================

func on_first_slash() -> void:
	is_stun = false
	is_on_first_slash = true


# ==============================
# 
# ==============================

func get_fx_panel() -> MeshInstance3D:
	return player_fx_panel


func set_receive_input(value: bool) -> void:
	receive_input = value


func on_dead() -> void:
	is_stun = false
	is_dead = true
	anim.play("die")
	cur_enemy.set_process(false)


func reset_scale() -> void:
	visual.scale = Vector3(1, 1, 1)


func set_stun(_arg, _args, value: bool) -> void:
	is_stun = value


func _animation_play_black_stun_flash() -> void:
	CombatFx.trigger("stun")
