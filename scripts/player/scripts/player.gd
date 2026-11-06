extends Node3D
class_name Player

@onready var visual: AnimatedSprite3D = $visual
@export var idle_anim:String="Idle"
@export var ready_anim:String="ready"
@export var parry_anim:String="parry"
@export var slash_anim_lst: Array[String] = [
	"slash_d2u",
	"slash_u2d",
	"slash_l2r"
	
]
@export var cur_enemy:Enemy

var is_stun=false

func _ready() -> void:
	visual.animation_finished.connect(_animation_ending_handler)
	visual.play("idle")

func _action_handler()->void:
	if Input.is_action_just_pressed("slash"):
		visual.play(slash_anim_lst.pick_random())
		if (cur_enemy.state==Enemy.STATE.DOWN):
			pass
			
	if Input.is_action_just_pressed("parry"):
		visual.play("parry")
		if (cur_enemy.state==Enemy.STATE.ATTACK):
			cur_enemy.got_parried()
		else:
			visual.play("stun_lock")
			is_stun=true
		
		

func _animation_ending_handler()->void:
	visual.play("idle")
	if is_stun:
		is_stun=false
	
func _process(delta: float) -> void:
	_action_handler()
	pass
