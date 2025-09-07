# ColorToPolygon.gd - v2.1 for Godot 4.x
# Corrected the parser error related to null Vector2i.
extends Node2D

# --- EXPORT VARIABLES (Set these in the Inspector) ---

@export_group("Input Settings")
@export var source_texture: Texture2D
@export var target_color: Color = Color.BLACK

@export_group("Color Matching")
@export_range(0.0, 1.732, 0.01) var rgb_tolerance: float = 0.1
@export var match_alpha: bool = true
@export_range(0.0, 1.0, 0.01) var alpha_tolerance: float = 0.1

@export_group("Polygon Generation")
@export var polygon_color: Color = Color(1, 1, 0, 0.5)
@export var simplify_polygon: bool = true
@export_range(0.1, 10.0) var simplification_distance: float = 1.0

@export_group("Debugging")
@export var debug_mode: bool = false


# --- PRIVATE VARIABLES ---
var _image: Image
var _visited: Array[bool]
var _width: int
var _height: int
var _polygons_created_count := 0


# --- GODOT FUNCTIONS ---

func _ready() -> void:
	if source_texture:
		generate_polygons_from_texture(source_texture)
	else:
		printerr("ColorToPolygon: No source_texture assigned.")


# --- CORE LOGIC ---

func generate_polygons_from_texture(texture: Texture2D) -> void:
	_image = texture.get_image()
	if not _image:
		printerr("ColorToPolygon: Could not get image data from texture.")
		return
	
	_width = _image.get_width()
	_height = _image.get_height()
	
	_visited.resize(_width * _height)
	_visited.fill(false)
	
	if debug_mode:
		print("--- Starting Polygon Generation ---")
		print("Target Color: R=%.2f, G=%.2f, B=%.2f, A=%.2f" % [target_color.r, target_color.g, target_color.b, target_color.a])
		print("RGB Tolerance: %.2f, Match Alpha: %s" % [rgb_tolerance, match_alpha])
	
	for y in range(_height):
		for x in range(_width):
			if not _is_visited(x, y):
				var pixel_color = _image.get_pixel(x, y)
				
				if _is_color_match(pixel_color, Vector2i(x,y)):
					if debug_mode: print("Found new unvisited shape at %s. Starting trace..." % Vector2i(x,y))
					var boundary_points: PackedVector2Array = _trace_boundary(Vector2i(x, y))
					
					if boundary_points.size() > 2:
						_create_polygon_node(boundary_points)
						_polygons_created_count += 1
						
					_flood_fill_mark_visited(Vector2i(x, y))

	if _polygons_created_count == 0:
		print("ColorToPolygon: Scan complete. No matching color regions were found.")
		print("  - Try increasing the 'RGB Tolerance' value.")
		print("  - Double-check that 'Target Color' is correct.")
		print("  - Try disabling 'Match Alpha' if transparency is not important.")


# --- HELPER FUNCTIONS ---

func _create_polygon_node(points: PackedVector2Array) -> void:
	var final_points = points
	if simplify_polygon and points.size() > 2:
		# Note: The simplification algorithm is basic and may not be perfect.
		# For production use, a more robust implementation might be needed.
		final_points = _simplify_rdp(points, simplification_distance)

	var poly_node = Polygon2D.new()
	poly_node.polygon = final_points
	poly_node.color = polygon_color
	add_child(poly_node)
	if debug_mode:
		print("  -> Created polygon. Original vertices: %d, Simplified vertices: %d" % [points.size(), final_points.size()])

func _trace_boundary(start_pos: Vector2i) -> PackedVector2Array:
	var boundary_points = PackedVector2Array()
	const DIRECTIONS = [Vector2i(0,-1),Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(-1,-1)]
	var current_pos := start_pos
	var last_dir_index := 4
	while true:
		var found_next_pixel := false
		for i in range(8):
			var dir_index = (last_dir_index + 1 + i) % 8
			var check_pos = current_pos + DIRECTIONS[dir_index]
			if _is_valid_pixel(check_pos.x, check_pos.y):
				boundary_points.append(current_pos)
				current_pos = check_pos
				last_dir_index = (dir_index + 4) % 8
				found_next_pixel = true
				break
		if current_pos == start_pos: break
		if not found_next_pixel: boundary_points.append(current_pos); break
	return boundary_points

func _flood_fill_mark_visited(start_pos: Vector2i) -> void:
	var queue: Array[Vector2i] = [start_pos]
	_set_visited(start_pos.x, start_pos.y)
	while not queue.is_empty():
		var pos = queue.pop_front()
		const OFFSETS = [Vector2i(0,1),Vector2i(0,-1),Vector2i(1,0),Vector2i(-1,0)]
		for offset in OFFSETS:
			var check_pos = pos + offset
			if _is_valid_pixel(check_pos.x, check_pos.y) and not _is_visited(check_pos.x, check_pos.y):
				_set_visited(check_pos.x, check_pos.y)
				queue.append(check_pos)

func _is_valid_pixel(x: int, y: int) -> bool:
	if x < 0 or x >= _width or y < 0 or y >= _height: return false
	# The call to _is_color_match now correctly passes null without a type error.
	if not _is_color_match(_image.get_pixel(x, y), null): return false
	return true

# --- FIX IS HERE ---
# The 'pos' argument is now a 'Variant' with a default 'null' value.
# This makes it optional and resolves the parser error.
func _is_color_match(c: Color, pos: Variant = null) -> bool:
	var color_vec := Vector3(c.r, c.g, c.b)
	var target_vec := Vector3(target_color.r, target_color.g, target_color.b)
	var rgb_distance: float = color_vec.distance_to(target_vec)

	if rgb_distance <= rgb_tolerance:
		if match_alpha:
			var a_diff: float = abs(c.a - target_color.a)
			if a_diff <= alpha_tolerance:
				return true # RGB and Alpha both match
			elif debug_mode and pos != null:
				print("  DEBUG [%s]: Pixel passed RGB check (dist %.3f) but failed Alpha check (diff %.3f)." % [pos, rgb_distance, a_diff])
		else:
			return true # RGB matches and we are ignoring Alpha
	
	return false

func _simplify_rdp(point_list: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	if point_list.size() < 3: return point_list
	var dmax: float = 0.0
	var index: int = 0
	var end: int = point_list.size() - 1
	for i in range(1, end):
		var p = point_list[i]
		var start_p = point_list[0]
		var end_p = point_list[end]
		var d = p.distance_to(start_p.lerp(end_p, start_p.distance_to(p) / start_p.distance_to(end_p) * (end_p - start_p).normalized().dot((p-start_p).normalized())))
		if d > dmax:
			index = i
			dmax = d
	var result_list: PackedVector2Array
	if dmax > epsilon:
		var rec_results1: PackedVector2Array = _simplify_rdp(point_list.slice(0, index + 1), epsilon)
		var rec_results2: PackedVector2Array = _simplify_rdp(point_list.slice(index, end + 1), epsilon)
		result_list.append_array(rec_results1.slice(0, rec_results1.size() - 1))
		result_list.append_array(rec_results2)
	else:
		result_list.append(point_list[0])
		result_list.append(point_list[end])
	return result_list

func _is_visited(x: int, y: int) -> bool: return _visited[y * _width + x]
func _set_visited(x: int, y: int) -> void: _visited[y * _width + x] = true
