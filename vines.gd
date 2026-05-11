@tool
extends Node3D

@export_tool_button("Redraw", "Node3D") var redraw_tool_button = refresh_vines

@export var query_max_distance := 25.0
@export_range(0, 4, 1) var refinement_passes := 2
@export_range(6, 64, 1) var refinement_rays_per_pass := 18
@export var debug_sphere_radius := 0.05
@export var debug_normal_length := 0.5
@export var debug_normal_radius := 0.01
@export_range(1, 10, 1) var vine_iterations := 3
@export var vine_radius := 0.1
@export_range(0.0, 180.0, 5.0) var surface_direction_variation_angle := 45.0

const QUERY_COLLISION_MASK := 1
const COLLIDE_WITH_BODIES := true
const COLLIDE_WITH_AREAS := false
const DEBUG_PRINTS := true

func _find_closest_surface_hit(global_point: Vector3) -> Dictionary:
	var query_origin := global_point
	var directions: Array[Vector3] = [
		Vector3.RIGHT,
		Vector3.LEFT,
		Vector3.UP,
		Vector3.DOWN,
		Vector3.FORWARD,
		Vector3.BACK
	]

	directions.append_array([
		(Vector3.RIGHT + Vector3.UP).normalized(),
		(Vector3.RIGHT + Vector3.DOWN).normalized(),
		(Vector3.LEFT + Vector3.UP).normalized(),
		(Vector3.LEFT + Vector3.DOWN).normalized(),
		(Vector3.RIGHT + Vector3.FORWARD).normalized(),
		(Vector3.RIGHT + Vector3.BACK).normalized(),
		(Vector3.LEFT + Vector3.FORWARD).normalized(),
		(Vector3.LEFT + Vector3.BACK).normalized(),
		(Vector3.UP + Vector3.FORWARD).normalized(),
		(Vector3.UP + Vector3.BACK).normalized(),
		(Vector3.DOWN + Vector3.FORWARD).normalized(),
		(Vector3.DOWN + Vector3.BACK).normalized(),
		(Vector3.RIGHT + Vector3.UP + Vector3.FORWARD).normalized(),
		(Vector3.RIGHT + Vector3.UP + Vector3.BACK).normalized(),
		(Vector3.RIGHT + Vector3.DOWN + Vector3.FORWARD).normalized(),
		(Vector3.RIGHT + Vector3.DOWN + Vector3.BACK).normalized(),
		(Vector3.LEFT + Vector3.UP + Vector3.FORWARD).normalized(),
		(Vector3.LEFT + Vector3.UP + Vector3.BACK).normalized(),
		(Vector3.LEFT + Vector3.DOWN + Vector3.FORWARD).normalized(),
		(Vector3.LEFT + Vector3.DOWN + Vector3.BACK).normalized()
	])

	var space_state := get_world_3d().direct_space_state
	var best := {
		"found": false,
		"distance": INF,
		"point": Vector3.ZERO,
		"normal": Vector3.UP,
		"direction": Vector3.FORWARD
	}

	if DEBUG_PRINTS:
		print("[vines] _find_closest_surface_hit()")
		print("[vines] query_origin=", query_origin)
		print("[vines] max_distance=", query_max_distance)
		print("[vines] collision_mask=", QUERY_COLLISION_MASK)

	for direction in directions:
		var params := PhysicsRayQueryParameters3D.create(
			query_origin,
			query_origin + direction * query_max_distance,
			QUERY_COLLISION_MASK
		)
		params.collide_with_bodies = COLLIDE_WITH_BODIES
		params.collide_with_areas = COLLIDE_WITH_AREAS

		var hit := space_state.intersect_ray(params)
		if hit.is_empty():
			continue

		var hit_point: Vector3 = hit["position"]
		var distance := query_origin.distance_to(hit_point)
		if distance < best["distance"]:
			best["distance"] = distance
			best["point"] = hit_point
			best["normal"] = hit["normal"]
			best["direction"] = (hit_point - query_origin).normalized()
			best["found"] = true

	if best["found"]:
		var unit_samples: Array[Vector3] = []
		if refinement_rays_per_pass > 0:
			var golden_angle := PI * (3.0 - sqrt(5.0))
			for i in refinement_rays_per_pass:
				var t := (float(i) + 0.5) / float(refinement_rays_per_pass)
				var y := 1.0 - 2.0 * t
				var r := sqrt(max(0.0, 1.0 - y * y))
				var theta := golden_angle * float(i)
				unit_samples.append(Vector3(cos(theta) * r, y, sin(theta) * r))

		for passes in refinement_passes:
			var blend := 0.35 / float(passes + 1)
			for unit_dir in unit_samples:
				var sample_dir: Vector3 = (best["direction"] as Vector3).slerp(unit_dir, blend).normalized()
				var sample_params := PhysicsRayQueryParameters3D.create(
					query_origin,
					query_origin + sample_dir * query_max_distance,
					QUERY_COLLISION_MASK
				)
				sample_params.collide_with_bodies = COLLIDE_WITH_BODIES
				sample_params.collide_with_areas = COLLIDE_WITH_AREAS

				var sample_hit := space_state.intersect_ray(sample_params)
				if sample_hit.is_empty():
					continue

				var sample_point: Vector3 = sample_hit["position"]
				var sample_distance := query_origin.distance_to(sample_point)
				if sample_distance < best["distance"]:
					best["distance"] = sample_distance
					best["point"] = sample_point
					best["normal"] = sample_hit["normal"]
					best["direction"] = (sample_point - query_origin).normalized()
					best["found"] = true

	if not best["found"]:
		if DEBUG_PRINTS:
			print("[vines] no surface hit found from query point")
		return {}

	if DEBUG_PRINTS:
		print("[vines] closest point=", best["point"], " normal=", best["normal"], " distance=", best["distance"])

	return best

