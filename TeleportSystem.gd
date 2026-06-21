extends Area3D

@export var destination_marker: Node3D
@export var location_name: String = "DESTINATION"

var canvas: CanvasLayer
var prompt_ui: Control
var fade_rect: ColorRect
var ui_tween: Tween

var player_in_zone = false
var active_player: CharacterBody3D = null

# --- HARDWARE CONTROLLER TRACKING ---
var was_joy_a_pressed = false

func _ready():
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_ui()

func _process(_delta):
	if player_in_zone and active_player and destination_marker:
		prompt_ui.visible = true
		
		# Check for Enter key
		if Input.is_action_just_pressed("interact_race"):
			_teleport_player()
			
		# Hardware Check for D-Pad Right (Joypad Button 14 on most controllers)
		var dpad_right = Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT)
		if dpad_right and not was_joy_a_pressed:
			_teleport_player()
		was_joy_a_pressed = dpad_right
			
	else:
		prompt_ui.visible = false

func _teleport_player():
	# THE FIX: Lock in the car and destination right now so they 
	# can't become "Nil" if the player rolls out of the tunnel during the fade!
	var car_to_teleport = active_player
	var dest_marker = destination_marker
	
	player_in_zone = false
	prompt_ui.visible = false
	
	if ui_tween: ui_tween.kill()
	ui_tween = create_tween()
	
	fade_rect.visible = true
	# 1. Fade to Black
	ui_tween.tween_property(fade_rect, "color:a", 1.0, 0.5)
	ui_tween.tween_callback(func():
		# 2. Teleport the locked-in car!
		if car_to_teleport and dest_marker:
			car_to_teleport.global_position = dest_marker.global_position
			car_to_teleport.global_rotation = dest_marker.global_rotation
			
			# Reset velocity so they don't go flying out of the tunnel at 300 KMH!
			car_to_teleport.velocity = Vector3.ZERO
		
		# 3. Fade back in
		var in_tween = create_tween()
		in_tween.tween_property(fade_rect, "color:a", 0.0, 0.5)
		in_tween.tween_callback(func(): fade_rect.visible = false)
	)

func _is_player(body) -> bool:
	if body is CharacterBody3D or body is VehicleBody3D: return true
	if "player" in body.name.to_lower() or "car" in body.name.to_lower(): return true
	return false

func _on_body_entered(body):
	if _is_player(body): 
		player_in_zone = true
		active_player = body

func _on_body_exited(body):
	if _is_player(body): 
		player_in_zone = false
		active_player = null

# --- UI BUILDER ---
func _build_ui():
	canvas = CanvasLayer.new()
	canvas.layer = 80 
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
	lbl.text = "PRESS [ENTER / D-PAD RIGHT] TO GO TO " + location_name
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
