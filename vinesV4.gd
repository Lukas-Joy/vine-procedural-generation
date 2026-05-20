@tool
extends Node3D

const VINES_PRESET_SCRIPT := preload("res://vines_preset_resource.gd")

@export_tool_button("Redraw", "Node3D") var redraw_tool_button = refresh_vines

@export_category("Preset Setup")
@export_group("Save")
@export var preset_name: String ##Filename used when saving presets into res://vine_presets.
@export var initial_seed: int = 1 ##Base seed used to make every generated result deterministic.
@export_tool_button("Save", "Node3D") var save_preset_tool_button = save_current_preset
@export_group("Load")
@export var preset_file_path: String = "" ##Choose a saved preset from the dropdown list.
@export_tool_button("Load", "Node3D") var load_preset_tool_button = load_current_preset

@export_category("Origin Calculation")
@export var origin_raycast_distance := 2.0 ##Radius in Meters of zone checked to find the closest surface point for the origin.
@export_range(0, 4, 1) var refinement_passes := 2 ##Number of times does extra raycast passes to get more accurate closest surface point.
@export_range(6, 64, 1) var refinement_rays_per_pass := 18 ##Number of raycasts pre refinement pass.

@export_category("Vine Settings")
@export_group("Main Vines")
@export var step_length := 0.5 ##Length of raycast used to find next point in branch.
@export_range(1, 20, 1) var vine_length_min := 5 ##Minimum number of nodes in a single vine branch.
@export_range(1, 20, 1) var vine_length_max := 10 ##Maximum number of nodes in a single vine branch.
@export var vine_radius := 0.01 ##Vine Radius in meters.
@export_range(1, 20, 1) var vine_count := 1 ##Number of branches starting from the origin point.
@export_range(0.0, 180.0, 5.0) var surface_direction_variation_angle := 45.0 ##

@export_group("Secondary Branches")
@export var branch_step_length := 0.5 ##Step length for secondary branches
@export_range(1, 20, 1) var branch_vine_length_min := 3 ##Min length for secondary branches
@export_range(1, 20, 1) var branch_vine_length_max := 6 ##Max length for secondary branches
@export var branch_vine_radius := 0.008 ##Radius for secondary branches
@export_range(0.0, 180.0, 5.0) var branch_surface_direction_variation_angle := 30.0 ##Variation for branch directions
@export_range(0, 5, 1) var branch_spawn_min := 0 ##Min number of secondary branches per main vine
@export_range(0, 5, 1) var branch_spawn_max := 3 ##Max number of secondary branches per main vine

const QUERY_COLLISION_MASK := 1
const COLLIDE_WITH_BODIES := true
const COLLIDE_WITH_AREAS := false
const DEBUG_PRINTS := true
const PRESET_FOLDER := "res://vine_presets"

var _seed_cursor: int = 0
var _preset_picker_labels: PackedStringArray = PackedStringArray(["<None>"])
var _preset_picker_paths: PackedStringArray = PackedStringArray([""])

func _ready() -> void:
	refresh_preset_picker()

func _validate_property(property: Dictionary) -> void:
	if property.name == "preset_file_path":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(_preset_picker_labels)

func refresh_preset_picker() -> void:
	var labels: PackedStringArray = PackedStringArray(["<None>"])
	var paths: PackedStringArray = PackedStringArray([""])

	var dir := DirAccess.open(PRESET_FOLDER)
	if dir != null:
		dir.list_dir_begin()
		while true:
			var file_name := dir.get_next()
			if file_name.is_empty():
				break
			if dir.current_is_dir():
				continue
			var ext := file_name.get_extension().to_lower()
			if ext == "tres" or ext == "res":
				labels.append(file_name)
				paths.append(PRESET_FOLDER.path_join(file_name))
		dir.list_dir_end()

	_preset_picker_labels = labels
	_preset_picker_paths = paths

	if preset_file_path.is_empty() or not _preset_picker_paths.has(preset_file_path):
		preset_file_path = _preset_picker_paths[0]

	notify_property_list_changed()

