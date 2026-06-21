extends Area3D

var canvas: CanvasLayer
var prompt_ui: Control
var menu_ui: Control
var fade_rect: ColorRect
var ui_tween: Tween

var player_in_zone = false
var is_in_garage = false

# The injected parts!
var basic_mesh: Node3D
var basic_collision: CollisionShape3D
var pigeon_mesh: Node3D
var pigeon_collision: CollisionShape3D
var shitta_mesh: Node3D
var shitta_collision: CollisionShape3D
var cheflorin_mesh: Node3D
var cheflorin_collision: CollisionShape3D
var dam_mesh: Node3D
var dam_collision: CollisionShape3D
var goatgenie_mesh: Node3D
var goatgenie_collision: CollisionShape3D

# --- HARDWARE CONTROLLER TRACKING ---
var was_joy_a_pressed = false
var scroll_container: ScrollContainer

# UI References for dynamic updating
var wallet_label: Label
var btn_basic: Button
var btn_pigeon: Button
var btn_shitta: Button
var btn_cheflorin: Button
var btn_dam: Button
var btn_goatgenie: Button

func _ready():
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("garage") 
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_build_ui()
	
	# ---------------------------------------------------------
	# THE HEIST: Steal parts from ALL cars on the map!
	# ---------------------------------------------------------
	var player = get_node_or_null("../PlayerCar")
	var pigeon = get_node_or_null("../Pigeon308")
	var shitta = get_node_or_null("../ShittaRapid")
	var cheflorin = get_node_or_null("../CheflorinCaptiveXS")
	var dam = get_node_or_null("../Dam1500")
	var goatgenie = get_node_or_null("../GoatgenieSenarioSter")

	if player:
		basic_collision = player.get_node_or_null("BasicCollision")
		basic_mesh = player.get_node_or_null("BasicMesh")

	if pigeon and player:
		pigeon_collision = pigeon.get_node_or_null("PigeonCollision")
		pigeon_mesh = pigeon.get_node_or_null("PigeonMesh")

		if pigeon_collision:
			pigeon_collision.get_parent().remove_child(pigeon_collision)
			player.add_child(pigeon_collision)
		if pigeon_mesh:
			pigeon_mesh.get_parent().remove_child(pigeon_mesh)
			player.add_child(pigeon_mesh)
		pigeon.queue_free() 

	if shitta and player:
		shitta_collision = shitta.get_node_or_null("ShittaCollision")
		shitta_mesh = shitta.get_node_or_null("ShittaMesh")

		if shitta_collision:
			shitta_collision.get_parent().remove_child(shitta_collision)
			player.add_child(shitta_collision)
		if shitta_mesh:
			shitta_mesh.get_parent().remove_child(shitta_mesh)
			player.add_child(shitta_mesh)
		shitta.queue_free() 

	if cheflorin and player:
		cheflorin_collision = cheflorin.get_node_or_null("CheflorinCollision")
		cheflorin_mesh = cheflorin.get_node_or_null("CheflorinMesh")

		if cheflorin_collision:
			cheflorin_collision.get_parent().remove_child(cheflorin_collision)
			player.add_child(cheflorin_collision)
		if cheflorin_mesh:
			cheflorin_mesh.get_parent().remove_child(cheflorin_mesh)
			player.add_child(cheflorin_mesh)
		cheflorin.queue_free() 

	if dam and player:
		dam_collision = dam.get_node_or_null("DamCollision")
		dam_mesh = dam.get_node_or_null("DamMesh")

		if dam_collision:
			dam_collision.get_parent().remove_child(dam_collision)
			player.add_child(dam_collision)
		if dam_mesh:
			dam_mesh.get_parent().remove_child(dam_mesh)
			player.add_child(dam_mesh)
		dam.queue_free() 

	if goatgenie and player:
		goatgenie_collision = goatgenie.get_node_or_null("GoatgenieCollision")
		goatgenie_mesh = goatgenie.get_node_or_null("GoatgenieMesh")

		if goatgenie_collision:
			goatgenie_collision.get_parent().remove_child(goatgenie_collision)
			player.add_child(goatgenie_collision)
		if goatgenie_mesh:
			goatgenie_mesh.get_parent().remove_child(goatgenie_mesh)
			player.add_child(goatgenie_mesh)
		goatgenie.queue_free() 

	var saved_car = SaveSystem.get_selected_car()
	_apply_car(saved_car)

