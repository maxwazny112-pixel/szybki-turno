extends Node

@export var click_sound: AudioStream
@export var begin_sound: AudioStream 

var click_player: AudioStreamPlayer
var begin_player: AudioStreamPlayer

var is_mph = false
var graphics_level = 2 
var is_retro = false

var main_canvas: CanvasLayer
var retro_canvas: CanvasLayer
var retro_rect: ColorRect

var center_container: CenterContainer
var main_panel: VBoxContainer
var settings_panel: VBoxContainer
var account_panel: VBoxContainer
var login_panel: VBoxContainer
var create_panel: VBoxContainer
var tuning_panel: VBoxContainer

var btn_begin: Button
var btn_graphics: Button
var btn_speed: Button
var btn_retro: Button
var btn_account_main: Button

var log_user: LineEdit
var log_pass: LineEdit
var cre_user: LineEdit
var cre_pass: LineEdit
var cre_gender: OptionButton
var status_label: Label

var tune_lbl_credits: Label
var btn_tune_speed: Button
var btn_tune_handling: Button
var btn_tune_drift: Button
var btn_tune_bonus: Button

# --- HARDWARE CONTROLLER TRACKING ---
var was_joy_a_pressed = false
var was_joy_start_pressed = false

func _ready():
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	click_player = AudioStreamPlayer.new()
	click_player.process_mode = Node.PROCESS_MODE_ALWAYS 
	add_child(click_player)
	if click_sound: click_player.stream = click_sound
		
	begin_player = AudioStreamPlayer.new()
	begin_player.process_mode = Node.PROCESS_MODE_ALWAYS 
	add_child(begin_player)
	if begin_sound: begin_player.stream = begin_sound
	
	retro_canvas = CanvasLayer.new()
	retro_canvas.layer = -1 
	add_child(retro_canvas)
	
	retro_rect = ColorRect.new()
	retro_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var r_mat = ShaderMaterial.new()
	var r_sh = Shader.new()
	r_sh.code = "shader_type canvas_item; uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest; void fragment() { vec2 grid = vec2(320.0, 180.0); vec2 uv = floor(SCREEN_UV * grid) / grid; COLOR = texture(screen_texture, uv); }"
	r_mat.shader = r_sh
	retro_rect.material = r_mat
	retro_rect.visible = false
	retro_canvas.add_child(retro_rect)
	
	main_canvas = CanvasLayer.new()
	main_canvas.layer = 50
	add_child(main_canvas)
	
	var blur_bg = ColorRect.new()
	blur_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var blur_shader = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = "shader_type canvas_item; uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest; void fragment() { vec4 color = textureLod(screen_texture, SCREEN_UV, 3.5); COLOR = color * vec4(0.4, 0.4, 0.4, 1.0); }"
	blur_shader.shader = shader
	blur_bg.material = blur_shader
	main_canvas.add_child(blur_bg)
	
	var sys_font = SystemFont.new()
	sys_font.font_weight = 900
	sys_font.font_italic = true
	
	var title = Label.new()
	title.text = "Szybki Turno"
	var title_settings = LabelSettings.new()
	title_settings.font = sys_font
	title_settings.font_size = 110
	title_settings.font_color = Color(1.0, 0.8, 0.0) 
	title_settings.outline_color = Color.BLACK
	title_settings.outline_size = 15
	title_settings.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
	title_settings.shadow_offset = Vector2(8, 8)
	title.label_settings = title_settings
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 20 
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_canvas.add_child(title)
	
	center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.offset_top = 100 
	main_canvas.add_child(center_container)
	
	_build_panels()
	_update_account_button()

# --- HARDWARE CONTROLLER POLLING & PAUSE SYSTEM ---
func _process(delta):
	# Joypad Button 6 is exactly the Start / Options / 3-Lines button
	var is_start_pressed = Input.is_joy_button_pressed(0, JOY_BUTTON_START)
	var start_just_pressed = is_start_pressed and not was_joy_start_pressed
	was_joy_start_pressed = is_start_pressed

	if (Input.is_action_just_pressed("ui_cancel") or start_just_pressed) and not main_canvas.visible:
		get_tree().paused = true
		main_canvas.visible = true
		btn_begin.text = "RESUME"
		_show_main()
		_update_tuning_ui() 

	# If the Menu is visible, simulate the mouse!
	if main_canvas.visible:
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

