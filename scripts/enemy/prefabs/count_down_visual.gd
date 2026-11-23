extends Label
class_name Clocking
@export var countdown_time: float = 20.0
@export var enemy: Enemy


var clocking:bool=false

func _process(delta: float) -> void:
	if clocking:
		var delta_prime = delta if enemy.clocking else delta*enemy.slow_down
		if countdown_time > 0.0:
			countdown_time = maxf(countdown_time - delta_prime, 0.0)
		
		text = "%.2f" % countdown_time