func get_closest_surface_point(global_point: Vector3) -> Variant:
	var hit := _find_closest_surface_hit(global_point)
	if hit.is_empty():
		return null
	return hit["point"]

func get_closest_surface_normal(global_point: Vector3) -> Variant:
	var hit := _find_closest_surface_hit(global_point)
	if hit.is_empty():
		return null
	return hit["normal"]

func _clear_debug_shapes() -> void:
	# Remove all children of this node so debug geometry never lingers.
	for child in get_children():
		# queue_free each direct child
		child.queue_free()

func _raycast_for_next(origin: Vector3, dir: Vector3, length: float) -> Dictionary:
	var params := PhysicsRayQueryParameters3D.create(origin, origin + dir.normalized() * length, QUERY_COLLISION_MASK)
	params.collide_with_bodies = COLLIDE_WITH_BODIES
	params.collide_with_areas = COLLIDE_WITH_AREAS
	return get_world_3d().direct_space_state.intersect_ray(params)

func _catmull_rom_point(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		2.0 * p1 +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)

func _build_catmull_rom_curve(points: Array) -> Array:
	if points.size() < 2:
		return []

	var curve_points: Array = []
	var segments := 8

	if points.size() == 2:
		for i in range(segments + 1):
			var t := float(i) / float(segments)
			var pt = points[0].lerp(points[1], t)
			curve_points.append(pt)
	else:
		for i in range(points.size() - 1):
			var p0 = points[max(0, i - 1)]
			var p1 = points[i]
			var p2 = points[i + 1]
			var p3 = points[min(points.size() - 1, i + 2)]

			for j in range(segments):
				var t := float(j) / float(segments)
				var pt := _catmull_rom_point(p0, p1, p2, p3, t)
				curve_points.append(pt)

		curve_points.append(points[-1])

	return curve_points

