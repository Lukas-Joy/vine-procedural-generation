class_name CameraComponent
extends Node

# References
@export_group("References")
@export var character_body: CharacterBody3D
@export var head: Node3D

# Mouse sensitivity (exported for customization)
@export_group("Camera Settings")
@export var dots_per_360: float = 5000  # Dots for full 360 rotation
@export var max_look_up_degrees: float = 90.0
@export var max_look_down_degrees: float = 90.0

# Constants
const MIN_DOTS_PER_360: float = 100.0
const MAX_DOTS_PER_360: float = 100000.0

# Rotation state
var camera_rotation_x: float = 0.0  # Pitch (up/down)
var camera_rotation_y: float = 0.0  # Yaw (left/right)
var sensitivity_scale: float = 0.0  # Radians per dot
var accumulated_motion: Vector2 = Vector2.ZERO


func _ready():
	if not character_body or not head:
		push_error("CameraComponent: character_body or head not assigned!")
		set_process(false)
		return
	
	# Calculate sensitivity scale from dots per 360
	calculate_sensitivity_scale()


func _process(_delta):
	# Check for mouse toggle
	if Input.is_action_just_pressed("ui_cancel"):
		toggle_mouse_capture()
	
	# Update camera look
	handle_camera_input()


func _input(event: InputEvent):
	"""Capture mouse motion events for accurate unscaled movement"""
	if not is_processing():
		return
	
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		accumulated_motion += event.screen_relative
		get_tree().root.set_input_as_handled()


func handle_camera_input():
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	
	# Use accumulated motion and reset
	var motion = accumulated_motion
	accumulated_motion = Vector2.ZERO
	
	# Apply sensitivity
	camera_rotation_y -= motion.x * sensitivity_scale
	camera_rotation_x -= motion.y * sensitivity_scale
	
	# Clamp vertical look
	var max_look_up_rad = deg_to_rad(max_look_up_degrees)
	var max_look_down_rad = deg_to_rad(max_look_down_degrees)
	camera_rotation_x = clamp(camera_rotation_x, -max_look_up_rad, max_look_down_rad)
	
	# Apply rotations
	apply_rotation()


func toggle_mouse_capture():
	"""Toggle mouse capture on/off"""
	Input.set_mouse_mode(
		Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED 
		else Input.MOUSE_MODE_CAPTURED
	)


func set_mouse_captured(captured: bool):
	"""Force mouse capture state"""
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE)


func calculate_sensitivity_scale():
	"""Calculate sensitivity scale: radians per dot"""
	sensitivity_scale = TAU / dots_per_360


func set_dots_per_360(dots: float):
	"""Update sensitivity using dots per 360 value"""
	dots_per_360 = clamp(dots, MIN_DOTS_PER_360, MAX_DOTS_PER_360)
	calculate_sensitivity_scale()


func get_look_direction() -> Vector3:
	"""Returns the forward direction the camera is looking"""
	if not character_body:
		return Vector3.FORWARD
	return -character_body.global_transform.basis.z


func set_rotation(rotation_x_degrees: float, rotation_y_degrees: float):
	"""Set camera rotation directly (degrees)"""
	var max_look_up_rad = deg_to_rad(max_look_up_degrees)
	var max_look_down_rad = deg_to_rad(max_look_down_degrees)
	
	camera_rotation_x = clamp(deg_to_rad(rotation_x_degrees), -max_look_up_rad, max_look_down_rad)
	camera_rotation_y = deg_to_rad(rotation_y_degrees)
	
	apply_rotation()


func apply_rotation():
	"""Apply current rotation to character and head"""
	if not is_node_ready():
		return
	
	character_body.rotation.y = camera_rotation_y
	head.rotation.x = camera_rotation_x
