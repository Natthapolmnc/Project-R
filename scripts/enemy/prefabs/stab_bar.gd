
extends ProgressBar

@onready var enemy: Enemy = $"../../../../.."


func _ready() -> void:
	enemy.stability_changed.connect(_on_stability_changed)

	# Initialize UI
	_on_stability_changed(
		enemy.get_stability(),
		enemy.resource.max_stab
	)


func _on_stability_changed(current: int, maximum: int) -> void:
	max_value = maximum
	value = maximum - current
