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


func _ready() -> void:
	anim.animation_finished.connect(_animation_ending_handler)
	anim.play(idle_anim)

func _action_handler()->void:
	if is_stun or not receive_input:
		return
	
	if Input.is_action_just_pressed("slash"):
		if not cur_enemy: anim.play(slash_anim_lst.pick_random()); return
		
		anim.play(slash_anim_lst.pick_random())
		if (cur_enemy.state==Enemy.State.DOWN):
			slashing.emit()
			cur_enemy.receive_hit()
			CombatFx.trigger("blood", fx_panel)
			AudioPlayer.play_slash()
		elif (cur_enemy.timing_player.current_animation.begins_with("idle")):
			cur_enemy.on_dodge()
			anim.queue(stun_anim)
			is_stun = true
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
