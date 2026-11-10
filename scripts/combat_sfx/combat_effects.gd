class_name CombatEffects
extends Node

## Add combat_fx.tscn as an Autoload named "CombatFX".
## Both Player and Enemy can then request effects from one shared manager.

@export var presets: Array[CombatEffectPreset] = []
@export_range(1, 200, 1) var flash_canvas_layer: int = 100

var _flash_rect: ColorRect
var _flash_tween: Tween
var _shake_camera: Camera3D
var _shake_remaining: float = 0.0
var _shake_strength: float = 0.0
var _base_h_offset: float = 0.0
var _base_v_offset: float = 0.0


func _ready() -> void:
	# One overlay for the entire game, regardless of which character triggers it.
	var layer := CanvasLayer.new()
	layer.name = "CombatScreenOverlay"
	layer.layer = flash_canvas_layer
	add_child(layer)

	_flash_rect = ColorRect.new()
	_flash_rect.name = "Flash"
	_flash_rect.color = Color.TRANSPARENT
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash_rect)
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Main hook: call CombatFX.trigger(&"parry", attacker_or_marker).
## The preset may spawn particles, shake the camera and flash the screen.
func trigger(effect_id: StringName, origin: Node3D = null) -> void:
	var preset: CombatEffectPreset = _find_preset(effect_id)
	if preset == null:
		push_warning("CombatFX: unknown effect '%s'" % effect_id)
		return

	if preset.particle_scene != null:
		_spawn_particle(preset.particle_scene, origin, preset.cleanup_seconds)

	if preset.shake_strength > 0.0 and preset.shake_duration > 0.0:
		shake_screen(preset.shake_strength, preset.shake_duration)

	if preset.flash_color.a > 0.0 and preset.flash_duration > 0.0:
		flash_screen(preset.flash_color, preset.flash_duration)


## For animations that need particles without the preset's screen effects.
func play_particle(effect_id: StringName, origin: Node3D = null) -> void:
	var preset: CombatEffectPreset = _find_preset(effect_id)
	if preset == null or preset.particle_scene == null:
		push_warning("CombatFX: no particle preset '%s'" % effect_id)
		return
	_spawn_particle(preset.particle_scene, origin, preset.cleanup_seconds)


func _find_preset(effect_id: StringName) -> CombatEffectPreset:
	for preset in presets:
		if preset != null and preset.id == effect_id:
			return preset
	return null


func _spawn_particle(scene: PackedScene, origin: Node3D, cleanup: float) -> void:
	var instance: Node = scene.instantiate()
	if not instance is Node3D:
		push_warning("CombatFX: particle scene root must be Node3D")
		instance.queue_free()
		return

	# Parent to the current level, not to the attacker: the particle remains
	# at the impact position after the animation or stance changes.
	var parent_node: Node = get_tree().current_scene
	if parent_node == null:
		parent_node = get_tree().root
	parent_node.add_child(instance)
	(instance as Node3D).global_transform = (
		origin.global_transform if is_instance_valid(origin) else Transform3D.IDENTITY
	)
	_start_emitters(instance)

	get_tree().create_timer(cleanup).timeout.connect(
		func() -> void:
			if is_instance_valid(instance):
				instance.queue_free()
	)


func _start_emitters(root: Node) -> void:
	if root is GPUParticles3D:
		_restart_gpu(root as GPUParticles3D)
	elif root is CPUParticles3D:
		_restart_cpu(root as CPUParticles3D)

	for child in root.find_children("*", "GPUParticles3D", true, false):
		_restart_gpu(child as GPUParticles3D)
	for child in root.find_children("*", "CPUParticles3D", true, false):
		_restart_cpu(child as CPUParticles3D)


func _restart_gpu(particles: GPUParticles3D) -> void:
	particles.one_shot = true
	particles.restart()
	particles.emitting = true


func _restart_cpu(particles: CPUParticles3D) -> void:
	particles.one_shot = true
	particles.restart()
	particles.emitting = true


## The active camera is found automatically; neither character needs a
## reference to it, and neither character's world position is changed.
func shake_screen(strength: float = 0.08, duration: float = 0.20) -> void:
	var target: Camera3D = get_viewport().get_camera_3d()
	if target == null or strength <= 0.0 or duration <= 0.0:
		return

	if _shake_remaining <= 0.0 or not is_instance_valid(_shake_camera):
		_shake_camera = target
		_base_h_offset = target.h_offset
		_base_v_offset = target.v_offset

	_shake_remaining = maxf(_shake_remaining, duration)
	_shake_strength = maxf(_shake_strength, strength)


func flash_screen(color: Color = Color(1.0, 1.0, 1.0, 0.6), duration: float = 0.15) -> void:
	if _flash_rect == null:
		return
	if _flash_tween != null and _flash_tween.is_running():
		_flash_tween.kill()
	_flash_rect.color = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_rect, "color:a", 0.0, maxf(duration, 0.01))


func _process(delta: float) -> void:
	if _shake_remaining <= 0.0:
		return
	if not is_instance_valid(_shake_camera):
		_shake_remaining = 0.0
		_shake_strength = 0.0
		return

	_shake_remaining = maxf(_shake_remaining - delta, 0.0)
	if _shake_remaining > 0.0:
		_shake_camera.h_offset = _base_h_offset + randf_range(-_shake_strength, _shake_strength)
		_shake_camera.v_offset = _base_v_offset + randf_range(-_shake_strength, _shake_strength)
	else:
		_shake_camera.h_offset = _base_h_offset
		_shake_camera.v_offset = _base_v_offset
		_shake_strength = 0.0


func _exit_tree() -> void:
	if is_instance_valid(_shake_camera):
		_shake_camera.h_offset = _base_h_offset
		_shake_camera.v_offset = _base_v_offset
