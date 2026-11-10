class_name EnemyMove
extends Resource

enum Kind { ATTACK, TRICK }

@export var kind: Kind = Kind.ATTACK

## Stance names are arbitrary labels such as "left", "right", or "center".
@export var from_stance: StringName = &"center"
@export var to_stance: StringName = &"center"

## The only animation this move plays, inside Enemy's AnimationPlayer.
## Use property/method tracks to animate the sprite and combat windows.
@export var animation_name: StringName = &""

## Hidden migration fields for old EnemyMove resources.
@export_storage var timing_animation: StringName = &""
@export_storage var sprite_animation: StringName = &""


func get_animation_name() -> StringName:
	if animation_name != &"":
		return animation_name
	if timing_animation != &"":
		return timing_animation
	return sprite_animation