func _build_panels():
	main_panel = VBoxContainer.new()
	main_panel.add_theme_constant_override("separation", 20)
	center_container.add_child(main_panel)
	
	btn_begin = _create_button("BEGIN", main_panel, _on_begin_pressed)
	_create_button("TUNING SHOP", main_panel, _on_tuning_opened)
	btn_account_main = _create_button("ACCOUNT: GUEST", main_panel, _on_account_opened)
	_create_button("SETTINGS", main_panel, _on_settings_opened)
	_create_button("EXIT", main_panel, _on_exit_pressed)
	
	settings_panel = VBoxContainer.new()
	settings_panel.add_theme_constant_override("separation", 20)
	settings_panel.visible = false
	center_container.add_child(settings_panel)
	
	btn_graphics = _create_button("Graphics: High", settings_panel, _on_graphics_pressed)
	btn_speed = _create_button("Speed: KMH", settings_panel, _on_speed_pressed)
	btn_retro = _create_button("Retro Style: OFF", settings_panel, _on_retro_pressed)
	_create_button("BACK", settings_panel, _show_main)

	tuning_panel = VBoxContainer.new()
	tuning_panel.add_theme_constant_override("separation", 15)
	tuning_panel.visible = false
	center_container.add_child(tuning_panel)
	
	tune_lbl_credits = Label.new()
	tune_lbl_credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cred_set = LabelSettings.new()
	cred_set.font = SystemFont.new()
	cred_set.font_size = 36
	cred_set.font_color = Color(1.0, 0.8, 0.0)
	tune_lbl_credits.label_settings = cred_set
	tuning_panel.add_child(tune_lbl_credits)
	
	btn_tune_speed = _create_button("Speed", tuning_panel, _on_tune_pressed.bind("speed"))
	btn_tune_handling = _create_button("Handling", tuning_panel, _on_tune_pressed.bind("handling"))
	btn_tune_drift = _create_button("Drift", tuning_panel, _on_tune_pressed.bind("drift"))
	btn_tune_bonus = _create_button("Race Bonus", tuning_panel, _on_tune_pressed.bind("bonus"))
	_create_button("BACK", tuning_panel, _show_main)
	_update_tuning_ui()

	account_panel = VBoxContainer.new()
	account_panel.add_theme_constant_override("separation", 20)
	account_panel.visible = false
	center_container.add_child(account_panel)
	
	_create_button("LOGIN", account_panel, _on_login_menu_opened)
	_create_button("CREATE ACCOUNT", account_panel, _on_create_menu_opened)
	_create_button("LOGOUT", account_panel, _on_logout_pressed)
	_create_button("BACK", account_panel, _show_main)
	
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stat_set = LabelSettings.new()
	stat_set.font = SystemFont.new()
	stat_set.font_size = 24
	stat_set.font_color = Color(1.0, 0.2, 0.2)
	status_label.label_settings = stat_set
	
	login_panel = VBoxContainer.new()
	login_panel.add_theme_constant_override("separation", 20)
	login_panel.visible = false
	center_container.add_child(login_panel)
	
	log_user = _create_line_edit("Username", login_panel, false)
	log_pass = _create_line_edit("Password", login_panel, true)
	_create_button("SUBMIT", login_panel, _on_login_submit)
	_create_button("BACK", login_panel, _on_account_opened)

	create_panel = VBoxContainer.new()
	create_panel.add_theme_constant_override("separation", 20)
	create_panel.visible = false
	center_container.add_child(create_panel)
	
	cre_user = _create_line_edit("New Username", create_panel, false)
	cre_pass = _create_line_edit("New Password", create_panel, true)
	
	cre_gender = OptionButton.new()
	cre_gender.custom_minimum_size = Vector2(400, 60)
	cre_gender.add_theme_font_size_override("font_size", 28)
	cre_gender.add_item("Male")
	cre_gender.add_item("Female")
	create_panel.add_child(cre_gender)
	
	_create_button("SUBMIT", create_panel, _on_create_submit)
	_create_button("BACK", create_panel, _on_account_opened)

func _create_button(text: String, parent: Node, callable: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(400, 70)
	var sys_font = SystemFont.new()
	sys_font.font_weight = 900
	sys_font.font_italic = true
	btn.add_theme_font_override("font", sys_font)
	btn.add_theme_font_size_override("font_size", 28) 
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	normal_style.border_color = Color(0.15, 0.35, 0.8) 
	normal_style.border_width_bottom = 5
	normal_style.border_width_top = 5
	normal_style.skew = Vector2(0.3, 0.0) 
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(1.0, 0.8, 0.0) 
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", normal_style)
	btn.add_theme_stylebox_override("focus", normal_style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.BLACK)
	btn.pressed.connect(callable)
	parent.add_child(btn)
	return btn

func _create_line_edit(placeholder: String, parent: Node, is_password: bool) -> LineEdit:
	var le = LineEdit.new()
	le.placeholder_text = placeholder
	le.secret = is_password
	le.custom_minimum_size = Vector2(400, 60)
	le.add_theme_font_size_override("font_size", 28)
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.9)
	style.border_color = Color(0.5, 0.5, 0.5)
	style.border_width_bottom = 3
	le.add_theme_stylebox_override("normal", style)
	parent.add_child(le)
	return le

