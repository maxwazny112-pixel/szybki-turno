extends SpringArm3D

const ROTATION_SPEED = 4.0
const RETURN_SPEED = 5.0
const PITCH_LIMIT_UP = 10.0
const PITCH_LIMIT_DOWN = -35.0

var current_yaw: float = 0.0
var current_pitch: float = -10.0

@onready var car = get_parent()

func _ready():
	# 1. Detach from the car's rigid rotation so we can orbit smoothly
	top_level = true 
	
	# 2. Force the camera to lock exactly to the end of the spring arm
	if get_child_count() > 0:
		var cam = get_child(0)
		cam.position = Vector3.ZERO
		cam.rotation = Vector3.ZERO

	# 3. Adjust camera collision and distance
	shape = SphereShape3D.new()
	shape.radius = 0.5
	spring_length = 5.0 # Brought the camera slightly closer

func _process(delta):
	# 4. Manually follow the car's position, but lowered to 0.8 so it's not too high
	global_position = car.global_position + Vector3(0, 0.8, 0)

	# 5. Get right stick inputs
	var cam_x = Input.get_axis("camera_left", "camera_right")
	var cam_y = Input.get_axis("camera_up", "camera_down")

	# 6. Handle Orbit vs Return
	if abs(cam_x) > 0.1 or abs(cam_y) > 0.1:
		# Player is moving the stick: orbit the camera
		current_yaw -= cam_x * ROTATION_SPEED * delta
		current_pitch -= cam_y * ROTATION_SPEED * delta
	else:
		# Player let go: smoothly snap back to face the same direction as the Pungli
		current_yaw = lerp_angle(current_yaw, car.global_rotation.y, RETURN_SPEED * delta)
		current_pitch = lerp_angle(current_pitch, deg_to_rad(-10.0), RETURN_SPEED * delta)

	# Clamp the up/down angle so it doesn't flip under the floor
	current_pitch = clamp(current_pitch, deg_to_rad(PITCH_LIMIT_DOWN), deg_to_rad(PITCH_LIMIT_UP))

	# 7. Apply the final rotation in world space
	global_rotation.y = current_yaw
	global_rotation.x = current_pitch
	global_rotation.z = 0.0
