extends Node

@export var trap_sound: AudioStream
var audio_player: AudioStreamPlayer

var canvas: CanvasLayer
var ui_base: Control
var title_label: Label
var speed_label: Label
var stars_label: Label
var active_tween: Tween

func _ready():
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	if trap_sound: audio_player.stream = trap_sound

	canvas = CanvasLayer.new()
	add_child(canvas)

	ui_base = Control.new()
	# CHANGED: Now anchored exactly to the TOP CENTER of the screen
	ui_base.set_anchors_preset(Control.PRESET_CENTER_TOP)
	# Start hidden 200 pixels ABOVE the top edge of the screen
	ui_base.position = Vector2(0, -200) 
	canvas.add_child(ui_base)

	# Shifted polygon math so the box draws downward from the ceiling
	var bg = Polygon2D.new()
	bg.color = Color(0.1, 0.1, 0.1, 0.9)
	bg.polygon = PackedVector2Array([
		Vector2(30, 0), Vector2(370, 0),
		Vector2(340, 120), Vector2(0, 120)
	])
	bg.position = Vector2(-185, 0)
	ui_base.add_child(bg)
	
	var top_border = Polygon2D.new()
	top_border.color = Color(1.0, 0.8, 0.0) 
	top_border.polygon = PackedVector2Array([
		Vector2(30, 0), Vector2(370, 0), Vector2(368, 5), Vector2(28, 5)
	])
	top_border.position = Vector2(-185, 0)
	ui_base.add_child(top_border)

	var sys_font = SystemFont.new()
	sys_font.font_weight = 900
	sys_font.font_italic = true

	title_label = Label.new()
	title_label.text = "SPEED TRAP"
	var title_set = LabelSettings.new()
	title_set.font = sys_font
	title_set.font_size = 28
	title_set.font_color = Color(1.0, 0.8, 0.0)
	title_label.label_settings = title_set
	title_label.position = Vector2(-75, 5) 
	ui_base.add_child(title_label)

	speed_label = Label.new()
	speed_label.text = "0 KMH"
	var speed_set = LabelSettings.new()
	speed_set.font = sys_font
	speed_set.font_size = 48
	speed_set.font_color = Color.WHITE
	speed_set.outline_color = Color.BLACK
	speed_set.outline_size = 6
	speed_label.label_settings = speed_set
	speed_label.position = Vector2(-100, 40) 
	speed_label.custom_minimum_size = Vector2(200, 50)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_base.add_child(speed_label)

	stars_label = Label.new()
	stars_label.text = "☆☆☆"
	var stars_set = LabelSettings.new()
	stars_set.font = sys_font
	stars_set.font_size = 42
	stars_label.label_settings = stars_set
	stars_label.position = Vector2(-100, 90) 
	stars_label.custom_minimum_size = Vector2(200, 50)
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_base.add_child(stars_label)

func trigger_trap(speed: int, s1: int, s2: int, s3: int, unit: String):
	if audio_player.stream: audio_player.play()
	
	speed_label.text = str(speed) + " " + unit

	var stars = 0
	if speed >= s3: stars = 3
	elif speed >= s2: stars = 2
	elif speed >= s1: stars = 1

	if stars == 3: 
		stars_label.text = "★★★"
		stars_label.label_settings.font_color = Color(1.0, 0.8, 0.0) 
	elif stars == 2: 
		stars_label.text = "★★☆"
		stars_label.label_settings.font_color = Color(0.8, 0.8, 0.8) 
	elif stars == 1: 
		stars_label.text = "★☆☆"
		stars_label.label_settings.font_color = Color(0.8, 0.4, 0.2) 
	else: 
		stars_label.text = "☆☆☆"
		stars_label.label_settings.font_color = Color(0.3, 0.3, 0.3) 

	if active_tween: active_tween.kill()
	active_tween = create_tween()
	
	# Snap DOWN from the ceiling to y=20
	active_tween.tween_property(ui_base, "position:y", 20.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Hold at the top of the screen for 3 seconds
	active_tween.tween_interval(3.0) 
	
	# Snap UP back into the ceiling to hide (-200)
	active_tween.tween_property(ui_base, "position:y", -200.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
