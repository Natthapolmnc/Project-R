extends Node
class_name Tutorial


var first_parry: Control
var first_slash: Control
var first_timeout: Control
var first_trick: Control




func initialize():
	first_parry = $FirstParry
	first_slash = $FirstSlash
	first_timeout = $FirstTimeout
	first_trick = $FirstTrick
