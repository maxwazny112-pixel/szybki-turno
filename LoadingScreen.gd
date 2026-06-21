extends Node

@export var logo_sound: AudioStream 
@export var age_sound: AudioStream 
@export var ambient_sound: AudioStream 

@export var credit_line_1: String = "LEAD DEVELOPER"
@export var credit_line_2: String = "Maksymilian"
@export var credit_line_3: String = " " 
@export var credit_line_4: String = "PROGRAMMING & DESIGN"
@export var credit_line_5: String = "Maksymilian"
@export var credit_line_6: String = " "
@export var credit_line_7: String = "AUDIO & MUSIC"
@export var credit_line_8: String = "MRF Radio & Silver Radio"
@export var credit_line_9: String = " "
@export var credit_line_10: String = "SPECIAL THANKS TO ADAM"

var logo_player: AudioStreamPlayer
var age_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer

var bg: ColorRect
var studio_container: Control
var age_container: Control
var credits_container: VBoxContainer
var skip_button: Button

var main_tween: Tween

# --- HARDWARE CONTROLLER TRACKING ---
var was_joy_a_pressed = false

func _ready():
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	logo_player = AudioStreamPlayer.new()
	logo_player.process_mode = Node.PROCESS_MODE_ALWAYS 
	add_child(logo_player)
	if logo_sound: logo_player.stream = logo_sound
		
	age_player = AudioStreamPlayer.new()
	age_player.process_mode = Node.PROCESS_MODE_ALWAYS 
	add_child(age_player)
	if age_sound: age_player.stream = age_sound
		
	ambient_player = AudioStreamPlayer.new()
	ambient_player.process_mode = Node.PROCESS_MODE_ALWAYS 
	add_child(ambient_player)
	if ambient_sound: 
		ambient_player.stream = ambient_sound
		ambient_player.play()

	var canvas = CanvasLayer.new()
	canvas.layer = 100 
	add_child(canvas)
	
	bg = ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)
	
	var sys_font = SystemFont.new()
	sys_font.font_weight = 900 
	
	# --- SCREEN 1: MWW STUDIOS LOGO ---
	studio_container = Control.new()
	studio_container.set_anchors_preset(Control.PRESET_CENTER)
	studio_container.modulate.a = 0 
	canvas.add_child(studio_container)
	
	var red_square = ColorRect.new()
	red_square.color = Color(0.5, 0.0, 0.0) 
	red_square.size = Vector2(160, 160)
	red_square.position = Vector2(-80, -120) 
	studio_container.add_child(red_square)
	
	var m_label = Label.new()
	m_label.text = "M"
	var m_settings = LabelSettings.new()
	m_settings.font = sys_font
	m_settings.font_size = 130
	m_settings.font_color = Color.WHITE
	m_label.label_settings = m_settings
	m_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	m_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	m_label.position.y = -10 
	red_square.add_child(m_label)
	
	var text_label = Label.new()
	text_label.text = "MWW Studios"
	var text_settings = LabelSettings.new()
	text_settings.font = sys_font
	text_settings.font_size = 48
	text_settings.font_color = Color.WHITE
	text_label.label_settings = text_settings
	text_label.custom_minimum_size = Vector2(400, 60)
	text_label.position = Vector2(-200, 60) 
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	studio_container.add_child(text_label)

	# --- SCREEN 2: AGE RATING ---
	age_container = Control.new()
	age_container.set_anchors_preset(Control.PRESET_CENTER)
	age_container.modulate.a = 0 
	canvas.add_child(age_container)
	
	var circle = Panel.new()
	var circle_style = StyleBoxFlat.new()
	circle_style.bg_color = Color(0.8, 0.0, 0.0) 
	circle_style.border_color = Color.WHITE
	circle_style.border_width_top = 6
	circle_style.border_width_bottom = 6
	circle_style.border_width_left = 6
	circle_style.border_width_right = 6
	circle_style.corner_radius_top_left = 100
	circle_style.corner_radius_top_right = 100
	circle_style.corner_radius_bottom_left = 100
	circle_style.corner_radius_bottom_right = 100
	circle.add_theme_stylebox_override("panel", circle_style)
	circle.size = Vector2(140, 140)
	circle.position = Vector2(-280, -70) 
	age_container.add_child(circle)
	
	var age_label = Label.new()
	age_label.text = "18+"
	var age_settings = LabelSettings.new()
	age_settings.font = sys_font
	age_settings.font_size = 54
	age_settings.font_color = Color.WHITE
	age_label.label_settings = age_settings
	age_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	age_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	age_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	circle.add_child(age_label)
	
	var warning_label = Label.new()
	warning_label.text = "Moderate Language\nSwearing\nReckless Driving"
	var warning_settings = LabelSettings.new()
	warning_settings.font = sys_font
	warning_settings.font_size = 38
	warning_settings.font_color = Color.WHITE
	warning_label.label_settings = warning_settings
	warning_label.position = Vector2(-100, -70) 
	age_container.add_child(warning_label)

	# --- SCREEN 3: CREDITS & SKIP BUTTON ---
	credits_container = VBoxContainer.new()
	credits_container.set_anchors_preset(Control.PRESET_CENTER)
	credits_container.modulate.a = 0 
	credits_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	credits_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	canvas.add_child(credits_container)
	
	var lines = [
		credit_line_1, credit_line_2, credit_line_3, credit_line_4, credit_line_5, 
		credit_line_6, credit_line_7, credit_line_8, credit_line_9, credit_line_10
	]
	
	for i in range(lines.size()):
		var c_label = Label.new()
		c_label.text = lines[i]
		var c_set = LabelSettings.new()
		c_set.font = sys_font
		c_set.font_size = 36
		if i % 2 == 0: c_set.font_color = Color(1.0, 0.8, 0.0) 
		else: c_set.font_color = Color.WHITE
		c_label.label_settings = c_set
		c_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c_label.custom_minimum_size = Vector2(0, 45) 
		credits_container.add_child(c_label)

	skip_button = Button.new()
	skip_button.text = "SKIP CREDITS >>"
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	btn_style.border_color = Color(0.15, 0.35, 0.8)
	btn_style.border_width_bottom = 4
	btn_style.border_width_top = 4
	btn_style.skew = Vector2(0.3, 0.0)
	skip_button.add_theme_stylebox_override("normal", btn_style)
	skip_button.add_theme_stylebox_override("hover", btn_style)
	skip_button.add_theme_font_override("font", sys_font)
	skip_button.add_theme_font_size_override("font_size", 28)
	skip_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_button.offset_left = -300
	skip_button.offset_top = -80
	skip_button.offset_right = -30
	skip_button.offset_bottom = -20
	skip_button.visible = false
	skip_button.pressed.connect(_on_skip_pressed)
	canvas.add_child(skip_button)

	_play_intro_sequence()

