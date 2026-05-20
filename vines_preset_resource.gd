@tool
extends Resource
class_name VinesPresetResource

@export var origin_raycast_distance: float 
@export var refinement_passes: int
@export var refinement_rays_per_pass: int

@export var step_length: float
@export var vine_length_min: int
@export var vine_length_max: int
@export var vine_radius: float
@export var vine_count: int
@export var surface_direction_variation_angle: float

@export var branch_step_length: float
@export var branch_vine_length_min: int 
@export var branch_vine_length_max: int
@export var branch_vine_radius: float 
@export var branch_surface_direction_variation_angle: float
@export var branch_spawn_min: int
@export var branch_spawn_max: int

@export var initial_seed: int
