extends Node

@export var player_car: CharacterBody3D 

@export var time_3_star: float = 60.0 
@export var time_2_star: float = 80.0
@export var time_1_star: float = 110.0

@export var countdown_beep: AudioStream
@export var go_sound: AudioStream

var audio_player: AudioStreamPlayer
var start_line: Area3D
var finish_line: Area3D
var banners: Node

var is_racing = false
var is_counting_down = false
var player_in_start_zone = false
var elapsed_time = 0.0

var canvas: CanvasLayer
var prompt_ui: Control
var info_ui: Control
var hud_ui: Control
var end_ui: Control
var big_text: Label
var hud_time: Label

func _ready():
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("race_systems")
	
	audio_player = AudioStreamPlayer.new()
	audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(audio_player)

	start_line = get_node_or_null("StartLine")
	finish_line = get_node_or_null("FinishLine")
	banners = get_node_or_null("Banners")
	
	if banners: banners.visible = false
		
	if start_line:
		start_line.monitoring = true
		for layer in range(1, 10):
			start_line.set_collision_mask_value(layer, true)
			start_line.set_collision_layer_value(layer, true)
		start_line.body_entered.connect(_on_start_entered)
		start_line.body_exited.connect(_on_start_exited)
		
	if finish_line:
		finish_line.monitoring = true
		for layer in range(1, 10):
			finish_line.set_collision_mask_value(layer, true)
			finish_line.set_collision_layer_value(layer, true)
		finish_line.body_entered.connect(_on_finish_entered)
	
	_build_ui()

func _is_player(body) -> bool:
	if body is CharacterBody3D or body is VehicleBody3D: return true
	if "player" in body.name.to_lower() or "car" in body.name.to_lower(): return true
	return false

func _is_any_race_active() -> bool:
	for race in get_tree().get_nodes_in_group("race_systems"):
		if race.is_racing or race.is_counting_down:
			return true
	return false

func _process(delta):
	var active_player = get_tree().current_scene.get_node_or_null("PlayerCar")
	if player_car: active_player = player_car 
	
	if is_racing:
		elapsed_time += delta
		hud_time.text = _format_time(elapsed_time)
		
		if finish_line and active_player:
			for body in finish_line.get_overlapping_bodies():
				if _is_player(body):
					_finish_race()
					return
			if active_player.global_position.distance_to(finish_line.global_position) < 35.0:
				_finish_race()
		return

	if _is_any_race_active():
		prompt_ui.visible = false
		info_ui.visible = false
		return

	player_in_start_zone = false
	if start_line and active_player:
		if active_player.global_position.distance_to(start_line.global_position) < 25.0:
			player_in_start_zone = true
		for body in start_line.get_overlapping_bodies():
			if _is_player(body):
				player_in_start_zone = true

	if is_counting_down or end_ui.visible:
		prompt_ui.visible = false
		info_ui.visible = false
		return

	if info_ui.visible:
		prompt_ui.visible = false
		if not player_in_start_zone:
			info_ui.visible = false
			
		if Input.is_action_just_pressed("interact_race"):
			info_ui.visible = false
			_start_countdown()
			
	elif player_in_start_zone:
		prompt_ui.visible = true
		if Input.is_action_just_pressed("interact_race"):
			prompt_ui.visible = false
			info_ui.visible = true
	else:
		prompt_ui.visible = false
		info_ui.visible = false

func _on_start_entered(body):
	if _is_player(body): player_in_start_zone = true

func _on_start_exited(body):
	if _is_player(body): player_in_start_zone = false

func _on_finish_entered(body):
	if is_racing and _is_player(body):
		_finish_race()

