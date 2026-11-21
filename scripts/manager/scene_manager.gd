extends CanvasLayer

signal scene_changing(new_scene_path: String)
signal scene_changed(new_scene_path: String)

var _fade_rect: ColorRect
var _is_transitioning: bool = false

func _ready() -> void:
	# Keep the fade layer above all game UI
	layer = 100
	
	# Create a full-screen black rectangle for smooth transitions
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.modulate.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade_rect)

## Switch scenes using a file path (e.g., "res://scenes/level_1.tscn")
func change_scene(scene_path: String, fade_duration: float = 0.0) -> void:
	if _is_transitioning:
		return
	
	_is_transitioning = true
	scene_changing.emit(scene_path)
	
	# Fade out to black
	if fade_duration > 0.0:
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP # Block clicks during transition
		var tween := create_tween()
		tween.tween_property(_fade_rect, "modulate:a", 1.0, fade_duration)
		await tween.finished
	
	# Change the scene safely
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("SceneManager failed to load: " + scene_path)
		_is_transitioning = false
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	
	# Wait one frame for the new scene's _ready() to finish
	await get_tree().process_frame
	
	# Fade back in
	if fade_duration > 0.0:
		var tween := create_tween()
		tween.tween_property(_fade_rect, "modulate:a", 0.0, fade_duration)
		await tween.finished
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_is_transitioning = false
	scene_changed.emit(scene_path)

## Reload the currently active scene
func reload_current_scene(fade_duration: float = 0.1) -> void:
	var current_path := get_tree().current_scene.scene_file_path
	if current_path != "":
		change_scene(current_path, fade_duration)
