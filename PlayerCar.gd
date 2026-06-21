extends CharacterBody3D

const ACCELERATION = 60.0 
const BRAKING = 40.0
const FRICTION = 2.5 
const GRAVITY = 9.8

var was_drifting = false
var last_pos_left = null
var last_pos_right = null

@export var engine_sound: AudioStream
var engine_player: AudioStreamPlayer

# --- MRF RADIO ---
@export_group("MRF Radio")
@export var mrf_intro: AudioStream
@export var mrf_songs: Array[AudioStream]
var mrf_player: AudioStreamPlayer
var mrf_track_name: String = ""
var target_mrf_vol: float = -60.0 
var mrf_playing_intro: bool = false

# --- SILVER RADIO ---
@export_group("Silver Radio")
@export var silver_intro: AudioStream
@export var silver_news: Array[AudioStream]
var silver_player: AudioStreamPlayer
var silver_track_name: String = ""
var target_silver_vol: float = -60.0 
var silver_playing_intro: bool = false

# --- COSA ESPAÑOLA ---
@export_group("Cosa Espanola")
@export var cosa_espanola_intro: AudioStream
@export var cosa_espanola_songs: Array[AudioStream]
var cosa_player: AudioStreamPlayer
var cosa_track_name: String = ""
var target_cosa_vol: float = -60.0 
var cosa_playing_intro: bool = false

var current_station: int = 0 
var radio_ui_node: Control
var radio_label: Label # Shows the Station Name
var song_label: Label  # Shows the Song Name

var speed_label: Label
var unit_label: Label
var is_mph: bool = false 

@onready var horn_sound = $HornSound
@onready var tire_mark_left = $TireMarkLeft
@onready var tire_mark_right = $TireMarkRight
var target_horn_volume = -60.0 

# --- HARDWARE CONTROLLER TRACKING ---
var was_joy_up_pressed = false

func _ready():
	safe_margin = 0.15 
	floor_max_angle = deg_to_rad(65) 
	
	_create_speedometer_ui()
	_create_radio_ui()
	horn_sound.volume_db = target_horn_volume
	
	engine_player = AudioStreamPlayer.new()
	add_child(engine_player)
	if engine_sound:
		engine_player.stream = engine_sound
		engine_player.volume_db = -60.0 
	
	# Setup MRF
	mrf_player = AudioStreamPlayer.new()
	add_child(mrf_player)
	mrf_player.finished.connect(_on_mrf_track_finished)
	mrf_player.volume_db = -60.0
	if mrf_intro:
		mrf_playing_intro = true
		mrf_player.stream = mrf_intro
		mrf_player.play()
	else:
		_play_mrf_random()
		
	# Setup Silver
	silver_player = AudioStreamPlayer.new()
	add_child(silver_player)
	silver_player.finished.connect(_on_silver_track_finished)
	silver_player.volume_db = -60.0
	if silver_intro:
		silver_playing_intro = true
		silver_player.stream = silver_intro
		silver_player.play()
	else:
		_play_silver_random()
		
	# Setup Cosa Espanola
	cosa_player = AudioStreamPlayer.new()
	add_child(cosa_player)
	cosa_player.finished.connect(_on_cosa_track_finished)
	cosa_player.volume_db = -60.0
	if cosa_espanola_intro:
		cosa_playing_intro = true
		cosa_player.stream = cosa_espanola_intro
		cosa_player.play()
	else:
		_play_cosa_random()

func change_speed_unit(to_mph: bool):
	is_mph = to_mph
	if unit_label:
		unit_label.text = "mph" if is_mph else "kmh"

