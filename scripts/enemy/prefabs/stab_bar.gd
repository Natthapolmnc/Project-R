extends ProgressBar

@onready var enemy: Enemy = $"../../../../.."


func _ready() -> void:
	# A zero step means the bar can display fractional values smoothly.
	step = 0.0
	enemy.stability_changed.connect(_on_stability_changed)
	_on_stability_changed(enemy.get_stability(), enemy.profile.max_stab)


func _on_stability_changed(current: float, maximum: float) -> void:
	max_value = maximum
	value = maximum - current