func _process(delta):
	if is_in_garage:
		prompt_ui.visible = false
		
		# 1. Hardware Mouse Simulation (Left Thumbstick)
		var joy_x = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
		var joy_y = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
		
		if abs(joy_x) > 0.15 or abs(joy_y) > 0.15:
			var current_mouse = get_viewport().get_mouse_position()
			var new_mouse = current_mouse + Vector2(joy_x, joy_y) * 1200.0 * delta
			var rect = get_viewport().get_visible_rect().size
			new_mouse.x = clamp(new_mouse.x, 0, rect.x)
			new_mouse.y = clamp(new_mouse.y, 0, rect.y)
			get_viewport().warp_mouse(new_mouse)
			
		# 2. Hardware Scrolling (Right Thumbstick)
		var joy_ry = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		if abs(joy_ry) > 0.15 and scroll_container:
			scroll_container.scroll_vertical += int(joy_ry * 800.0 * delta)
			
		# 3. Hardware Clicking (A Button)
		var is_a_pressed = Input.is_joy_button_pressed(0, JOY_BUTTON_A)
		if is_a_pressed and not was_joy_a_pressed:
			var ev = InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.global_position = get_viewport().get_mouse_position()
			Input.parse_input_event(ev)
		elif not is_a_pressed and was_joy_a_pressed:
			var ev = InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = false
			ev.global_position = get_viewport().get_mouse_position()
			Input.parse_input_event(ev)
			
		was_joy_a_pressed = is_a_pressed
		return

	# Prompt Logic
	if player_in_zone:
		prompt_ui.visible = true
		if Input.is_action_just_pressed("interact_race"):
			_open_garage()
	else:
		prompt_ui.visible = false

# --- DYNAMIC GARAGE MENU REFRESH ---
func _update_garage_ui():
	if SaveSystem.current_user == "":
		wallet_label.text = "LOG IN TO USE GARAGE"
		btn_basic.disabled = true; btn_basic.text = "Basic Car [LOCKED]"
		btn_pigeon.disabled = true; btn_pigeon.text = "Pigeon 308 [LOCKED]"
		btn_shitta.disabled = true; btn_shitta.text = "Shitta Rapid [LOCKED]"
		btn_cheflorin.disabled = true; btn_cheflorin.text = "Cheflorin Captive XS [LOCKED]"
		btn_dam.disabled = true; btn_dam.text = "DAM 1500 [LOCKED]"
		btn_goatgenie.disabled = true; btn_goatgenie.text = "GoatgenieSenarioSter [LOCKED]"
		return
		
	btn_basic.disabled = false
	btn_pigeon.disabled = false
	btn_shitta.disabled = false
	btn_cheflorin.disabled = false
	btn_dam.disabled = false
	btn_goatgenie.disabled = false
	
	wallet_label.text = "WALLET: " + str(SaveSystem.get_credits()) + " CR"
	var current_car = SaveSystem.get_selected_car()
	
	# Basic Car (Always Owned)
	if current_car == "Basic": btn_basic.text = "Basic Car [SELECTED]"
	else: btn_basic.text = "Basic Car (Owned)"
		
	# Pigeon 308 (Always Owned)
	if current_car == "Pigeon": btn_pigeon.text = "Pigeon 308 [SELECTED]"
	else: btn_pigeon.text = "Pigeon 308 (Owned)"
		
	# Shitta Rapid (Costs 200 CR)
	if SaveSystem.is_car_owned("Shitta"):
		if current_car == "Shitta": btn_shitta.text = "Shitta Rapid [SELECTED]"
		else: btn_shitta.text = "Shitta Rapid (Owned)"
	else:
		btn_shitta.text = "BUY Shitta Rapid [200 CR]"
		
	# Cheflorin Captive XS (Costs 300 CR)
	if SaveSystem.is_car_owned("Cheflorin"):
		if current_car == "Cheflorin": btn_cheflorin.text = "Cheflorin Captive [SELECTED]"
		else: btn_cheflorin.text = "Cheflorin Captive (Owned)"
	else:
		btn_cheflorin.text = "BUY Cheflorin Captive [300 CR]"
		
	# DAM 1500 (Costs 400 CR)
	if SaveSystem.is_car_owned("Dam"):
		if current_car == "Dam": btn_dam.text = "DAM 1500 [SELECTED]"
		else: btn_dam.text = "DAM 1500 (Owned)"
	else:
		btn_dam.text = "BUY DAM 1500 [400 CR]"

	# GoatgenieSenarioSter (Costs 600 CR)
	if SaveSystem.is_car_owned("Goatgenie"):
		if current_car == "Goatgenie": btn_goatgenie.text = "GoatgenieSenarioSter [SELECTED]"
		else: btn_goatgenie.text = "GoatgenieSenarioSter (Owned)"
	else:
		btn_goatgenie.text = "BUY GoatgenieSenarioSter [600 CR]"

