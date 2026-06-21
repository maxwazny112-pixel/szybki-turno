extends Marker3D

# This allows you to easily assign the PlayerCar in the Inspector if the path ever changes
@export var player_path: NodePath = "../PlayerCar"

func _ready():
	# call_deferred waits until the end of the current frame.
	# This guarantees the MapBuilder has completely finished generating the city's 
	# physics collisions before we drop the car onto it.
	call_deferred("_teleport_player")

func _teleport_player():
	var player = get_node_or_null(player_path)
	
	if player:
		# Snap the car exactly to the Marker3D's position
		player.global_position = global_position
		
		# Snap the car's steering/facing direction to match the Marker3D's rotation
		player.global_rotation.y = global_rotation.y
		
		# Reset the car's physics momentum so it doesn't spawn already moving
		player.velocity = Vector3.ZERO
	else:
		push_error("SpawnPoint: PlayerCar not found at the specified path.")
