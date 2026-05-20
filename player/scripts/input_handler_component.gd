class_name InputHandlerComponent
extends Node

# Signals for input events (other systems can listen to these)
signal movement_input_changed(input_vector: Vector3)
signal jump_pressed
signal jump_released

# State
var _movement_input: Vector3 = Vector3.ZERO
var _jump_pressed_this_frame: bool = false
var _jump_released_this_frame: bool = false

# Frame tracking to ensure single-frame events
var _was_jump_pressed: bool = false

# Sprint tracking (for double-tap detection and state)
var _was_move_forward_pressed: bool = false
var _move_forward_last_tap_time: float = 0.0

func _ready():
	# Initialize input state at start of game
	_update_movement_input()

func _input(event: InputEvent):
	# Handle raw input events here if needed
	pass

func _physics_process(delta: float):
	# Update movement input
	_update_movement_input()
	
	# Update jump input
	_update_jump_input()


func _update_movement_input():
	"""Read movement input and emit signal if changed"""
	var input_vec = Input.get_vector("move_left", "move_right", "move_backward", "move_forward")
	var new_movement = Vector3(input_vec.x, 0, input_vec.y)
	
	if new_movement != _movement_input:
		_movement_input = new_movement
		movement_input_changed.emit(_movement_input)


func _update_jump_input():
	"""Handle jump input with single-frame press/release detection"""
	var is_jump_pressed = Input.is_action_pressed("jump")
	
	# Detect press (transition from not pressed to pressed)
	_jump_pressed_this_frame = is_jump_pressed and not _was_jump_pressed
	
	# Detect release (transition from pressed to not pressed)
	_jump_released_this_frame = not is_jump_pressed and _was_jump_pressed
	
	if _jump_pressed_this_frame:
		jump_pressed.emit()
	
	if _jump_released_this_frame:
		jump_released.emit()
	
	_was_jump_pressed = is_jump_pressed

# Getter methods for external systems to query current input state
func get_movement_input() -> Vector3:
	"""Get current movement input vector"""
	return _movement_input


func is_moving() -> bool:
	"""Check if there's any movement input"""
	return _movement_input.length() > 0


func is_jump_pressed() -> bool:
	"""Check if jump was pressed this frame"""
	return _jump_pressed_this_frame


func is_jump_held() -> bool:
	"""Check if jump is currently held"""
	return _was_jump_pressed
