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

func _random_in_plane_direction(normal: Vector3) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var angle := rng.randf_range(0.0, PI * 2.0)
	var tangent := normal.cross(Vector3.UP)
	if tangent.length_squared() < 1e-6:
		tangent = normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	return tangent.rotated(normal, angle).normalized()

func _spawn_toruses_along_segment(start: Vector3, end: Vector3, count: int = 8, color: Color = Color.CYAN, size_scale: float = 1.0) -> void:
	# Spawn a line of small spheres between start and end for visualizing raycasts
	if count <= 0:
		return
	var seg_dir := (end - start)
	var length := seg_dir.length()
	if length <= 0.0:
		return
	for i in range(1, count + 1):
		var t := float(i) / float(count + 1)
		var pos := start.lerp(end, t)
		var sph := CSGSphere3D.new()
		sph.name = "DebugRaySphere_%d" % i
		sph.radius = max(0.01, length * 0.02) * size_scale
		sph.use_collision = false
		sph.material = StandardMaterial3D.new()
		sph.material.albedo_color = color
		add_child(sph)
		sph.global_transform = Transform3D(Basis(), pos)

func _compute_next_point_internal(surface_point: Vector3, surface_normal: Vector3, preferred_surface_dir: Vector3 = Vector3.ZERO) -> Variant:
	var x := debug_normal_length
	var half_x := x * 0.5
	var debug_segments: Array = []

	# 1) Raycast up from surface point in normal direction length x/2
	var start1 := surface_point
	var end1 := surface_point + surface_normal * half_x
	var hit = _raycast_for_next(start1, surface_normal, half_x)
	var seg_end1 := end1
	if not hit.is_empty():
		seg_end1 = hit["position"]
	debug_segments.append({"start": start1, "end": seg_end1})
	if not hit.is_empty():
		return {"point": hit["position"], "normal": hit["normal"], "debug_segments": debug_segments}

	# base origin is end of the first ray
	var base := end1

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

	var start2 := base
	var end2 := base + parallel_dir * x
	hit = _raycast_for_next(start2, parallel_dir, x)
	var seg_end2 := end2
	if not hit.is_empty():
		seg_end2 = hit["position"]
	debug_segments.append({"start": start2, "end": seg_end2})
	if not hit.is_empty():
		return {"point": hit["position"], "normal": hit["normal"], "debug_segments": debug_segments}

	# 3) raycast length x from end in negative normal direction
	var base2 := end2
	var start3 := base2
	var end3 := base2 + (-surface_normal) * x
	hit = _raycast_for_next(start3, -surface_normal, x)
	var seg_end3 := end3
	if not hit.is_empty():
		seg_end3 = hit["position"]
	debug_segments.append({"start": start3, "end": seg_end3})
	if not hit.is_empty():
		return {"point": hit["position"], "normal": hit["normal"], "debug_segments": debug_segments}

	# 4) raycast length x from end in negative parallel direction
	var base3 := end3
	var start4 := base3
	var end4 := base3 + (-parallel_dir) * x
	hit = _raycast_for_next(start4, -parallel_dir, x)
	var seg_end4 := end4
	if not hit.is_empty():
		seg_end4 = hit["position"]
	debug_segments.append({"start": start4, "end": seg_end4})
	if not hit.is_empty():
		return {"point": hit["position"], "normal": hit["normal"], "debug_segments": debug_segments}

	# 5) final raycast from end in normal direction (should hit)
	var base4 := end4
	var start5 := base4
	var end5 := base4 + surface_normal * x
	hit = _raycast_for_next(start5, surface_normal, x)
	var seg_end5 := end5
	if not hit.is_empty():
		seg_end5 = hit["position"]
	debug_segments.append({"start": start5, "end": seg_end5})
	if not hit.is_empty():
		return {"point": hit["position"], "normal": hit["normal"], "debug_segments": debug_segments}

	# error, return null
	return null

