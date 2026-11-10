class_name EnemyProfile
extends Resource

## 0 selects a random pattern. Other values map to SequenceGenerator.SequenceType + 1.
@export_enum(
	"Random", "Balanced", "Rush Then Slow", "Delay Before Attack",
	"Burst Pause", "Slow Then Rush", "Bait And Strike", "Chaotic"
)
var sequence_pattern: int = 0

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
