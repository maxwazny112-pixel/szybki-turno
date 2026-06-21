extends CharacterBody3D

@export var police_speech: Array[AudioStream] 

# Drop your Spotted and Escaped MP3s here!
@export var spotted_sound: AudioStream
@export var lost_sound: AudioStream

const STEER_SENSITIVITY = 5.0
const BUST_TIME_LIMIT = 10.0
const ESCAPE_TIME_LIMIT = 30.0 
const ESCAPE_DISTANCE = 150.0 

var original_position: Vector3
var original_rotation: Vector3

var is_chasing = false
var bust_timer = 0.0
var lose_timer = 0.0 
var target_player: Node3D = null

# --- AUDIO & SPEECH LOGIC ---
var speech_timer = 0.0
var speech_audio: AudioStreamPlayer3D
var fx_player: AudioStreamPlayer 

# --- UNSTUCK LOGIC ---
var stuck_timer = 0.0
var is_reversing = false
var reverse_timer = 0.0

@onready var detection_zone = $DetectionZone
@onready var bust_zone = $BustZone
@onready var siren_audio = $SirenAudio

@onready var ray_front = $RayCasts/FrontRay
@onready var ray_left = $RayCasts/LeftRay
@onready var ray_right = $RayCasts/RightRay

var canvas: CanvasLayer
var warning_label: Label
var escape_timer_label: Label
var busted_label: Label
var target_label: Label
var evaded_label: Label
var ui_tween: Tween

func _ready():
	original_position = global_position
	original_rotation = global_rotation
	
	speech_audio = AudioStreamPlayer3D.new()
	speech_audio.unit_size = 50.0 
	speech_audio.max_distance = 800.0 
	add_child(speech_audio)
	
	fx_player = AudioStreamPlayer.new()
	fx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(fx_player)
	
	detection_zone.body_entered.connect(_on_detect_entered)
	detection_zone.body_exited.connect(_on_detect_exited)
	
	if ray_front: ray_front.target_position = Vector3(0, 0, -40)
	if ray_left: ray_left.target_position = Vector3(-15, 0, -30)
	if ray_right: ray_right.target_position = Vector3(15, 0, -30)
	
	_build_ui()