func _hide_all():
	main_panel.visible = false
	settings_panel.visible = false
	account_panel.visible = false
	login_panel.visible = false
	create_panel.visible = false
	tuning_panel.visible = false
	if status_label.get_parent(): status_label.get_parent().remove_child(status_label)

func _show_main():
	_play_click()
	_hide_all()
	_update_account_button()
	main_panel.visible = true

func _on_settings_opened():
	_play_click()
	_hide_all()
	settings_panel.visible = true

func _on_tuning_opened():
	_play_click()
	_hide_all()
	_update_tuning_ui()
	tuning_panel.visible = true

func _on_account_opened():
	_play_click()
	_hide_all()
	account_panel.add_child(status_label)
	status_label.text = ""
	account_panel.visible = true

func _on_login_menu_opened():
	_play_click()
	_hide_all()
	login_panel.add_child(status_label)
	status_label.text = ""
	login_panel.visible = true

func _on_create_menu_opened():
	_play_click()
	_hide_all()
	create_panel.add_child(status_label)
	status_label.text = ""
	create_panel.visible = true

func _update_account_button():
	if SaveSystem.current_user != "":
		btn_account_main.text = "ACCOUNT: " + SaveSystem.current_user.to_upper()
	else:
		btn_account_main.text = "ACCOUNT: GUEST"

func _update_tuning_ui():
	if SaveSystem.current_user == "":
		tune_lbl_credits.text = "LOG IN TO TUNE CAR"
		btn_tune_speed.disabled = true; btn_tune_speed.text = "Speed [LOCKED]"
		btn_tune_handling.disabled = true; btn_tune_handling.text = "Handling [LOCKED]"
		btn_tune_drift.disabled = true; btn_tune_drift.text = "Drift [LOCKED]"
		btn_tune_bonus.disabled = true; btn_tune_bonus.text = "Race Bonus [LOCKED]"
		return
		
	btn_tune_speed.disabled = false
	btn_tune_handling.disabled = false
	btn_tune_drift.disabled = false
	btn_tune_bonus.disabled = false
	
	var creds = SaveSystem.get_credits()
	tune_lbl_credits.text = "WALLET: " + str(creds) + " CR"
	
	var spd_lvl = SaveSystem.get_tune_level("speed")
	if spd_lvl < 10:
		var cost = (spd_lvl + 1) * 500
		btn_tune_speed.text = "Speed Lvl %d -> %d [%d CR]\nMax: %d KMH" % [spd_lvl, spd_lvl+1, cost, 200 + ((spd_lvl+1) * 30)]
	else: btn_tune_speed.text = "Speed Lvl 10 [MAXED]\nMax: 500 KMH"; btn_tune_speed.disabled = true

	var hnd_lvl = SaveSystem.get_tune_level("handling")
	if hnd_lvl < 10:
		var cost = (hnd_lvl + 1) * 500
		btn_tune_handling.text = "Handling Lvl %d -> %d [%d CR]" % [hnd_lvl, hnd_lvl+1, cost]
	else: btn_tune_handling.text = "Handling Lvl 10 [MAXED]"; btn_tune_handling.disabled = true

	var drf_lvl = SaveSystem.get_tune_level("drift")
	if drf_lvl < 10:
		var cost = (drf_lvl + 1) * 500
		btn_tune_drift.text = "Drift Lvl %d -> %d [%d CR]" % [drf_lvl, drf_lvl+1, cost]
	else: btn_tune_drift.text = "Drift Lvl 10 [MAXED]"; btn_tune_drift.disabled = true
	
	var bon_lvl = SaveSystem.get_tune_level("bonus")
	if bon_lvl < 10:
		var cost = (bon_lvl + 1) * 500
		btn_tune_bonus.text = "Race Bonus Lvl %d -> %d [%d CR]\n+%d%% Payout" % [bon_lvl, bon_lvl+1, cost, (bon_lvl+1) * 10]
	else: btn_tune_bonus.text = "Race Bonus Lvl 10 [MAXED]\n+100% Payout"; btn_tune_bonus.disabled = true

func _on_tune_pressed(type: String):
	var lvl = SaveSystem.get_tune_level(type)
	if lvl < 10:
		var cost = (lvl + 1) * 500
		if SaveSystem.purchase_tune(type, cost):
			_play_click()
			_update_tuning_ui()
		else:
			pass 

