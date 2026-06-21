extends Node3D

func _ready():
	# As soon as the game loads, start scanning the map!
	_generate_collisions(self)
	print("SUNDOWN MAP COLLISION GENERATED!")

func _generate_collisions(node: Node):
	for child in node.get_children():
		# If it finds a 3D Mesh, it forces Godot to build a Trimesh Collision for it!
		if child is MeshInstance3D:
			child.create_trimesh_collision()
			
		# Recursively dig deeper to find meshes inside folders/other nodes
		if child.get_child_count() > 0:
			_generate_collisions(child)