func _reset_seed_cursor() -> void:
	_seed_cursor = 0

func _next_seed() -> int:
	var seed_value := initial_seed + _seed_cursor
	_seed_cursor += 1
	return seed_value

func _new_deterministic_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _next_seed()
	return rng

func _capture_preset() -> Resource:
	var preset := VINES_PRESET_SCRIPT.new()
	preset.origin_raycast_distance = origin_raycast_distance
	preset.refinement_passes = refinement_passes
	preset.refinement_rays_per_pass = refinement_rays_per_pass
	preset.step_length = step_length
	preset.vine_length_min = vine_length_min
	preset.vine_length_max = vine_length_max
	preset.vine_radius = vine_radius
	preset.vine_count = vine_count
	preset.surface_direction_variation_angle = surface_direction_variation_angle
	preset.branch_step_length = branch_step_length
	preset.branch_vine_length_min = branch_vine_length_min
	preset.branch_vine_length_max = branch_vine_length_max
	preset.branch_vine_radius = branch_vine_radius
	preset.branch_surface_direction_variation_angle = branch_surface_direction_variation_angle
	preset.branch_spawn_min = branch_spawn_min
	preset.branch_spawn_max = branch_spawn_max
	preset.initial_seed = initial_seed
	return preset

func _ensure_preset_folder_exists() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(PRESET_FOLDER)):
		var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PRESET_FOLDER))
		if err != OK:
			push_warning("[vines] Failed to create preset folder %s (error %s)" % [PRESET_FOLDER, err])

func _get_save_preset_path() -> String:
	var file_name := preset_name.strip_edges()
	if file_name.is_empty():
		file_name = "vine_preset"
	if not file_name.ends_with(".tres") and not file_name.ends_with(".res"):
		file_name += ".tres"
	return PRESET_FOLDER.path_join(file_name)

func _apply_preset(preset: Resource) -> void:
	if preset == null:
		return
	if not preset.has_method("get"):
		return
	origin_raycast_distance = preset.origin_raycast_distance
	refinement_passes = preset.refinement_passes
	refinement_rays_per_pass = preset.refinement_rays_per_pass
	step_length = preset.step_length
	vine_length_min = preset.vine_length_min
	vine_length_max = preset.vine_length_max
	vine_radius = preset.vine_radius
	vine_count = preset.vine_count
	surface_direction_variation_angle = preset.surface_direction_variation_angle
	branch_step_length = preset.branch_step_length
	branch_vine_length_min = preset.branch_vine_length_min
	branch_vine_length_max = preset.branch_vine_length_max
	branch_vine_radius = preset.branch_vine_radius
	branch_surface_direction_variation_angle = preset.branch_surface_direction_variation_angle
	branch_spawn_min = preset.branch_spawn_min
	branch_spawn_max = preset.branch_spawn_max
	initial_seed = preset.initial_seed

func save_current_preset() -> void:

	_ensure_preset_folder_exists()
	var save_path := _get_save_preset_path()

	var preset := _capture_preset()
	var err := ResourceSaver.save(preset, save_path)
	if err != OK:
		push_warning("[vines] Failed to save preset to %s (error %s)" % [save_path, err])
		return

	refresh_preset_picker()
	print("[vines] preset saved to ", save_path)