func _build_tubular_mesh(curve_points: Array, radius: float) -> Mesh:
	if curve_points.size() < 2:
		return null

	var vertices: PackedVector3Array = []
	var indices: PackedInt32Array = []
	var normals: PackedVector3Array = []

	var circle_segments := 16
	var radius_vec := radius

	for i in range(curve_points.size()):
		var pt = curve_points[i]
		var tangent: Vector3

		if i == 0:
			tangent = (curve_points[1] - curve_points[0]).normalized()
		elif i == curve_points.size() - 1:
			tangent = (curve_points[i] - curve_points[i - 1]).normalized()
		else:
			tangent = (curve_points[i + 1] - curve_points[i - 1]).normalized()

		var up := Vector3.UP
		if abs(tangent.dot(up)) > 0.9:
			up = Vector3.RIGHT

		var right := tangent.cross(up).normalized()
		var forward := tangent.cross(right).normalized()

		for j in range(circle_segments):
			var angle := (float(j) / float(circle_segments)) * TAU
			var offset := right * cos(angle) * radius_vec + forward * sin(angle) * radius_vec
			vertices.append(pt + offset)
			normals.append(offset.normalized())

	# Cap at start
	var center_start := vertices[0]
	vertices.append(center_start)
	var center_start_idx := vertices.size() - 1

	for j in range(circle_segments):
		var j_next := (j + 1) % circle_segments
		indices.append(center_start_idx)
		indices.append(j)
		indices.append(j_next)

	# Build tube indices
	for i in range(curve_points.size() - 1):
		var base := i * circle_segments
		var next_base := (i + 1) * circle_segments

		for j in range(circle_segments):
			var j_next := (j + 1) % circle_segments

			indices.append(base + j)
			indices.append(next_base + j)
			indices.append(base + j_next)

			indices.append(next_base + j)
			indices.append(next_base + j_next)
			indices.append(base + j_next)

	# Cap at end
	var last_ring_start := (curve_points.size() - 1) * circle_segments
	var center_end := vertices[last_ring_start]
	vertices.append(center_end)
	var center_end_idx := vertices.size() - 1

	for j in range(circle_segments):
		var j_next := (j + 1) % circle_segments
		indices.append(center_end_idx)
		indices.append(last_ring_start + j_next)
		indices.append(last_ring_start + j)

	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _random_in_plane_direction(normal: Vector3) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var angle := rng.randf_range(0.0, PI * 2.0)
	var tangent := normal.cross(Vector3.UP)
	if tangent.length_squared() < 1e-6:
		tangent = normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	return tangent.rotated(normal, angle).normalized()

func _compute_next_point_internal(surface_point: Vector3, surface_normal: Vector3, preferred_surface_dir: Vector3 = Vector3.ZERO) -> Variant:
	var x := debug_normal_length
	var half_x := x * 0.5
	# 1) Raycast up from surface point in normal direction length x/2
	var hit = _raycast_for_next(surface_point, surface_normal, half_x)
	if not hit.is_empty():
		return {"point": hit["position"], "normal": hit["normal"]}

	# base origin is end of the first ray
	var base := surface_point + surface_normal * half_x

	# 2) random parallel direction in surface plane, ray length x
	var parallel_dir: Vector3
	if preferred_surface_dir.length_squared() > 0.0001:
		# Bias toward preferred direction with variation
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var variation_rad := deg_to_rad(surface_direction_variation_angle)
		var angle_offset := rng.randf_range(-variation_rad, variation_rad)
		parallel_dir = preferred_surface_dir.rotated(surface_normal, angle_offset).normalized()
	else:
		parallel_dir = _random_in_plane_direction(surface_normal)

	hit = _raycast_for_next(base, parallel_dir, x)
	if not hit.is_empty():
		return {"point": hit["position"], "normal": hit["normal"]}

	# 3) raycast length x from end in negative normal direction
	var base2 := base + parallel_dir * x
	hit = _raycast_for_next(base2, -surface_normal, x)
	if not hit.is_empty():
		return {"point": hit["position"], "normal": hit["normal"]}

	# 4) raycast length x from end in negative parallel direction
	var base3 := base2 + (-surface_normal) * x
	hit = _raycast_for_next(base3, -parallel_dir, x)
	if not hit.is_empty():
		return {"point": hit["position"], "normal": hit["normal"]}

	# 5) final raycast from end in normal direction (should hit)
	var base4 := base3 + (-parallel_dir) * x
	hit = _raycast_for_next(base4, surface_normal, x)
	if not hit.is_empty():
		return {"point": hit["position"], "normal": hit["normal"]}

	# error, return null
	return null