func _load_user_settings():
	var settings = SaveSystem.get_settings()
	is_mph = settings.is_mph
	graphics_level = settings.graphics
	is_retro = settings.retro
	
	btn_speed.text = "Speed: MPH" if is_mph else "Speed: KMH"
	btn_retro.text = "Retro Style: ON" if is_retro else "Retro Style: OFF"
	retro_rect.visible = is_retro
	
	var text = "Low"
	if graphics_level == 1: text = "Medium"
	elif graphics_level == 2: text = "High"
	btn_graphics.text = "Graphics: " + text
	
	_apply_graphics()
	var car = get_tree().current_scene.get_node_or_null("PlayerCar")
	if car and car.has_method("change_speed_unit"):
		car.change_speed_unit(is_mph)

func _on_login_submit():
	_play_click()
	var msg = SaveSystem.login(log_user.text, log_pass.text)
	status_label.text = msg
	if msg == "LOGIN SUCCESSFUL!":
		status_label.label_settings.font_color = Color(0.2, 1.0, 0.2)
		_load_user_settings() 
		await get_tree().create_timer(1.0).timeout
		_show_main()
	else:
		status_label.label_settings.font_color = Color(1.0, 0.2, 0.2)

func _on_create_submit():
	_play_click()
	var gender = "Male" if cre_gender.selected == 0 else "Female"
	var msg = SaveSystem.create_account(cre_user.text, cre_pass.text, gender)
	status_label.text = msg
	if msg == "ACCOUNT CREATED!":
		status_label.label_settings.font_color = Color(0.2, 1.0, 0.2)
		_load_user_settings()
		await get_tree().create_timer(1.0).timeout
		_show_main()
	else:
		status_label.label_settings.font_color = Color(1.0, 0.2, 0.2)

func _on_logout_pressed():
	_play_click()
	SaveSystem.logout()
	status_label.text = "LOGGED OUT."
	status_label.label_settings.font_color = Color(0.8, 0.8, 0.8)

func _play_click():
	if click_player.stream: click_player.play(0.0) 
		
func _play_begin_sound():
	if begin_player.stream: begin_player.play(0.0)

func _on_begin_pressed():
	_play_begin_sound()
	await get_tree().create_timer(0.4).timeout 
	get_tree().paused = false
	main_canvas.visible = false

func _on_exit_pressed():
	_play_click()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func _on_speed_pressed():
	_play_click()
	is_mph = !is_mph
	btn_speed.text = "Speed: MPH" if is_mph else "Speed: KMH"
	SaveSystem.save_settings(is_mph, graphics_level, is_retro) 
	
	var car = get_tree().current_scene.get_node_or_null("PlayerCar")
	if car and car.has_method("change_speed_unit"): car.change_speed_unit(is_mph)

func _on_retro_pressed():
	_play_click()
	is_retro = !is_retro
	btn_retro.text = "Retro Style: ON" if is_retro else "Retro Style: OFF"
	retro_rect.visible = is_retro
	SaveSystem.save_settings(is_mph, graphics_level, is_retro)

func _on_graphics_pressed():
	_play_click()
	graphics_level -= 1
	if graphics_level < 0: graphics_level = 2
	var text = "Low"
	if graphics_level == 1: text = "Medium"
	elif graphics_level == 2: text = "High"
	btn_graphics.text = "Graphics: " + text
	
	SaveSystem.save_settings(is_mph, graphics_level, is_retro) 
	_apply_graphics()

func _find_node_by_name(parent: Node, node_name: String) -> Node:
	for child in parent.get_children():
		if child.name == node_name: return child
		var found = _find_node_by_name(child, node_name)
		if found: return found
	return null

func _apply_graphics():
	var sun = _find_node_by_name(get_tree().current_scene, "GeneratedSun")
	var world_env = _find_node_by_name(get_tree().current_scene, "GeneratedWorldEnv")
	if not world_env or not sun: return
	var env = world_env.environment
	match graphics_level:
		0: 
			get_viewport().scaling_3d_scale = 0.4 
			sun.shadow_enabled = false
			env.ssao_enabled = false
			env.glow_enabled = false
			env.volumetric_fog_enabled = false
		1: 
			get_viewport().scaling_3d_scale = 0.75 
			sun.shadow_enabled = true
			env.ssao_enabled = false
			env.glow_enabled = true
			env.volumetric_fog_enabled = false
		2: 
			get_viewport().scaling_3d_scale = 1.0 
			sun.shadow_enabled = true
			env.ssao_enabled = true
			env.glow_enabled = true
			env.volumetric_fog_enabled = true
