class_name PhysicsComponent
extends Node

# Physics constants
const STANDARD_GRAVITY = 9.8

# References
@onready var character_body: CharacterBody3D = get_parent()

@export_group("Physics Settings")
@export var gravity_scale: float = 0.7
@export var jump_velocity: float = 7.0

# State
var can_jump: bool = false
var landing_pause_timer: float = 0.0
var is_landing: bool = false


func _ready():
	can_jump = true


func _physics_process(delta):
	handle_physics(delta)


func handle_physics(delta: float):
	"""Handle gravity and landing pause"""
	if landing_pause_timer > 0:
		landing_pause_timer -= delta
		return
	
	apply_gravity(delta)
	handle_jump_input()
	handle_landing()


func apply_gravity(delta: float):
	"""Apply custom gravity for slower falling"""
	var gravity = STANDARD_GRAVITY * gravity_scale
	character_body.velocity.y -= gravity * delta


func handle_jump_input():
	"""Handle jump input"""
	if Input.is_action_just_pressed("ui_accept") and can_jump:
		character_body.velocity.y = jump_velocity
		can_jump = false
		is_landing = false


func handle_landing():
	"""Handle landing on surface, applying pause if needed"""
	if character_body.is_on_floor():
		can_jump = true
	else:
		can_jump = false


func is_in_landing_pause() -> bool:
	"""Check if currently in landing pause"""
	return landing_pause_timer > 0


func set_gravity_scale(scale: float):
	"""Adjust gravity scale"""
	gravity_scale = scale


func set_jump_velocity(velocity: float):
	"""Adjust jump height"""
	jump_velocity = velocity
