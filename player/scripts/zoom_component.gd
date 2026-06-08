class_name ZoomComponent
extends Node

# References
@export_group("References")
@export var camera: Node3D
@export var input_handler: InputHandlerComponent

# Mouse sensitivity (exported for customization)
@export_group("Zoom Settings")
@export var minimum_fov: float = 15
@export var maximum_fov: float = 120.0
@export var default_fov: float = 90.0
@export var zoom_increment: float = 5

var current_fov: float

func _ready():
	if not camera or not input_handler:
		push_error("ZoomComponent: camera or input handler not assigned!")
		print("camera: ", camera, " | input_handler: ", input_handler)
		set_physics_process(false)
		return
	current_fov = default_fov
	camera.set_perspective(default_fov, 0.05, 4000.0)
	
func _physics_process(delta: float) -> void:
	if input_handler.is_zoom_in_pressed():
		zoom_in()
	if input_handler.is_zoom_out_pressed():
		zoom_out()
	if input_handler.is_zoom_reset_pressed():
		zoom_reset()

func zoom_out():
	var new_fov = clamp(current_fov + zoom_increment, minimum_fov, maximum_fov)
	camera.set_perspective(new_fov, 0.05, 4000.0)
	current_fov = new_fov

func zoom_in():
	var new_fov = clamp(current_fov - zoom_increment, minimum_fov, maximum_fov)
	camera.set_perspective(new_fov, 0.05, 4000.0)
	current_fov = new_fov

func zoom_reset():
	camera.set_perspective(default_fov, 0.05, 4000.0)
	current_fov = default_fov