# Safety net: Guarantee the game goes back to normal speed if the police car is deleted
func _exit_tree():
	Engine.time_scale = 1.0

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= 9.8 * delta
		
	if not is_chasing:
		if target_player:
			var horiz_vel = Vector3(target_player.velocity.x, 0, target_player.velocity.z)
			if (horiz_vel.length() * 3.6) >= 150.0:
				_start_chase()
				
		var h_vel = Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, 30.0 * delta)
		velocity.x = h_vel.x
		velocity.z = h_vel.z
		move_and_slide()
		return

	# --- CHASE LOGIC ---
	if target_player == null:
		_end_chase(false)
		return

	# --- POLICE SPEECH LOGIC ---
	speech_timer -= delta
	if speech_timer <= 0.0:
		speech_timer = 5.0 
		if police_speech.size() > 0 and not speech_audio.playing:
			var random_clip = police_speech[randi() % police_speech.size()]
			if random_clip:
				speech_audio.stream = random_clip
				speech_audio.play()

	var target_pos = target_player.global_position
	var distance_to_player = global_position.distance_to(target_pos)
	var horiz_speed = Vector3(velocity.x, 0, velocity.z).length()

	# --- 1. ESCAPE LOGIC (30 SECONDS TO LOSE COPS) ---
	if distance_to_player > ESCAPE_DISTANCE:
		lose_timer += delta
		var time_left = int(ESCAPE_TIME_LIMIT - lose_timer)
		escape_timer_label.text = "LOSE POLICE: %d" % max(0, time_left)
		escape_timer_label.visible = true
		
		if lose_timer >= ESCAPE_TIME_LIMIT:
			escape_timer_label.visible = false
			_end_chase(false) # FALSE means you escaped successfully!
			return
	else:
		lose_timer = 0.0
		escape_timer_label.visible = false

	# --- 2. UNSTUCK & REVERSE ---
	if is_reversing:
		reverse_timer -= delta
		var reverse_dir = global_transform.basis.z 
		var desired_vel = reverse_dir * 15.0 
		
		var h_vel = Vector3(velocity.x, 0, velocity.z).lerp(desired_vel, 3.0 * delta)
		velocity.x = h_vel.x
		velocity.z = h_vel.z
		
		rotation.y -= 1.5 * delta 
		move_and_slide()
		
		if reverse_timer <= 0.0:
			is_reversing = false
		return
		
	if horiz_speed < 3.0 and distance_to_player > 10.0:
		stuck_timer += delta
		if stuck_timer > 1.5:
			is_reversing = true
			reverse_timer = 2.0
			stuck_timer = 0.0
			return
	else:
		stuck_timer = 0.0

	# --- 3. DYNAMIC SPEED (RUBBER-BANDING) ---
	var player_speed = Vector3(target_player.velocity.x, 0, target_player.velocity.z).length()
	var current_speed = player_speed
	
	if distance_to_player > 30.0:
		current_speed += 15.0 
	elif distance_to_player > 15.0:
		current_speed += 5.0
	else:
		current_speed += 2.0 
		
	current_speed = clamp(current_speed, 20.0, 140.0) 

	# --- 4. SMARTER STEERING & AVOIDANCE ---
	target_pos.y = global_position.y

	if distance_to_player > 20.0:
		var avoid_offset = Vector3.ZERO
		if ray_front.is_colliding():
			if ray_left.is_colliding(): avoid_offset += global_transform.basis.x * 20.0
			else: avoid_offset -= global_transform.basis.x * 20.0
		elif ray_left.is_colliding():
			avoid_offset += global_transform.basis.x * 15.0
		elif ray_right.is_colliding():
			avoid_offset -= global_transform.basis.x * 15.0
			
		target_pos += avoid_offset

	if global_position.distance_to(target_pos) > 2.0:
		var target_transform = global_transform.looking_at(target_pos, Vector3.UP)
		var turn_speed = clamp(STEER_SENSITIVITY / (horiz_speed * 0.05 + 1.0), 1.0, 5.0)
		global_transform = global_transform.interpolate_with(target_transform, turn_speed * delta)

	# --- 5. MOVEMENT ---
	var forward_dir = -global_transform.basis.z
	var desired_velocity = forward_dir * current_speed
	
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z).lerp(desired_velocity, 2.5 * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z
	
	move_and_slide()

	# --- 6. BUSTING LOGIC ---
	var is_in_bust_radius = false
	for body in bust_zone.get_overlapping_bodies():
		if body == target_player:
			is_in_bust_radius = true
			break

	if is_in_bust_radius:
		bust_timer += delta
		warning_label.text = "BUSTING: %d%%" % int((bust_timer / BUST_TIME_LIMIT) * 100)
		warning_label.visible = true
		
		if bust_timer >= BUST_TIME_LIMIT:
			_bust_player()
	else:
		bust_timer = max(0.0, bust_timer - (delta * 0.5)) 
		if bust_timer == 0.0:
			warning_label.visible = false
		else:
			warning_label.text = "BUSTING: %d%%" % int((bust_timer / BUST_TIME_LIMIT) * 100)

func _is_player(body) -> bool:
	if body is CharacterBody3D or body is VehicleBody3D: return true
	if "player" in body.name.to_lower() or "car" in body.name.to_lower(): return true
	return false

func _on_detect_entered(body):
	if _is_player(body):
		target_player = body

func _on_detect_exited(body):
	if body == target_player:
		if not is_chasing:
			target_player = null

func _start_chase():
	is_chasing = true
	bust_timer = 0.0
	lose_timer = 0.0
	stuck_timer = 0.0
	is_reversing = false
	speech_timer = 0.0 
	
	if siren_audio.stream and not siren_audio.playing:
		siren_audio.play()
		
	_trigger_spotted_fx()

func _trigger_spotted_fx():
	if spotted_sound:
		fx_player.stream = spotted_sound
		fx_player.play()
		
	target_label.visible = true
	target_label.modulate.a = 1.0
	
	# Trigger 25% Slow-Mo!
	Engine.time_scale = 0.25
	
	# Wait exactly 1 second in REAL time (ignoring the slow-mo time scale)
	await get_tree().create_timer(1.0, true, false, true).timeout
	
	# Snap back to full speed
	Engine.time_scale = 1.0
	
	# Fade out the text
	var t = create_tween()
	t.tween_property(target_label, "modulate:a", 0.0, 1.0)
	t.tween_callback(func(): target_label.visible = false)

func _trigger_evaded_fx():
	if lost_sound:
		fx_player.stream = lost_sound
		fx_player.play()
		
	evaded_label.visible = true
	evaded_label.modulate.a = 1.0
	
	# Trigger 25% Slow-Mo!
	Engine.time_scale = 0.25
	
	# Wait exactly 1 second in REAL time
	await get_tree().create_timer(1.0, true, false, true).timeout
	
	# Snap back to full speed
	Engine.time_scale = 1.0
	
	# Fade out the text
	var t = create_tween()
	t.tween_property(evaded_label, "modulate:a", 0.0, 1.0)
	t.tween_callback(func(): evaded_label.visible = false)

func _bust_player():
	var current_creds = SaveSystem.get_credits()
	var penalty = int(current_creds * 0.10) 
	
	SaveSystem.add_credits(-penalty) 
	_show_busted_text(penalty)
	
	# TRUE means you got busted (no escape sound or slow-mo!)
	_end_chase(true) 

func _end_chase(was_busted: bool):
	is_chasing = false
	bust_timer = 0.0
	lose_timer = 0.0
	warning_label.visible = false
	escape_timer_label.visible = false
	
	# Safety reset on time scale just in case
	Engine.time_scale = 1.0
	
	if siren_audio.playing: siren_audio.stop()
	if speech_audio.playing: speech_audio.stop()
		
	# Play the escape cinematic ONLY if you weren't busted
	if not was_busted:
		_trigger_evaded_fx()
		
	global_position = original_position
	global_rotation = original_rotation
	velocity = Vector3.ZERO
	target_player = null

func _build_ui():
	canvas = CanvasLayer.new()
	canvas.layer = 90
	add_child(canvas)
	
	var sys_font = SystemFont.new()
	sys_font.font_weight = 900
	sys_font.font_italic = true
	
	target_label = Label.new()
	var t_set = LabelSettings.new()
	t_set.font = sys_font
	t_set.font_size = 90
	t_set.font_color = Color(1.0, 0.2, 0.2)
	t_set.outline_color = Color.BLACK
	t_set.outline_size = 12
	t_set.shadow_color = Color(0.0, 0.0, 0.0, 0.8)
	t_set.shadow_offset = Vector2(5, 5)
	target_label.label_settings = t_set
	target_label.text = "POLICE TARGET"
	target_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	target_label.position = Vector2(-400, 150)
	target_label.custom_minimum_size = Vector2(800, 100)
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_label.visible = false
	canvas.add_child(target_label)
	
	# NEW: POLICE EVADED UI LABEL
	evaded_label = Label.new()
	var e_set = LabelSettings.new()
	e_set.font = sys_font
	e_set.font_size = 90
	e_set.font_color = Color(0.2, 0.6, 1.0) # Cool Police Blue!
	e_set.outline_color = Color.BLACK
	e_set.outline_size = 12
	e_set.shadow_color = Color(0.0, 0.0, 0.0, 0.8)
	e_set.shadow_offset = Vector2(5, 5)
	evaded_label.label_settings = e_set
	evaded_label.text = "POLICE EVADED"
	evaded_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	evaded_label.position = Vector2(-400, 150)
	evaded_label.custom_minimum_size = Vector2(800, 100)
	evaded_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	evaded_label.visible = false
	canvas.add_child(evaded_label)
	
	# NEW: ESCAPE TIMER LABEL
	escape_timer_label = Label.new()
	var esc_set = LabelSettings.new()
	esc_set.font = sys_font
	esc_set.font_size = 48
	esc_set.font_color = Color(0.2, 0.6, 1.0) # Matches Evaded Blue
	esc_set.outline_color = Color.BLACK
	esc_set.outline_size = 8
	escape_timer_label.label_settings = esc_set
	escape_timer_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	escape_timer_label.position = Vector2(-200, -260)
	escape_timer_label.custom_minimum_size = Vector2(400, 60)
	escape_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	escape_timer_label.visible = false
	canvas.add_child(escape_timer_label)
	
	warning_label = Label.new()
	var w_set = LabelSettings.new()
	w_set.font = sys_font
	w_set.font_size = 48
	w_set.font_color = Color(1.0, 0.2, 0.2)
	w_set.outline_color = Color.BLACK
	w_set.outline_size = 8
	warning_label.label_settings = w_set
	warning_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	warning_label.position = Vector2(-200, -180)
	warning_label.custom_minimum_size = Vector2(400, 60)
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.visible = false
	canvas.add_child(warning_label)
	
	busted_label = Label.new()
	var b_set = LabelSettings.new()
	b_set.font = sys_font
	b_set.font_size = 120
	b_set.font_color = Color(0.8, 0.0, 0.0)
	b_set.outline_color = Color.BLACK
	b_set.outline_size = 15
	busted_label.label_settings = b_set
	busted_label.set_anchors_preset(Control.PRESET_CENTER)
	busted_label.position = Vector2(-400, -150)
	busted_label.custom_minimum_size = Vector2(800, 200)
	busted_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	busted_label.visible = false
	canvas.add_child(busted_label)

func _show_busted_text(penalty: int):
	busted_label.text = "BUSTED!\n-%d CR" % penalty
	busted_label.visible = true
	
	if ui_tween: ui_tween.kill()
	ui_tween = create_tween()
	ui_tween.tween_property(busted_label, "scale", Vector2(1.2, 1.2), 0.1)
	ui_tween.tween_property(busted_label, "scale", Vector2(1.0, 1.0), 0.3)
	ui_tween.tween_interval(3.0)
	ui_tween.tween_callback(func(): busted_label.visible = false)
