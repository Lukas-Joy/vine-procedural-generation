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

@export var sagging_chance: float
@export var sagging_length_factor_min: float
@export var sagging_length_factor_max: float
@export var trailing_chance: float
@export var trailing_length_min: float
@export var trailing_length_max: float
@export var trailing_vine_radius: float
@export var trailing_vine_jitter: float

@export var initial_seed: int