func _create_speedometer_ui():
	var ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var speedo_base = Control.new()
	speedo_base.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	speedo_base.position = Vector2(-300, -100) 
	ui_layer.add_child(speedo_base)

	var bg = Polygon2D.new()
	bg.color = Color(0.1, 0.1, 0.1, 0.85) 
	bg.polygon = PackedVector2Array([
		Vector2(30, 0), Vector2(270, 0), 
		Vector2(240, 70), Vector2(0, 70) 
	])
	speedo_base.add_child(bg)
	
	var top_border = Polygon2D.new()
	top_border.color = Color(0.15, 0.35, 0.8) 
	top_border.polygon = PackedVector2Array([
		Vector2(30, 0), Vector2(270, 0),
		Vector2(268, 5), Vector2(28, 5)
	])
	speedo_base.add_child(top_border)
	
	var bot_border = Polygon2D.new()
	bot_border.color = Color(0.15, 0.35, 0.8) 
	bot_border.polygon = PackedVector2Array([
		Vector2(2, 65), Vector2(242, 65),
		Vector2(240, 70), Vector2(0, 70)
	])
	speedo_base.add_child(bot_border)

	var sys_font = SystemFont.new()
	sys_font.font_weight = 900 
	sys_font.font_italic = true 
	
	var num_settings = LabelSettings.new()
	num_settings.font = sys_font
	num_settings.font_size = 64
	num_settings.font_color = Color(1.0, 0.8, 0.0) 
	num_settings.outline_color = Color(0.0, 0.0, 0.0)
	num_settings.outline_size = 12
	num_settings.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	num_settings.shadow_offset = Vector2(4, 4)

	var unit_settings = num_settings.duplicate()
	unit_settings.font_size = 36
	unit_settings.font_color = Color(1.0, 0.6, 0.0) 
	unit_settings.outline_size = 8

	speed_label = Label.new()
	speed_label.text = "0"
	speed_label.label_settings = num_settings
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_label.custom_minimum_size = Vector2(120, 70)
	speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speed_label.position = Vector2(20, -5) 
	speedo_base.add_child(speed_label)

	unit_label = Label.new()
	unit_label.text = "kmh"
	unit_label.label_settings = unit_settings
	unit_label.position = Vector2(150, 18) 
	speedo_base.add_child(unit_label)

func _create_radio_ui():
	var ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	radio_ui_node = Control.new()
	radio_ui_node.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	radio_ui_node.position = Vector2(50, -35) 
	ui_layer.add_child(radio_ui_node)

	# Increased height to 75 to fit two lines of text!
	var bg = Polygon2D.new()
	bg.color = Color(0.1, 0.1, 0.1, 0.85) 
	bg.polygon = PackedVector2Array([
		Vector2(15, 0), Vector2(260, 0), 
		Vector2(245, 75), Vector2(0, 75) 
	])
	radio_ui_node.add_child(bg)
	
	var left_border = Polygon2D.new()
	left_border.color = Color(0.15, 0.35, 0.8) 
	left_border.polygon = PackedVector2Array([
		Vector2(15, 0), Vector2(20, 0),
		Vector2(5, 75), Vector2(0, 75)
	])
	radio_ui_node.add_child(left_border)

	var sys_font = SystemFont.new()
	sys_font.font_weight = 900 
	sys_font.font_italic = true 
	
	# Station Name Settings
	var text_settings = LabelSettings.new()
	text_settings.font = sys_font
	text_settings.font_size = 28
	text_settings.font_color = Color(1.0, 0.8, 0.0) 
	text_settings.outline_color = Color(0.0, 0.0, 0.0)
	text_settings.outline_size = 6

	# Song Name Settings
	var song_settings = LabelSettings.new()
	song_settings.font = sys_font
	song_settings.font_size = 20
	song_settings.font_color = Color(1.0, 1.0, 1.0) # Crisp White
	song_settings.outline_color = Color(0.0, 0.0, 0.0)
	song_settings.outline_size = 4

	radio_label = Label.new()
	radio_label.text = "STATION"
	radio_label.label_settings = text_settings
	radio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	radio_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	radio_label.custom_minimum_size = Vector2(240, 35)
	radio_label.position = Vector2(10, 0)
	radio_ui_node.add_child(radio_label)
	
	song_label = Label.new()
	song_label.text = "Song Name"
	song_label.label_settings = song_settings
	song_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	song_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	song_label.custom_minimum_size = Vector2(240, 35)
	song_label.position = Vector2(5, 35)
	radio_ui_node.add_child(song_label)
	
	radio_ui_node.visible = false

