extends Node

# Drag the SilverLakeMap node into this slot in the Inspector
@export var target_map: Node3D 

func _ready():
	if target_map:
		_build_collisions(target_map)
	else:
		push_error("MapBuilder: target_map is not assigned.")

func _build_collisions(current_node: Node):
	# Iterate through all children of the current node
	for child in current_node.get_children():
		if child is MeshInstance3D:
			# Automatically generates a StaticBody3D with a precise Trimesh collision shape
			child.create_trimesh_collision()
		
		# Recursively search deeper into the node tree
		if child.get_child_count() > 0:
			_build_collisions(child)