# --- CAR SWAPPING & STORE LOGIC ---
func _apply_car(car_name: String):
	if basic_mesh: basic_mesh.visible = false
	if basic_collision: basic_collision.disabled = true
	if pigeon_mesh: pigeon_mesh.visible = false
	if pigeon_collision: pigeon_collision.disabled = true
	if shitta_mesh: shitta_mesh.visible = false
	if shitta_collision: shitta_collision.disabled = true
	if cheflorin_mesh: cheflorin_mesh.visible = false
	if cheflorin_collision: cheflorin_collision.disabled = true
	if dam_mesh: dam_mesh.visible = false
	if dam_collision: dam_collision.disabled = true
	if goatgenie_mesh: goatgenie_mesh.visible = false
	if goatgenie_collision: goatgenie_collision.disabled = true

	if car_name == "Basic":
		if basic_mesh: basic_mesh.visible = true
		if basic_collision: basic_collision.disabled = false
	elif car_name == "Pigeon":
		if pigeon_mesh: pigeon_mesh.visible = true
		if pigeon_collision: pigeon_collision.disabled = false
	elif car_name == "Shitta":
		if shitta_mesh: shitta_mesh.visible = true
		if shitta_collision: shitta_collision.disabled = false
	elif car_name == "Cheflorin":
		if cheflorin_mesh: cheflorin_mesh.visible = true
		if cheflorin_collision: cheflorin_collision.disabled = false
	elif car_name == "Dam":
		if dam_mesh: dam_mesh.visible = true
		if dam_collision: dam_collision.disabled = false
	elif car_name == "Goatgenie":
		if goatgenie_mesh: goatgenie_mesh.visible = true
		if goatgenie_collision: goatgenie_collision.disabled = false

func _on_select_basic():
	SaveSystem.set_selected_car("Basic")
	_apply_car("Basic")
	_update_garage_ui()

func _on_select_pigeon():
	SaveSystem.set_selected_car("Pigeon")
	_apply_car("Pigeon")
	_update_garage_ui()

func _on_select_shitta():
	if SaveSystem.is_car_owned("Shitta"):
		SaveSystem.set_selected_car("Shitta")
		_apply_car("Shitta")
		_update_garage_ui()
	else:
		if SaveSystem.purchase_car("Shitta", 200):
			SaveSystem.set_selected_car("Shitta")
			_apply_car("Shitta")
			_update_garage_ui()

func _on_select_cheflorin():
	if SaveSystem.is_car_owned("Cheflorin"):
		SaveSystem.set_selected_car("Cheflorin")
		_apply_car("Cheflorin")
		_update_garage_ui()
	else:
		if SaveSystem.purchase_car("Cheflorin", 300):
			SaveSystem.set_selected_car("Cheflorin")
			_apply_car("Cheflorin")
			_update_garage_ui()

func _on_select_dam():
	if SaveSystem.is_car_owned("Dam"):
		SaveSystem.set_selected_car("Dam")
		_apply_car("Dam")
		_update_garage_ui()
	else:
		if SaveSystem.purchase_car("Dam", 400):
			SaveSystem.set_selected_car("Dam")
			_apply_car("Dam")
			_update_garage_ui()

func _on_select_goatgenie():
	if SaveSystem.is_car_owned("Goatgenie"):
		SaveSystem.set_selected_car("Goatgenie")
		_apply_car("Goatgenie")
		_update_garage_ui()
	else:
		if SaveSystem.purchase_car("Goatgenie", 600):
			SaveSystem.set_selected_car("Goatgenie")
			_apply_car("Goatgenie")
			_update_garage_ui()

