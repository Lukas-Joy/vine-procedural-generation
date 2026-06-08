class_name InputHandlerComponent
extends Node

# Signals for input events (other systems can listen to these)
signal movement_input_changed(input_vector: Vector3)
signal jump_pressed
signal jump_released
signal zoom_in_pressed
signal zoom_out_pressed
signal zoom_reset_pressed
signal level_reset_pressed
signal level_exit_pressed

# State
var _movement_input: Vector3 = Vector3.ZERO

# Sprint tracking (for double-tap detection and state)
var _was_move_forward_pressed: bool = false
var _move_forward_last_tap_time: float = 0.0

func _ready():
	_update_movement_input()

func _input(event: InputEvent):
	pass

func _physics_process(delta: float):
	_update_movement_input()
	_update_jump_input()
	_update_zoom_input()
	_update_level_input()

func _update_movement_input():
	var input_vec = Input.get_vector("move_left", "move_right", "move_backward", "move_forward")
	var new_movement = Vector3(input_vec.x, 0, input_vec.y)
	if new_movement != _movement_input:
		_movement_input = new_movement
		movement_input_changed.emit(_movement_input)

func _update_jump_input():
	if Input.is_action_just_pressed("jump"):
		jump_pressed.emit()
	if Input.is_action_just_released("jump"):
		jump_released.emit()

func _update_zoom_input():
	if Input.is_action_just_pressed("zoom_in"):
		zoom_in_pressed.emit()
	if Input.is_action_just_pressed("zoom_out"):
		zoom_out_pressed.emit()
	if Input.is_action_just_pressed("zoom_reset"):
		zoom_reset_pressed.emit()

func _update_level_input():
	if Input.is_action_just_pressed("level_exit"):
		level_exit_pressed.emit()
	if Input.is_action_just_pressed("level_reset"):
		level_reset_pressed.emit()
		
# Getter methods for external systems to query current input state
func get_movement_input() -> Vector3:
	return _movement_input

func is_moving() -> bool:
	return _movement_input.length() > 0

func is_jump_pressed() -> bool:
	return Input.is_action_just_pressed("jump")

func is_jump_held() -> bool:
	return Input.is_action_pressed("jump")

func is_zoom_in_pressed() -> bool:
	return Input.is_action_just_pressed("zoom_in")

func is_zoom_out_pressed() -> bool:
	return Input.is_action_just_pressed("zoom_out")

func is_zoom_reset_pressed() -> bool:
	return Input.is_action_just_pressed("zoom_reset")

func is_level_exit_pressed() -> bool:
	return Input.is_action_just_pressed("level_exit")

func is_level_reset_pressed() -> bool:
	return Input.is_action_just_pressed("level_reset")
