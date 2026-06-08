@tool
extends Node3D

# Simple straight-line surface point generator using raycasts.
# Usage: Attach to a Node3D, position it near the starting surface,
# then press the `Generate Now` toggle in the Inspector.

@export var max_steps: int = 40
@export var step_distance: float = 0.5
@export var start_offset: float = 0.2 # how far above the surface to start each ray
@export var marker_radius: float = 0.03
@export var clear_previous: bool = true
@export_tool_button("Generate Now") var auto_find_start: bool = false

var _pending_generate: bool = false

func start_generate_now() -> void:
	_pending_generate = true

func _physics_process(_delta: float) -> void:
	if not _pending_generate:
		return
	_pending_generate = false
	var start_pos = global_transform.origin
	var start_normal = -global_transform.basis.z
	_generate_straight_line(start_pos, start_normal)

func _generate_straight_line(start_pos: Vector3, start_normal: Vector3) -> void:
	if clear_previous:
		_clear_markers()

	# compute a tangent direction along the surface using the node's X axis
	var raw_tangent = global_transform.basis.x
	var tangent = (raw_tangent - raw_tangent.project(start_normal)).normalized()
	if tangent.length() == 0:
		# fallback: compute perpendicular to normal
		var up = Vector3.UP
		if abs(start_normal.dot(up)) > 0.99:
			up = Vector3.RIGHT
		tangent = start_normal.cross(up).normalized()

	var space = get_world_3d().direct_space_state
	var placed = 0
	for i in range(1, max_steps + 1):
		var lateral = start_pos + tangent * step_distance * float(i)
		var from = lateral + start_normal * start_offset
		var to = lateral - start_normal * (start_offset + step_distance * 2.0)

		var q = PhysicsRayQueryParameters3D.create(from, to)
		q.exclude = [self]
		var res = space.intersect_ray(q)
		if not res:
			break
		var hit_pos: Vector3 = res.position
		_spawn_marker(hit_pos)
		placed += 1

	print("BranchGenerator: placed ", placed, " markers")

func _spawn_marker(pos: Vector3) -> void:
	var m = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = marker_radius
	mesh.radial_segments = 8
	mesh.rings = 6
	m.mesh = mesh
	m.transform.origin = pos
	add_child(m)

func _clear_markers() -> void:
	for c in get_children():
		if c is MeshInstance3D:
			c.queue_free()