# --- PHYSICS & MECHANICS ---
func _physics_process(delta):
	if not is_on_floor(): velocity.y -= GRAVITY * delta

	var drive_input = Input.get_axis("drive_backward", "drive_forward") 
	var steer_input = Input.get_axis("steer_right", "steer_left") 
	var is_drifting = Input.is_action_pressed("handbrake")

	# --- 1. DYNAMIC TUNING CALCULATIONS ---
	var tune_speed = SaveSystem.get_tune_level("speed")
	var tune_hand = SaveSystem.get_tune_level("handling")
	var tune_drft = SaveSystem.get_tune_level("drift")
	
	var current_max_speed = 55.5 + (tune_speed * 8.33)
	var base_steer = 2.5 + (tune_hand * 0.15)
	var current_steer_sens = base_steer * (1.5 if is_drifting else 1.0)
	var current_traction_drift = max(0.1, 1.0 - (tune_drft * 0.05))
	var current_grip = current_traction_drift if is_drifting else 5.0

	# --- 2. MOVEMENT ---
	var forward_dir = -transform.basis.z
	var forward_speed = velocity.dot(forward_dir) 
	
	if abs(forward_speed) > 1.0:
		var reverse_multiplier = 1.0 if forward_speed > 0.0 else -1.0
		rotation.y += steer_input * current_steer_sens * delta * reverse_multiplier

	var target_speed = drive_input * current_max_speed
	var accel_rate = ACCELERATION
	if drive_input == 0:
		accel_rate = FRICTION
	elif sign(drive_input) != sign(forward_speed) and abs(forward_speed) > 1.0:
		accel_rate = BRAKING

	forward_speed = move_toward(forward_speed, target_speed, accel_rate * delta)
	var desired_velocity = forward_dir * forward_speed

	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	horizontal_velocity = horizontal_velocity.lerp(desired_velocity, current_grip * delta)
	
	var current_vy = velocity.y
	velocity = horizontal_velocity
	velocity.y = current_vy

	move_and_slide()
	
	if is_on_wall() and is_on_floor() and abs(forward_speed) > 2.0:
		var space_state = get_world_3d().direct_space_state
		var origin = global_position + Vector3(0, 0.6, 0) 
		var end = origin + forward_dir * 1.5 
		var query = PhysicsRayQueryParameters3D.create(origin, end)
		query.exclude = [self.get_rid()] 
		var head_hit = space_state.intersect_ray(query)
		if not head_hit:
			position.y += 0.15 
			velocity.y = 1.0   
	
	if is_drifting and is_on_floor() and abs(forward_speed) > 2.0:
		var current_pos_l = _get_ground_pos(tire_mark_left.global_position)
		var current_pos_r = _get_ground_pos(tire_mark_right.global_position)
		if was_drifting:
			if current_pos_l != null and last_pos_left != null:
				_spawn_skid_segment(last_pos_left, current_pos_l)
			if current_pos_r != null and last_pos_right != null:
				_spawn_skid_segment(last_pos_right, current_pos_r)
		last_pos_left = current_pos_l
		last_pos_right = current_pos_r
		was_drifting = true
	else:
		was_drifting = false 

	# --- AUDIO & UI SYSTEM ---
	var current_horiz_speed = horizontal_velocity.length()
	
	if current_horiz_speed > 0.5: 
		if engine_sound and not engine_player.playing:
			engine_player.play()
			
		var speed_factor = current_horiz_speed / current_max_speed
		engine_player.pitch_scale = lerp(0.8, 2.5, speed_factor)
		engine_player.volume_db = lerp(engine_player.volume_db, 0.0, 5.0 * delta)
	else:
		engine_player.volume_db = lerp(engine_player.volume_db, -60.0, 5.0 * delta)
		if engine_player.volume_db <= -55.0 and engine_player.playing:
			engine_player.stop()

	# --- RADIO CONTROLS (Keyboard + Hardware D-Pad) ---
	var dpad_up = Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP)
	if Input.is_action_just_pressed("toggle_radio") or (dpad_up and not was_joy_up_pressed): 
		_cycle_radio()
	was_joy_up_pressed = dpad_up

	if Input.is_action_pressed("sound_horn"):
		target_horn_volume = 0.0 
		if not horn_sound.playing: horn_sound.play()
	else:
		target_horn_volume = -60.0 

	horn_sound.volume_db = lerp(horn_sound.volume_db, target_horn_volume, 12.0 * delta)
	if target_horn_volume == -60.0 and horn_sound.volume_db < -55.0 and horn_sound.playing:
		horn_sound.stop()
		
	mrf_player.volume_db = lerp(mrf_player.volume_db, target_mrf_vol, 10.0 * delta)
	silver_player.volume_db = lerp(silver_player.volume_db, target_silver_vol, 10.0 * delta)
	cosa_player.volume_db = lerp(cosa_player.volume_db, target_cosa_vol, 10.0 * delta)
	
	# Update Radio UI Text dynamically
	if current_station == 1:
		radio_label.text = "MRF RADIO"
		song_label.text = "" if mrf_playing_intro else mrf_track_name
	elif current_station == 2:
		radio_label.text = "SILVER RADIO"
		song_label.text = "" if silver_playing_intro else silver_track_name
	elif current_station == 3:
		radio_label.text = "COSA ESPAÑOLA"
		song_label.text = "" if cosa_playing_intro else cosa_track_name
	
	var speed_mult = 2.23694 if is_mph else 3.6
	var speed_val = current_horiz_speed * speed_mult
	speed_label.text = str(int(speed_val))

