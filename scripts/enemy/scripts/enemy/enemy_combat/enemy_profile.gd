class_name EnemyProfile
extends Resource

## 0 selects a random pattern. Other values map to SequenceGenerator.SequenceType + 1.
@export_enum(
	"Random", "Balanced", "Rush Then Slow", "Delay Before Attack",
	"Burst Pause", "Slow Then Rush", "Bait And Strike", "Chaotic"
)
var sequence_pattern: int = 0

@export var base_hp: int = 1
@export var max_stab: int = 1

var cur_hp: int = 1
var cur_stab: float = 1


func on_start() -> void:
	cur_hp = base_hp
	cur_stab = max_stab


func on_being_finished() -> void:
	cur_hp = maxi(cur_hp - 1, 0)


func recover_from_down() -> void:
	cur_stab = max_stab


func is_dead() -> bool:
	return cur_hp <= 0


func get_hp() -> int:
	return cur_hp


func get_base_hp() -> int:
	return base_hp

@export var initial_stance: StringName = &"center"
@export var idle_by_stance: Dictionary[StringName, StringName] = {
	&"center": &"idle_center"
}
@export var down_animation: StringName = &"down"
@export var death_animation: StringName = &"death"

@export var moves: Array[EnemyMove] = []


func get_idle(stance: StringName) -> StringName:
	return idle_by_stance.get(stance, &"")


func pick_move(code: String, stance: StringName) -> EnemyMove:
	var desired_kind: EnemyMove.Kind = (
		EnemyMove.Kind.ATTACK if code == "a" else EnemyMove.Kind.TRICK
	)
	var options: Array[EnemyMove] = []
	for move in moves:
		if move != null and move.kind == desired_kind and move.from_stance == stance:
			options.append(move)
	if options.is_empty():
		return null
	return options.pick_random()