func _spawn_debug_shapes(point: Vector3, normal: Vector3, iteration: int, size_scale: float, prev_normal = null, prev_point = null) -> void:
	var color := Color.RED
	if prev_normal != null:
		var d = (normal.normalized()).dot((prev_normal as Vector3).normalized())
		if DEBUG_PRINTS:
			print("[vines] _spawn_debug_shapes: iteration=", iteration, " dot=", d)
		# If normals differ significantly (dot < 0.9999) mark green.
		# Use raw dot so opposite normals (dot ~= -1) are considered different.
		if d < 0.9999:
			color = Color.GREEN
			if DEBUG_PRINTS:
				print("[vines] normals differ -> GREEN")
		elif DEBUG_PRINTS:
			print("[vines] normals similar -> RED")

	var sphere := CSGSphere3D.new()
	sphere.name = "DebugPointSphere_%d" % iteration
	sphere.radius = debug_sphere_radius * size_scale
	sphere.use_collision = false
	sphere.material = StandardMaterial3D.new()
	sphere.material.albedo_color = color
	add_child(sphere)
	sphere.global_transform = Transform3D(Basis(), point)

	# Cylinder with one end at point, extending in normal direction
	var cylinder := CSGCylinder3D.new()
	cylinder.name = "DebugNormalCylinder_%d" % iteration
	cylinder.radius = debug_normal_radius * size_scale
	cylinder.height = debug_normal_length * size_scale
	cylinder.use_collision = false
	cylinder.material = StandardMaterial3D.new()
	cylinder.material.albedo_color = color

	# Position cylinder so bottom is at point, top extends in normal direction
	var cyl_center := point + normal * (debug_normal_length * size_scale * 0.5)
	var up := normal
	var right := up.cross(Vector3.FORWARD)
	if right.length_squared() < 0.0001:
		right = up.cross(Vector3.RIGHT)
	right = right.normalized()
	var forward := right.cross(up).normalized()
	var debug_segments: Array = []
	add_child(cylinder)
	cylinder.global_transform = Transform3D(Basis(right, up, forward), cyl_center)

	# If normals differ (we colored green) and we have a previous point, spawn a line of small cubes
	if prev_point != null and color == Color.GREEN:
		var cube_count := 10
		var cube_size := debug_sphere_radius * 0.5 * size_scale
		for j in range(1, cube_count + 1):
			var t := float(j) / float(cube_count + 1)
			var pos := (prev_point as Vector3).lerp(point, t)
			var box_mesh := BoxMesh.new()
			box_mesh.size = Vector3(cube_size, cube_size, cube_size)
			var mi := MeshInstance3D.new()
			mi.name = "DebugCube_%d_%d" % [iteration, j]
			mi.mesh = box_mesh
			mi.material_override = StandardMaterial3D.new()
			mi.material_override.albedo_color = color
			add_child(mi)
			mi.global_transform = Transform3D(Basis(), pos)

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

		# Compare normals to previous; if different, draw spheres along all ray segments that were tested for this point
		var prev_normal := current_normal
		var new_normal := (next_result["normal"] as Vector3).normalized()
		if prev_normal != null and next_result.has("debug_segments"):
			var d := prev_normal.dot(new_normal)
			if d < 0.9999:
				# Spawn spheres for each tested ray segment
				for seg in next_result["debug_segments"]:
					_spawn_toruses_along_segment(seg["start"], seg["end"], 6, Color.CYAN, 0.6)

				# Refinement: sample N points along the concatenated debug ray polyline,
				# raycast from each sample toward the corresponding point along the cube path
				var refinement_count := 10
				# build segment lengths
				var segs = next_result["debug_segments"]
				var seg_lengths := []
				var total_len := 0.0
				for s in segs:
					var l := (s["start"] as Vector3).distance_to(s["end"])
					seg_lengths.append(l)
					total_len += l
				if total_len > 0.0:
					for k in range(1, refinement_count + 1):
						var frac := float(k) / float(refinement_count + 1)
						# find position along polyline at frac
						var dist_along := total_len * frac
						var accum := 0.0
						var source_pos = segs[-1]["end"]
						for idx in range(segs.size()):
							if accum + seg_lengths[idx] >= dist_along:
								var local_t = (dist_along - accum) / seg_lengths[idx]
								source_pos = (segs[idx]["start"] as Vector3).lerp(segs[idx]["end"] as Vector3, local_t)
								break
							accum += seg_lengths[idx]
						# corresponding target along straight line between prev and new point
						var target_pos := (current_point as Vector3).lerp(next_result["point"] as Vector3, frac)
						var dir_vec = (target_pos - source_pos)
						if dir_vec.length_squared() < 1e-8:
							continue
						var ray_hit := _raycast_for_next(source_pos, dir_vec, dir_vec.length() + 0.01)
						if not ray_hit.is_empty():
							points_and_normals.append({"point": ray_hit["position"], "normal": ray_hit["normal"]})

		current_point = next_result["point"]
		current_normal = new_normal
		points_and_normals.append({"point": current_point, "normal": current_normal})

	if DEBUG_PRINTS:
		print("[vines] found ", points_and_normals.size(), " points")

	# Offset points outward by vine_radius along their normals
	var offset_points: Array = []
	for entry in points_and_normals:
		var offset_pt: Vector3 = entry["point"] + entry["normal"] * vine_radius
		offset_points.append(offset_pt)

	# Spawn debug shapes for each point with decreasing size
	for i in range(points_and_normals.size()):
		var size_scale := pow(0.9, float(i))
		var entry = points_and_normals[i]
		var prev_normal = null
		var prev_point = null
		if i > 0:
			prev_normal = points_and_normals[i - 1]["normal"]
			prev_point = points_and_normals[i - 1]["point"]
		_spawn_debug_shapes(entry["point"], entry["normal"], i, size_scale, prev_normal, prev_point)
	
