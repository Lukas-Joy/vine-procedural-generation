@tool
extends Node3D

@export_tool_button("Redraw", "Node3D") var redraw_tool_button = refresh_vines

@export var query_max_distance := 25.0
@export_range(0, 4, 1) var refinement_passes := 2
@export_range(6, 64, 1) var refinement_rays_per_pass := 18
@export var debug_sphere_radius := 0.05
@export var debug_normal_length := 0.5
@export var debug_normal_radius := 0.01

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

func refresh_vines():
	_clear_debug_shapes()
	var origin := global_position
	var point_result = get_closest_surface_point(origin)
	var normal_result = get_closest_surface_normal(origin)

	print("[vines] point=", point_result, " normal=", normal_result)
	if point_result == null or normal_result == null:
		return

	var point: Vector3 = point_result
	var normal: Vector3 = (normal_result as Vector3).normalized()
	var end_point := point + normal * debug_normal_length

	var sphere := CSGSphere3D.new()
	sphere.name = "DebugClosestPointSphere"
	sphere.radius = debug_sphere_radius
	sphere.use_collision = false
	add_child(sphere)
	# set world transform explicitly so child appears at exact world position
	sphere.global_transform = Transform3D(Basis(), point)

	var cylinder := CSGCylinder3D.new()
	cylinder.name = "DebugClosestNormalCylinder"
	cylinder.radius = debug_normal_radius
	cylinder.height = debug_normal_length
	cylinder.use_collision = false

	var midpoint := (point + end_point) * 0.5
	var up := normal
	var right := up.cross(Vector3.FORWARD)
	if right.length_squared() < 0.0001:
		right = up.cross(Vector3.RIGHT)
	right = right.normalized()
	var forward := right.cross(up).normalized()
	add_child(cylinder)
	# set world transform so cylinder aligns correctly in world space
	cylinder.global_transform = Transform3D(Basis(right, up, forward), midpoint)
	
