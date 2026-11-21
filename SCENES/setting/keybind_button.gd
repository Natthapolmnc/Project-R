extends Button
class_name KeybindButton

@export var action_name: String = "ui_accept"

func _ready() -> void:
	var events = InputMap.action_get_events(action_name)
	if events.size() > 0:
		text = str(events)
	# Make sure toggle_mode is on so the button stays pressed while listening
	toggle_mode = true
	set_process_input(false)
	_update_button_text()

func _toggled(toggled_on: bool) -> void:
	if toggled_on:
		text = "Press any key..."
		set_process_input(true)
	else:
		set_process_input(false)
		_update_button_text()

func _input(event: InputEvent) -> void:
	# Only listen for keyboard keys or mouse buttons (ignore mouse movement)
	if event is InputEventKey or event is InputEventMouseButton:
		if event.pressed:
			# Optional: Cancel rebinding if Escape is pressed
			if event is InputEventKey and event.keycode == KEY_ESCAPE:
				button_pressed = false
				get_viewport().set_input_as_handled()
				return
			
			# Replace the old keybind in Godot's InputMap
			InputMap.action_erase_events(action_name)
			InputMap.action_add_event(action_name, event)
			
			# Stop listening and update the button text
			button_pressed = false
			get_viewport().set_input_as_handled()

func _update_button_text() -> void:
	var events := InputMap.action_get_events(action_name)
	
	if events.is_empty():
		text = "Unassigned"
		return
	
	var event := events[0]
	
	if event is InputEventKey:
		# Gets the readable key name (e.g., "Space", "W", "Shift")
		# Uses physical_keycode fallback if keycode is unset
		var key_name := OS.get_keycode_string(event.get_keycode_with_modifiers())
		if key_name == "":
			key_name = OS.get_keycode_string(event.get_physical_keycode_with_modifiers())
		text = key_name
	elif event is InputEventMouseButton:
		# Cleans up mouse button names (e.g., "Left Mouse Button")
		text = event.as_text()
	else:
		# Fallback for gamepad or other inputs
		text = event.as_text().trim_suffix(" (Physical)")