func _cycle_radio():
	current_station = (current_station + 1) % 4

	target_mrf_vol = -60.0
	target_silver_vol = -60.0
	target_cosa_vol = -60.0

	if current_station == 0:
		radio_ui_node.visible = false
	elif current_station == 1:
		radio_ui_node.visible = true
		target_mrf_vol = 0.0
	elif current_station == 2:
		radio_ui_node.visible = true
		target_silver_vol = 0.0
	elif current_station == 3:
		radio_ui_node.visible = true
		target_cosa_vol = 0.0

func _on_mrf_track_finished():
	_play_mrf_random()

func _on_silver_track_finished():
	_play_silver_random()

func _on_cosa_track_finished():
	_play_cosa_random()

func _play_mrf_random():
	mrf_playing_intro = false # Intro is over!
	if mrf_songs.size() > 0:
		var random_index = randi() % mrf_songs.size()
		var song = mrf_songs[random_index]
		mrf_player.stream = song
		mrf_player.play()
		
		var song_name = song.resource_path.get_file().get_basename()
		if song_name == "": song_name = "MRF Track " + str(random_index + 1)
		mrf_track_name = song_name
	else:
		mrf_track_name = "No Signal"

func _play_silver_random():
	silver_playing_intro = false # Intro is over!
	if silver_news.size() > 0:
		var random_index = randi() % silver_news.size()
		var broadcast = silver_news[random_index]
		silver_player.stream = broadcast
		silver_player.play()
		
		var news_name = broadcast.resource_path.get_file().get_basename()
		if news_name == "": news_name = "Silver News " + str(random_index + 1)
		silver_track_name = news_name
	else:
		silver_track_name = "No Signal"

func _play_cosa_random():
	cosa_playing_intro = false # Intro is over!
	if cosa_espanola_songs.size() > 0:
		var random_index = randi() % cosa_espanola_songs.size()
		var song = cosa_espanola_songs[random_index]
		cosa_player.stream = song
		cosa_player.play()
		
		var song_name = song.resource_path.get_file().get_basename()
		if song_name == "": song_name = "Cosa Track " + str(random_index + 1)
		cosa_track_name = song_name
	else:
		cosa_track_name = "No Signal"

func _get_ground_pos(marker_pos: Vector3):
	var space_state = get_world_3d().direct_space_state
	var origin = marker_pos + Vector3(0, 0.5, 0)
	var end = marker_pos - Vector3(0, 1.0, 0)
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [self.get_rid()] 
	var result = space_state.intersect_ray(query)
	if result: return result.position + Vector3(0, 0.02, 0)
	return null

func _spawn_skid_segment(start_pos: Vector3, end_pos: Vector3):
	var distance = start_pos.distance_to(end_pos)
	if distance < 0.01: return
	var mark = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(0.3, distance) 
	mark.mesh = plane
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.05, 0.8) 
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mark.material_override = mat
	get_tree().current_scene.add_child(mark)
	var center_pos = (start_pos + end_pos) / 2.0
	mark.global_position = center_pos
	mark.look_at(end_pos, Vector3.UP)
	var tween = get_tree().create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 3.0).set_delay(1.0)
	tween.tween_callback(mark.queue_free)
