extends Label
class_name Clocking
var countdown_time: float = 0:
	set(value):
		countdown_time=value
		text = "%.2f" % value
@export var enemy: Enemy


var clocking:bool=false

func _process(delta: float) -> void:
	if clocking:
		var delta_prime = delta if enemy.clocking else delta*enemy.slow_down
		countdown_time = maxf(countdown_time - delta_prime, 0.0)
		print (countdown_time)