func _start_countdown():
	is_counting_down = true
	get_tree().paused = true 
	big_text.visible = true
	if banners: banners.visible = true
	
	var tween = create_tween()
	
	for i in range(3, 0, -1):
		tween.tween_callback(func(): 
			big_text.text = str(i)
			if countdown_beep: 
				audio_player.stream = countdown_beep
				audio_player.play()
		)
		tween.tween_property(big_text, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(big_text, "scale", Vector2(1.0, 1.0), 0.9)
		
	tween.tween_callback(func():
		big_text.text = "GO!"
		big_text.label_settings.font_color = Color(0.15, 0.8, 0.2) 
		if go_sound: 
			audio_player.stream = go_sound
			audio_player.play()
		
		is_counting_down = false
		is_racing = true
		get_tree().paused = false
		elapsed_time = 0.0
		hud_ui.visible = true
	)
	
	tween.tween_property(big_text, "scale", Vector2(2.0, 2.0), 1.0)
	tween.tween_callback(func(): big_text.visible = false)

func _finish_race():
	is_racing = false
	hud_ui.visible = false
	if banners: banners.visible = false
	
	var stars = 0
	var reward = 0
	
	if elapsed_time <= time_3_star: 
		stars = 3
		reward = 100
	elif elapsed_time <= time_2_star: 
		stars = 2
		reward = 50
	elif elapsed_time <= time_1_star: 
		stars = 1
		reward = 25
	
	# Process Economy (No repeat penalties for races!)
	SaveSystem.add_credits(reward)
	SaveSystem.save_race(self.name, elapsed_time, stars)
	
	var m = floori(elapsed_time / 60.0)
	var s = floori(fmod(elapsed_time, 60.0))
	
	end_ui.get_node("TimeBox").text = "Time: %02d:%02d" % [m, s]
	var star_label = end_ui.get_node("Stars")
	
	if stars == 3: 
		star_label.text = "★★★"
		star_label.label_settings.font_color = Color(1.0, 0.8, 0.0)
	elif stars == 2: 
		star_label.text = "★★☆"
		star_label.label_settings.font_color = Color(0.8, 0.8, 0.8)
	elif stars == 1: 
		star_label.text = "★☆☆"
		star_label.label_settings.font_color = Color(0.8, 0.4, 0.2)
	else: 
		star_label.text = "☆☆☆"
		star_label.label_settings.font_color = Color(0.3, 0.3, 0.3)
		
	end_ui.visible = true
	
	await get_tree().create_timer(4.0).timeout
	end_ui.visible = false
	big_text.label_settings.font_color = Color(1.0, 0.8, 0.0)

func _format_time(time: float) -> String:
	var m = floori(time / 60.0)
	var s = floori(fmod(time, 60.0))
	return "%02d:%02d" % [m, s]

func _build_ui():
	canvas = CanvasLayer.new()
	add_child(canvas)
	
	var sys_font = SystemFont.new()
	sys_font.font_weight = 900
	sys_font.font_italic = true
	
	prompt_ui = Control.new()
	prompt_ui.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_ui.position.y = -100
	prompt_ui.visible = false
	canvas.add_child(prompt_ui)
	
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1, 0.9)
	bg.position = Vector2(-220, -30)
	bg.size = Vector2(440, 60)
	prompt_ui.add_child(bg)
	
	var lbl = Label.new()
	lbl.text = "PRESS [ENTER / D-PAD RIGHT] TO VIEW RACE"
	var lbl_set = LabelSettings.new()
	lbl_set.font = sys_font
	lbl_set.font_size = 20
	lbl_set.font_color = Color(1.0, 0.8, 0.0)
	lbl.label_settings = lbl_set
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.position = Vector2(-200, -15)
	prompt_ui.add_child(lbl)
	
	info_ui = Control.new()
	info_ui.set_anchors_preset(Control.PRESET_CENTER)
	info_ui.visible = false
	canvas.add_child(info_ui)
	
	var info_bg = Polygon2D.new()
	info_bg.color = Color(0.1, 0.1, 0.1, 0.95)
	info_bg.polygon = PackedVector2Array([Vector2(30, 0), Vector2(430, 0), Vector2(400, 300), Vector2(0, 300)])
	info_bg.position = Vector2(-215, -150)
	info_ui.add_child(info_bg)
	
	var title = Label.new()
	title.text = "SPRINT RACE"
	title.label_settings = lbl_set.duplicate()
	title.label_settings.font_size = 36
	title.position = Vector2(-110, -130)
	info_ui.add_child(title)
	
	var details = Label.new()
	details.text = "POINT A TO POINT B\n\n★★★ : %s\n★★☆ : %s\n★☆☆ : %s\n\nPRESS ENTER TO START" % [
		_format_time(time_3_star), _format_time(time_2_star), _format_time(time_1_star)
	]
	var det_set = LabelSettings.new()
	det_set.font = sys_font
	det_set.font_size = 24
	details.label_settings = det_set
	details.position = Vector2(-110, -60)
	info_ui.add_child(details)

	big_text = Label.new()
	var big_set = LabelSettings.new()
	big_set.font = sys_font
	big_set.font_size = 180
	big_set.font_color = Color(1.0, 0.8, 0.0)
	big_set.outline_color = Color.BLACK
	big_set.outline_size = 15
	big_text.label_settings = big_set
	big_text.set_anchors_preset(Control.PRESET_CENTER)
	big_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big_text.position = Vector2(-150, -100)
	big_text.custom_minimum_size = Vector2(300, 200)
	big_text.pivot_offset = Vector2(150, 100)
	big_text.visible = false
	canvas.add_child(big_text)

	hud_ui = Control.new()
	hud_ui.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hud_ui.visible = false
	canvas.add_child(hud_ui)
	
	var hud_bg2 = ColorRect.new()
	hud_bg2.color = Color(0.1, 0.1, 0.1, 0.8)
	hud_bg2.position = Vector2(-120, 20)
	hud_bg2.size = Vector2(240, 60)
	hud_ui.add_child(hud_bg2)
	
	hud_time = Label.new()
	hud_time.label_settings = big_set.duplicate()
	hud_time.label_settings.font_size = 42
	hud_time.position = Vector2(-100, 25)
	hud_time.custom_minimum_size = Vector2(200, 50)
	hud_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_ui.add_child(hud_time)
	
	end_ui = Control.new()
	end_ui.set_anchors_preset(Control.PRESET_CENTER)
	end_ui.visible = false
	canvas.add_child(end_ui)
	
	var end_bg = info_bg.duplicate()
	end_ui.add_child(end_bg)
	
	var end_title = Label.new()
	end_title.text = "FINISH!"
	end_title.label_settings = big_set.duplicate()
	end_title.label_settings.font_size = 64
	end_title.position = Vector2(-120, -120)
	end_ui.add_child(end_title)
	
	var end_time = Label.new()
	end_time.name = "TimeBox"
	end_time.label_settings = det_set.duplicate()
	end_time.label_settings.font_size = 32
	end_time.position = Vector2(-100, -30)
	end_ui.add_child(end_time)
	
	var end_stars = Label.new()
	end_stars.name = "Stars"
	end_stars.label_settings = big_set.duplicate()
	end_stars.label_settings.font_size = 54
	end_stars.position = Vector2(-100, 30)
	end_ui.add_child(end_stars)