# --- GARAGE TRANSITIONS ---
func _open_garage():
	is_in_garage = true
	get_tree().paused = true
	_update_garage_ui()
	
	if ui_tween: ui_tween.kill()
	ui_tween = create_tween()
	ui_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) 
	
	fade_rect.visible = true
	menu_ui.visible = true
	ui_tween.tween_property(fade_rect, "color:a", 1.0, 0.5)

func _close_garage():
	if ui_tween: ui_tween.kill()
	ui_tween = create_tween()
	ui_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	menu_ui.visible = false
	ui_tween.tween_property(fade_rect, "color:a", 0.0, 0.5)
	ui_tween.tween_callback(func(): 
		fade_rect.visible = false
		is_in_garage = false
		get_tree().paused = false
	)

func _is_player(body) -> bool:
	if body is CharacterBody3D or body is VehicleBody3D: return true
	if "player" in body.name.to_lower() or "car" in body.name.to_lower(): return true
	return false

func _on_body_entered(body):
	if _is_player(body): player_in_zone = true

func _on_body_exited(body):
	if _is_player(body): player_in_zone = false

# --- UI BUILDER ---
func _build_ui():
	canvas = CanvasLayer.new()
	canvas.layer = 70
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
	lbl.text = "PRESS [ENTER / D-PAD RIGHT] TO ENTER GARAGE"
	var lbl_set = LabelSettings.new()
	lbl_set.font = sys_font
	lbl_set.font_size = 20
	lbl_set.font_color = Color(1.0, 0.8, 0.0)
	lbl.label_settings = lbl_set
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.position = Vector2(-200, -15)
	prompt_ui.add_child(lbl)
	
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0) 
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.visible = false
	canvas.add_child(fade_rect)
	
	menu_ui = Control.new()
	menu_ui.set_anchors_preset(Control.PRESET_CENTER)
	menu_ui.visible = false
	canvas.add_child(menu_ui)
	
	var title = Label.new()
	title.text = "GARAGE"
	var title_set = LabelSettings.new()
	title_set.font = sys_font
	title_set.font_size = 72
	title_set.font_color = Color(1.0, 0.8, 0.0)
	title_set.outline_color = Color.BLACK
	title_set.outline_size = 10
	title.label_settings = title_set
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-150, -320) 
	menu_ui.add_child(title)
	
	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 20)
	outer_vbox.set_anchors_preset(Control.PRESET_CENTER)
	outer_vbox.position = Vector2(-220, -220) 
	menu_ui.add_child(outer_vbox)
	
	wallet_label = Label.new()
	wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cred_set = LabelSettings.new()
	cred_set.font = sys_font
	cred_set.font_size = 36
	cred_set.font_color = Color(1.0, 0.8, 0.0)
	wallet_label.label_settings = cred_set
	outer_vbox.add_child(wallet_label)
	
	# NEW: SCROLL CONTAINER FOR THE CAR LIST
	scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(440, 260) # Shows about 3 cars at a time
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(scroll_container)
	
	var inner_vbox = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 15)
	inner_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(inner_vbox)
	
	btn_basic = _create_button("Basic Car", inner_vbox, _on_select_basic)
	btn_pigeon = _create_button("Pigeon 308", inner_vbox, _on_select_pigeon)
	btn_shitta = _create_button("Shitta Rapid", inner_vbox, _on_select_shitta)
	btn_cheflorin = _create_button("Cheflorin Captive XS", inner_vbox, _on_select_cheflorin)
	btn_dam = _create_button("DAM 1500", inner_vbox, _on_select_dam)
	btn_goatgenie = _create_button("GoatgenieSenarioSter", inner_vbox, _on_select_goatgenie)
	
	# Close button locked cleanly outside of the scroll list
	_create_button("CLOSE", outer_vbox, _close_garage)

func _create_button(text: String, parent: Node, callable: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(400, 60)
	var sys_font = SystemFont.new()
	sys_font.font_weight = 900
	sys_font.font_italic = true
	btn.add_theme_font_override("font", sys_font)
	btn.add_theme_font_size_override("font_size", 30) 
	
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
