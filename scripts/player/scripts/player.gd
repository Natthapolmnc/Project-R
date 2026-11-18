extends Node3D
class_name Player


@onready var fx_panel: MeshInstance3D = $"../../FxPanel"
@onready var player_fx_panel: MeshInstance3D = $MeshInstance3D


@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var visual: AnimatedSprite3D = $visual
@export var idle_anim: StringName = &"RESET"
@export var parry_anim: StringName = &"parry"
@export var stun_anim: StringName = &"stun_lock"
@export var slash_anim_lst: Array[String] = [
	&"slash_d2u",
	&"slash_u2d",
	&"slash_l2r"
	
]
@export var cur_enemy:Enemy


var is_stun=false


func _ready() -> void:
	anim.animation_finished.connect(_animation_ending_handler)
	anim.play(idle_anim)

func _action_handler()->void:
	if is_stun:
		return
	
	if Input.is_action_just_pressed("slash"):
		if not cur_enemy: anim.play(slash_anim_lst.pick_random()); return
		if (cur_enemy.state==Enemy.State.DOWN):
			anim.play(slash_anim_lst.pick_random())
			cur_enemy.receive_hit()
			CombatFx.trigger("blood", fx_panel)
		else:
			anim.play(stun_anim)
			is_stun = true
			
	if Input.is_action_just_pressed("parry"):
		if not cur_enemy: anim.play(parry_anim); return
		if (cur_enemy.state==Enemy.State.ATTACK):
			if cur_enemy.receive_parry():
				anim.play(parry_anim)
				CombatFx.trigger("parry", fx_panel)
			else:
				anim.play(stun_anim)
				is_stun = true
		else:
			anim.play(stun_anim)
			is_stun = true


func _animation_ending_handler(_arg)->void:
	anim.play(idle_anim)
	if is_stun:
		is_stun = false
	
func _process(_delta: float) -> void:
	_action_handler()
	pass


func get_fx_panel() -> MeshInstance3D:
	return player_fx_panel