func load_current_preset() -> void:
	if preset_file_path.is_empty():
		push_warning("[vines] Choose a preset from the dropdown before loading.")
		return

	var load_path := preset_file_path

	var loaded := ResourceLoader.load(load_path)
	if loaded == null:
		push_warning("[vines] Failed to load preset from %s" % load_path)
		return
	if not (loaded is VINES_PRESET_SCRIPT):
		push_warning("[vines] The selected file is not a VinesPresetResource: %s" % load_path)
		return

	_apply_preset(loaded)
	refresh_preset_picker()
	print("[vines] preset loaded from ", load_path)
	refresh_vines()

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
		print("[vines] max_distance=", origin_raycast_distance)
		print("[vines] collision_mask=", QUERY_COLLISION_MASK)

	for direction in directions:
		var params := PhysicsRayQueryParameters3D.create(
			query_origin,
			query_origin + direction * origin_raycast_distance,
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
					query_origin + sample_dir * origin_raycast_distance,
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
	var rng := _new_deterministic_rng()
	var angle := rng.randf_range(0.0, PI * 2.0)
	var tangent := normal.cross(Vector3.UP)
	if tangent.length_squared() < 1e-6:
		tangent = normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	return tangent.rotated(normal, angle).normalized()

func _compute_next_point_internal(surface_point: Vector3, surface_normal: Vector3, preferred_surface_dir: Vector3 = Vector3.ZERO, use_step_length: float = -1.0, use_variation_angle: float = -1.0) -> Variant:
	var x := step_length
	if use_step_length > 0.0:
		x = use_step_length
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
		var rng := _new_deterministic_rng()
		var variation_rad := deg_to_rad(surface_direction_variation_angle)
		if use_variation_angle >= 0.0:
			variation_rad = deg_to_rad(use_variation_angle)
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

func refresh_vines() -> void:
	_clear_debug_shapes()
	_reset_seed_cursor()
	var origin := global_position
	var point_result = get_closest_surface_point(origin)
	var normal_result = get_closest_surface_normal(origin)

	if point_result == null or normal_result == null:
		return

	var initial_point: Vector3 = point_result
	var initial_normal: Vector3 = (normal_result as Vector3).normalized()

	# Generate multiple main vines from the same starting point in different directions
	for vine_idx in range(vine_count):
		var initial_dir: Vector3 = Vector3.ZERO
		if vine_idx > 0:
			# For vines after the first, use random directions on the surface plane
			initial_dir = _random_in_plane_direction(initial_normal)

		# Determine randomized main vine length
		var rng := _new_deterministic_rng()
		var main_len := rng.randi_range(vine_length_min, vine_length_max)
		var settings := {
			"step_length": step_length,
			"vine_length": main_len,
			"vine_radius": vine_radius,
			"surface_direction_variation_angle": surface_direction_variation_angle
		}

		var vine_res = _generate_single_vine(initial_point, initial_normal, initial_dir, settings)
		if vine_res != null and vine_res.has("mesh") and vine_res["mesh"] != null:
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.mesh = vine_res["mesh"]
			mesh_instance.material_override = StandardMaterial3D.new()
			mesh_instance.material_override.albedo_color = Color.GREEN
			add_child(mesh_instance)
			if DEBUG_PRINTS:
				print("[vines] vine ", vine_idx, " mesh added to scene")

			# Spawn random secondary branches along the smoothed main curve
			var spawn_count_rng := _new_deterministic_rng()
			var spawn_count := spawn_count_rng.randi_range(branch_spawn_min, branch_spawn_max)
			for b_i in range(spawn_count):
				if vine_res["curve_points"].size() < 2:
					continue
				var branch_sample_rng := _new_deterministic_rng()
				var t_norm := branch_sample_rng.randf()
				t_norm = clamp(t_norm, 0.0, 1.0)
				var seg_f := t_norm * float(vine_res["curve_points"].size() - 1)
				var idx := int(floor(seg_f))
				var idx_next = min(idx + 1, vine_res["curve_points"].size() - 1)
				var alpha := seg_f - float(idx)
				var spawn_pos := (vine_res["curve_points"][idx] as Vector3).lerp(vine_res["curve_points"][idx_next] as Vector3, alpha)

				# pick a normal from the raw points_and_normals mapping
				var pn_count = vine_res["points_and_normals"].size()
				var p_idx_f := t_norm * float(max(1, pn_count - 1))
				var p_idx := int(round(p_idx_f))
				p_idx = clamp(p_idx, 0, pn_count - 1)
				var spawn_normal := (vine_res["points_and_normals"][p_idx]["normal"] as Vector3).normalized()

				# Derive an initial direction from curve tangent projected on surface plane
				var tangent: Vector3 = Vector3.FORWARD
				if vine_res["curve_points"].size() >= 3:
					var t_i0 = max(0, idx - 1)
					var t_i1 = min(vine_res["curve_points"].size() - 1, idx + 1)
					tangent = (vine_res["curve_points"][t_i1] - vine_res["curve_points"][t_i0]).normalized()
				var branch_initial_dir := (tangent - tangent.dot(spawn_normal) * spawn_normal).normalized()

				var branch_len_rng := _new_deterministic_rng()
				var branch_len := branch_len_rng.randi_range(branch_vine_length_min, branch_vine_length_max)
				var branch_settings := {
					"step_length": branch_step_length,
					"vine_length": branch_len,
					"vine_radius": branch_vine_radius,
					"surface_direction_variation_angle": branch_surface_direction_variation_angle
				}

				var branch_res = _generate_single_vine(spawn_pos, spawn_normal, branch_initial_dir, branch_settings)
				if branch_res != null and branch_res.has("mesh") and branch_res["mesh"] != null:
					var bmesh_inst := MeshInstance3D.new()
					bmesh_inst.mesh = branch_res["mesh"]
					bmesh_inst.material_override = StandardMaterial3D.new()
					bmesh_inst.material_override.albedo_color = Color(0.0, 0.6, 0.0)
					add_child(bmesh_inst)
	


func _build_tubular_mesh(curve_points: Array, radius: float) -> Mesh:
	if curve_points.size() < 2:
		return null

	var vertices: PackedVector3Array = []
	var indices: PackedInt32Array = []
	var normals: PackedVector3Array = []

	var circle_segments := 16
	var radius_vec := radius

	# Store tangents for each curve point
	var tangents: Array[Vector3] = []
	for i in range(curve_points.size()):
		var pt = curve_points[i]
		var tangent: Vector3

		if i == 0:
			tangent = (curve_points[1] - curve_points[0]).normalized()
		elif i == curve_points.size() - 1:
			tangent = (curve_points[i] - curve_points[i - 1]).normalized()
		else:
			tangent = (curve_points[i + 1] - curve_points[i - 1]).normalized()

		tangents.append(tangent)

	# Build circle vertices and normals
	for i in range(curve_points.size()):
		var pt = curve_points[i]
		var tangent = tangents[i]

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

	# Add cap centers with matching normals
	var center_start_idx := vertices.size()
	vertices.append(curve_points[0])
	normals.append(tangents[0])

	var center_end_idx := vertices.size()
	vertices.append(curve_points[-1])
	normals.append(tangents[-1])

	# Cap at start
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

	if DEBUG_PRINTS:
		print("[vines] _build_tubular_mesh:")
		print("[vines]   curve_points.size()=", curve_points.size())
		print("[vines]   vertices.size()=", vertices.size())
		print("[vines]   normals.size()=", normals.size())
		print("[vines]   indices.size()=", indices.size())

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	if DEBUG_PRINTS:
		print("[vines] Mesh surface added. Surface count: ", mesh.get_surface_count())
		var aabb := mesh.get_aabb()
		print("[vines] Mesh AABB: ", aabb)
	
	return mesh


func _extract_mesh_from_scene(scene: PackedScene) -> Mesh:
	if scene == null:
		return null
	var inst := scene.instantiate()
	# Search for first MeshInstance3D
	var mesh_res: Mesh = null
	if typeof(inst) == TYPE_OBJECT and inst is MeshInstance3D:
		mesh_res = inst.mesh
	else:
		var stack := [inst]
		while stack.size() > 0:
			var node = stack.pop_back()
			for child in node.get_children():
				if child is MeshInstance3D and mesh_res == null:
					mesh_res = child.mesh
				elif child.get_child_count() > 0:
					stack.append(child)
	inst.queue_free()
	return mesh_res


func _build_tube_surface_placements(curve_points: Array, radius: float, density: float) -> Array:
	var placements: Array = []
	if curve_points.size() < 2:
		return placements
	if density <= 0.0:
		return placements

	var rng := _new_deterministic_rng()

	# Density is interpreted as a normalized fraction of curve samples.
	var sample_count := int(round(float(curve_points.size()) * clamp(density, 0.0, 1.0)))
	sample_count = max(1, sample_count)

	for i in range(sample_count):
		var t_norm := (float(i) + rng.randf() * 0.35) / float(sample_count)
		t_norm = clamp(t_norm, 0.0, 1.0)
		var seg_f := t_norm * float(curve_points.size() - 1)
		var idx := int(floor(seg_f))
		var idx_next = min(idx + 1, curve_points.size() - 1)
		var alpha := seg_f - float(idx)

		var p0: Vector3 = curve_points[idx]
		var p1: Vector3 = curve_points[idx_next]
		var center: Vector3 = p0.lerp(p1, alpha)

		var tangent: Vector3
		if idx == 0:
			tangent = (curve_points[1] - curve_points[0]).normalized()
		elif idx >= curve_points.size() - 2:
			tangent = (curve_points[curve_points.size() - 1] - curve_points[curve_points.size() - 2]).normalized()
		else:
			tangent = (curve_points[idx + 1] - curve_points[idx - 1]).normalized()

		# Build a stable ring frame around the tangent and pick a random angle on the tube surface.
		var ref_up := Vector3.UP
		if abs(tangent.dot(ref_up)) > 0.9:
			ref_up = Vector3.RIGHT
		var right := tangent.cross(ref_up).normalized()
		var forward := tangent.cross(right).normalized()
		var ang := rng.randf_range(0.0, TAU)
		var outward := (right * cos(ang) + forward * sin(ang)).normalized()
		var surface_point := center + outward * radius

		placements.append({
			"point": surface_point,
			"outward": outward,
			"tangent": tangent
		})

	return placements


func _generate_single_vine(initial_point: Vector3, initial_normal: Vector3, initial_dir: Vector3, settings: Dictionary = {}) -> Dictionary:
	var rng := _new_deterministic_rng()

	var points_and_normals: Array = []
	var current_point: Vector3 = initial_point
	var current_normal: Vector3 = (initial_normal as Vector3).normalized()

	# Localized settings (fall back to global defaults)
	var local_step_length = settings["step_length"] if settings.has("step_length") else step_length
	var local_vine_length := int(settings["vine_length"]) if settings.has("vine_length") else rng.randi_range(vine_length_min, vine_length_max)
	var local_vine_radius = settings["vine_radius"] if settings.has("vine_radius") else vine_radius
	var local_variation = settings["surface_direction_variation_angle"] if settings.has("surface_direction_variation_angle") else surface_direction_variation_angle

	# Store first point and normal
	points_and_normals.append({"point": current_point, "normal": current_normal})

	# Iterate to find next points with direction continuity
	var preferred_surface_dir: Vector3 = initial_dir.normalized() if initial_dir.length_squared() > 0.0001 else Vector3.ZERO
	for iteration in range(1, local_vine_length):
		# Compute preferred direction from last two points if available
		if points_and_normals.size() >= 2:
			var p_prev: Vector3 = points_and_normals[-1]["point"]
			var p_prev_prev: Vector3 = points_and_normals[-2]["point"]
			var trend: Vector3 = (p_prev - p_prev_prev).normalized()
			# Project trend onto surface plane (perpendicular to normal)
			preferred_surface_dir = (trend - trend.dot(current_normal) * current_normal).normalized()

		var next_result = _compute_next_point_internal(current_point, current_normal, preferred_surface_dir, local_step_length, local_variation)
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

	# Offset points outward by local_vine_radius along their normals
	var offset_points: Array = []
	for entry in points_and_normals:
		var offset_pt: Vector3 = entry["point"] + entry["normal"] * local_vine_radius
		offset_points.append(offset_pt)

	# Build Catmull-Rom curve (world-space)
	var curve_points := _build_catmull_rom_curve(offset_points)

	# Convert curve points to local space (relative to node position) for mesh building
	var local_curve_points: Array = []
	for pt in curve_points:
		local_curve_points.append(pt - global_position)

	# Build tubular mesh using local radius
	var mesh := _build_tubular_mesh(local_curve_points, local_vine_radius)

	return {"mesh": mesh, "curve_points": curve_points, "points_and_normals": points_and_normals}
	
