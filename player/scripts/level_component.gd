class_name LevelComponent
extends Node

# References
@export_group("References")
@export var input_handler: InputHandlerComponent

func _ready():
	if not input_handler:
		push_error("LevelComponent: input_handler not assigned!")
		set_physics_process(false)
		return

func _physics_process(delta: float) -> void:
	if input_handler.is_level_exit_pressed():
		exit()
	if input_handler.is_level_reset_pressed():
		reset()

func exit() -> void:
	get_tree().quit()
	
func reset() -> void:
	get_tree().reload_current_scene()