func _spawn_debug_shapes(point: Vector3, normal: Vector3, iteration: int, size_scale: float) -> void:
	var sphere := CSGSphere3D.new()
	sphere.name = "DebugPointSphere_%d" % iteration
	sphere.radius = debug_sphere_radius * size_scale
	sphere.use_collision = false
	sphere.material = StandardMaterial3D.new()
	sphere.material.albedo_color = Color.RED
	add_child(sphere)
	sphere.global_transform = Transform3D(Basis(), point)

	# Cylinder with one end at point, extending in normal direction
	var cylinder := CSGCylinder3D.new()
	cylinder.name = "DebugNormalCylinder_%d" % iteration
	cylinder.radius = debug_normal_radius * size_scale
	cylinder.height = debug_normal_length * size_scale
	cylinder.use_collision = false
	cylinder.material = StandardMaterial3D.new()
	cylinder.material.albedo_color = Color.RED

	# Position cylinder so bottom is at point, top extends in normal direction
	var cyl_center := point + normal * (debug_normal_length * size_scale * 0.5)
	var up := normal
	var right := up.cross(Vector3.FORWARD)
	if right.length_squared() < 0.0001:
		right = up.cross(Vector3.RIGHT)
	right = right.normalized()
	var forward := right.cross(up).normalized()
	add_child(cylinder)
	cylinder.global_transform = Transform3D(Basis(right, up, forward), cyl_center)

func refresh_vines():
	_clear_debug_shapes()
	var origin := global_position
	var point_result = get_closest_surface_point(origin)
	var normal_result = get_closest_surface_normal(origin)

	if point_result == null or normal_result == null:
		return

	var points_and_normals: Array = []
	var current_point: Vector3 = point_result
	var current_normal: Vector3 = (normal_result as Vector3).normalized()

	# Store first point and normal
	points_and_normals.append({"point": current_point, "normal": current_normal})

	# Iterate to find next points with direction continuity
	var preferred_surface_dir: Vector3 = Vector3.ZERO
	for iteration in range(1, vine_iterations):
		# Compute preferred direction from last two points if available
		if points_and_normals.size() >= 2:
			var p_prev: Vector3 = points_and_normals[-1]["point"]
			var p_prev_prev: Vector3 = points_and_normals[-2]["point"]
			var trend: Vector3 = (p_prev - p_prev_prev).normalized()
			# Project trend onto surface plane (perpendicular to normal)
			preferred_surface_dir = (trend - trend.dot(current_normal) * current_normal).normalized()

		var next_result = _compute_next_point_internal(current_point, current_normal, preferred_surface_dir)
		if next_result == null:
			if DEBUG_PRINTS:
				print("[vines] iteration ", iteration, " computation failed")
			break

		current_point = next_result["point"]
		current_normal = (next_result["normal"] as Vector3).normalized()
		points_and_normals.append({"point": current_point, "normal": current_normal})

	if DEBUG_PRINTS:
		print("[vines] found ", points_and_normals.size(), " points")

	# Offset points outward by vine_radius along their normals
	var offset_points: Array = []
	for entry in points_and_normals:
		var offset_pt: Vector3 = entry["point"] + entry["normal"] * vine_radius
		offset_points.append(offset_pt)

	# Build Catmull-Rom curve
	var curve_points := _build_catmull_rom_curve(offset_points)

	# Build tubular mesh
	var vine_mesh := _build_tubular_mesh(curve_points, vine_radius)
	if vine_mesh != null:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = vine_mesh
		mesh_instance.material_override = StandardMaterial3D.new()
		mesh_instance.material_override.albedo_color = Color.GREEN
		add_child(mesh_instance)

	# Spawn debug shapes for each point with decreasing size
	for i in range(points_and_normals.size()):
		var size_scale := pow(0.5, float(i))
		var entry = points_and_normals[i]
		_spawn_debug_shapes(entry["point"], entry["normal"], i, size_scale)
	
