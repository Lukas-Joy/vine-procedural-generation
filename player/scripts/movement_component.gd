class_name MovementComponent
extends Node

# References
@export_group("References")
@export var character_body: CharacterBody3D
@export var input_handler: InputHandlerComponent

# Movement speeds (exported for customization)
@export_group("Movement")
@export_subgroup("Speeds")
@export var forward_speed: float = 5.5
@export var strafe_speed: float = 4.8
@export var backward_speed: float = 4.0

# Momentum timings (in seconds)
@export_subgroup("Momentum")
@export var accel_time: float = 0.3
@export var decel_time: float = 0.9

# Physics
@export_subgroup("Jump")
@export var gravity: float = 9.8
@export var jump_height: float = 0.8  # Target jump height (in units)
@export var jump_duration: float = 0.18  # Time to reach peak (in seconds)
@export var max_fall_speed: float = 20.0  # Terminal velocity (in units/s)
@export var coyote_time: float = 0.1  # Grace period to jump after leaving ground
@export var jump_buffer_time: float = 0.1  # Seconds to buffer jump input

# Constants
const MIN_SPEED: float = 0.01

# State
var desired_velocity: Vector3 = Vector3.ZERO
var accel_progress: float = 0.0  # 0.0 = no input, 1.0 = full speed
var last_input_vector: Vector3 = Vector3.ZERO
var coyote_time_remaining: float = 0.0  # Grace period to jump after leaving ground
var jump_buffer_remaining: float = 0.0  # Buffer jump input if pressed before landing
var jump_force: float = 0.0  # Calculated from height and duration


func _ready():
	if not character_body:
		push_error("MovementComponent: character_body not assigned!")
		set_physics_process(false)
		return
	
	if not input_handler:
		push_error("MovementComponent: input_handler not assigned!")
		set_physics_process(false)
		return
	
	# Calculate jump_force from desired height and time-to-peak
	_recalculate_jump_force()


func _recalculate_jump_force():
	"""
	Calculate initial jump velocity needed to reach target height in target time.
	Formula: v = (h/t) + (0.5 * g * t)
	Where: h = height, t = time to peak, g = gravity
	"""
	if jump_duration > 0:
		jump_force = (jump_height / jump_duration) + (0.5 * gravity * jump_duration)
	else:
		push_error("MovementComponent: jump_duration must be > 0!")
		jump_force = 0.0
	


func _physics_process(delta):
	if not is_physics_processing():
		return
	
	handle_input(delta)
	apply_gravity(delta)
	character_body.move_and_slide()


func handle_input(delta: float):
	"""Process movement and jump input from the input handler"""
	# Get movement input from input handler
	var input_vec = input_handler.get_movement_input()
	last_input_vector = input_vec
	var has_input = input_vec.length() > 0
	
	if has_input:
		_calculate_desired_velocity(last_input_vector)
	else:
		desired_velocity = Vector3.ZERO
	
	# Track jump input for buffering (lets you press jump before landing)
	if input_handler.is_jump_pressed() and jump_buffer_remaining <= 0:
		jump_buffer_remaining = jump_buffer_time
	
	# Countdown jump buffer
	jump_buffer_remaining -= delta
	
	# Update coyote time (grace period after leaving ground to still jump)
	if character_body.is_on_floor():
		coyote_time_remaining = coyote_time
	else:
		coyote_time_remaining -= delta
	
	# Jump if: (on floor or coyote time available) AND (jump buffered)
	var can_jump = character_body.is_on_floor() or coyote_time_remaining > 0
	var has_jump_input = jump_buffer_remaining > 0
	
	if can_jump and has_jump_input:
		character_body.velocity.y = jump_force
		jump_buffer_remaining = 0  # Consume buffered input
		coyote_time_remaining = 0  # Use up coyote time
	
	_update_momentum(delta, has_input)


func _calculate_desired_velocity(input_vector: Vector3):
	"""Calculate velocity based on input direction and camera orientation"""
	var forward = -character_body.global_transform.basis.z
	var right = character_body.global_transform.basis.x
	
	var desired_move = (forward * input_vector.z + right * input_vector.x).normalized()
	var move_speed = _get_movement_speed(input_vector)
	
	desired_velocity = desired_move * move_speed


func _get_movement_speed(input_vector: Vector3) -> float:
	"""Determine speed based on movement direction, then apply surface and sprint multipliers"""
	var base_speed: float
	
	if input_vector.z < 0:  # Moving backward
		base_speed = backward_speed
	elif abs(input_vector.x) > abs(input_vector.z):  # Strafing
		base_speed = strafe_speed
	else:  # Moving forward
		base_speed = forward_speed

	
	return base_speed


func _update_momentum(delta: float, has_input: bool):

	var current_accel_time = accel_time
	
	if has_input:
		accel_progress = clamp(accel_progress + delta / current_accel_time, 0.0, 1.0)
	else:
		accel_progress = clamp(accel_progress - delta / decel_time, 0.0, 1.0)


func apply_gravity(delta: float):
	"""Apply gravity and horizontal momentum"""
	var current_horizontal = Vector3(character_body.velocity.x, 0, character_body.velocity.z)
	var desired_horizontal = Vector3(desired_velocity.x, 0, desired_velocity.z)
	
	var new_horizontal = current_horizontal.lerp(desired_horizontal, accel_progress)
	character_body.velocity.x = new_horizontal.x
	character_body.velocity.z = new_horizontal.z
	
	# Apply gravity when airborne and clamp terminal velocity
	if not character_body.is_on_floor():
		character_body.velocity.y -= gravity * delta
		# Clamp to terminal velocity (prevent falling too fast)
		character_body.velocity.y = max(character_body.velocity.y, -max_fall_speed)


func get_current_horizontal_speed() -> float:
	"""Get current horizontal movement speed"""
	if not character_body:
		return 0.0
	
	return Vector3(character_body.velocity.x, 0, character_body.velocity.z).length()


func get_desired_speed() -> float:
	"""Get the desired speed magnitude"""
	return desired_velocity.length()


func is_moving() -> bool:
	"""Check if player is currently moving"""
	return get_current_horizontal_speed() > MIN_SPEED
