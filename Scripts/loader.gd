@tool
extends Node2D

@export var save_path: String = "res://saved/collision_polygon.save"

@export var load_polygon := false:
	set(value):
		if value:
			_load_polygon_data()
			call_deferred("set", "load_polygon", false)

func _load_polygon_data() -> void:
	# This is a more robust check. Instead of checking the node's type with 'is',
	# we check if the node has the 'polygon' property we need to modify.
	# This works for both Polygon2D and CollisionPolygon2D.
	if not "polygon" in self:
		push_error("This script must be attached to a node that has a 'polygon' property, like Polygon2D or CollisionPolygon2D.")
		return
		
	if not FileAccess.file_exists(save_path):
		push_error("Save file does not exist: " + save_path)
		return

	var f = FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		push_error("Failed to open save file: " + save_path)
		return
	
	var data = f.get_var()
	f.close()

	if typeof(data) != TYPE_DICTIONARY or not data.has("points"):
		push_error("Invalid or corrupted save file. Could not find 'points' data.")
		return

	var points = data["points"]
	if typeof(points) == TYPE_PACKED_VECTOR2_ARRAY and points.size() >= 3:
		self.polygon = points
		print("Successfully loaded and applied polygon data to " + str(self.get_class()) + " from: " + save_path)
	else:
		push_error("No valid polygon data found in the file.")