# --- HARDWARE CONTROLLER MOUSE SIMULATION ---
func _process(delta):
	var joy_x = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var joy_y = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	
	if abs(joy_x) > 0.15 or abs(joy_y) > 0.15:
		var current_mouse = get_viewport().get_mouse_position()
		var new_mouse = current_mouse + Vector2(joy_x, joy_y) * 1200.0 * delta
		
		var rect = get_viewport().get_visible_rect().size
		new_mouse.x = clamp(new_mouse.x, 0, rect.x)
		new_mouse.y = clamp(new_mouse.y, 0, rect.y)
		
		get_viewport().warp_mouse(new_mouse)
		
	var is_a_pressed = Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	if is_a_pressed and not was_joy_a_pressed:
		_inject_mouse_click(true)
	elif not is_a_pressed and was_joy_a_pressed:
		_inject_mouse_click(false)
		
	was_joy_a_pressed = is_a_pressed

func _inject_mouse_click(pressed: bool):
	var ev = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.global_position = get_viewport().get_mouse_position()
	Input.parse_input_event(ev)

func _play_intro_sequence():
	main_tween = create_tween()
	main_tween.tween_interval(1.5) 
	main_tween.tween_property(studio_container, "modulate:a", 1.0, 1.0) 
	main_tween.tween_callback(_play_logo_sound)
	main_tween.tween_interval(2.0) 
	main_tween.tween_property(studio_container, "modulate:a", 0.0, 1.0) 
	
	main_tween.tween_property(age_container, "modulate:a", 1.0, 1.0) 
	main_tween.tween_callback(_play_age_sound)
	main_tween.tween_interval(2.5) 
	main_tween.tween_property(age_container, "modulate:a", 0.0, 1.0) 
	
	main_tween.tween_callback(func(): skip_button.visible = true)
	main_tween.tween_property(credits_container, "modulate:a", 1.0, 1.0)
	main_tween.tween_interval(4.0) 
	main_tween.tween_property(credits_container, "modulate:a", 0.0, 1.0) 
	main_tween.tween_callback(_finish_loading_screen)

func _on_skip_pressed():
	if main_tween: main_tween.kill()
	_finish_loading_screen()

func _finish_loading_screen():
	skip_button.visible = false
	var end_tween = create_tween()
	end_tween.tween_property(bg, "modulate:a", 0.0, 1.0) 
	var audio_tween = create_tween()
	audio_tween.tween_property(ambient_player, "volume_db", -60.0, 1.0)
	end_tween.tween_callback(self.queue_free)

func _play_logo_sound():
	if logo_player.stream: logo_player.play()

func _play_age_sound():
	if age_player.stream: age_player.play()
