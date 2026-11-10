class_name EnemyMove
extends Resource

enum Kind { ATTACK, TRICK }

@export var kind: Kind = Kind.ATTACK

## Stance names are arbitrary labels such as "left", "right", or "center".
@export var from_stance: StringName = &"center"
@export var to_stance: StringName = &"center"

## Name inside AnimatedSprite3D's SpriteFrames.
@export var sprite_animation: StringName = &""

## Name inside AnimationPlayer. Use method keys to control combat windows.
@export var timing_animation: StringName = &""
