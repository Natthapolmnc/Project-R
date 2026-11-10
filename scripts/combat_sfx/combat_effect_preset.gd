class_name CombatEffectPreset
extends Resource

## An effect that either Player or Enemy can trigger through CombatFX.
@export var id: StringName = &""

@export_category("Particles")
@export var particle_scene: PackedScene
@export_range(0.1, 20.0, 0.1) var cleanup_seconds: float = 4.0

@export_category("Screen Shake")
@export_range(0.0, 1.0, 0.01) var shake_strength: float = 0.0
@export_range(0.0, 5.0, 0.01) var shake_duration: float = 0.20

@export_category("Screen Flash")
## Alpha 0 disables the flash.
@export var flash_color: Color = Color(1.0, 1.0, 1.0, 0.0)
@export_range(0.0, 5.0, 0.01) var flash_duration: float = 0.15
