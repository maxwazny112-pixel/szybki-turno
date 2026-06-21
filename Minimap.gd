extends Node

const NORMAL_SIZE = Vector2(250, 250)
const LARGE_SIZE = Vector2(700, 700)
const ORTHO_SIZE_NORMAL = 100.0 

var ortho_size_large = 350.0 
var is_large = false
var is_animating = false

var canvas_layer: CanvasLayer
var container: SubViewportContainer
var viewport: SubViewport
var map_cam: Camera3D
var player_arrow: Polygon2D
var border: ReferenceRect

var credits_container: Control
var credits_bg: ColorRect
var credits_label: Label

var trap_icons = [] 
var race_icons = [] 
var garage_icons = [] # NEW: Garage Trackers
var ui_tween: Tween

@onready var car = get_parent()

func _ready():
	canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	container = SubViewportContainer.new()
	container.stretch = true
	canvas_layer.add_child(container)
	
	viewport = SubViewport.new()
	viewport.world_3d = get_viewport().world_3d 
	container.add_child(viewport)
	
	map_cam = Camera3D.new()
	map_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	map_cam.rotation_degrees = Vector3(-90, 0, 0)
	map_cam.far = 2000.0 
	viewport.add_child(map_cam)
	
	var map_tint = ColorRect.new()
	map_tint.color = Color(0.0, 0.0, 0.0, 0.35) 
	map_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(map_tint)
	
	border = ReferenceRect.new()
	border.border_color = Color(0.15, 0.35, 0.8)
	border.border_width = 4.0
	border.editor_only = false
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(border)
	
	player_arrow = Polygon2D.new()
	player_arrow.color = Color(1.0, 0.8, 0.0) 
	player_arrow.polygon = PackedVector2Array([
		Vector2(0, -15), Vector2(10, 10), Vector2(0, 5), Vector2(-10, 10)
	])
	container.add_child(player_arrow)
	
	credits_container = Control.new()
	canvas_layer.add_child(credits_container)
	
	credits_bg = ColorRect.new()
	credits_bg.color = Color(0.1, 0.1, 0.1, 0.9)
	credits_bg.size = Vector2(250, 40)
	credits_container.add_child(credits_bg)
	
	var cr_border = ReferenceRect.new()
	cr_border.border_color = Color(1.0, 0.8, 0.0)
	cr_border.border_width = 4.0
	cr_border.editor_only = false
	cr_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits_bg.add_child(cr_border)
	
	credits_label = Label.new()
	var sys_font = SystemFont.new()
	sys_font.font_weight = 900
	sys_font.font_italic = true
	var cr_set = LabelSettings.new()
	cr_set.font = sys_font
	cr_set.font_size = 26
	cr_set.font_color = Color(1.0, 0.8, 0.0)
	cr_set.outline_color = Color.BLACK
	cr_set.outline_size = 6
	credits_label.label_settings = cr_set
	credits_label.text = "CREDITS: 0"
	credits_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	credits_bg.add_child(credits_label)
	
	_update_ui_positions(0.0)

func _process(delta):
	credits_label.text = "CREDITS: " + str(SaveSystem.get_credits())
	
	if Input.is_action_just_pressed("toggle_map"):
		is_large = !is_large
		_update_ui_positions(0.3) 
		
	if is_large and not is_animating:
		var zoom_changed = false
		if Input.is_action_pressed("map_zoom_in"):
			ortho_size_large -= 600.0 * delta
			zoom_changed = true
		if Input.is_action_pressed("map_zoom_out"):
			ortho_size_large += 600.0 * delta
			zoom_changed = true
			
		if zoom_changed:
			ortho_size_large = clamp(ortho_size_large, 100.0, 1200.0)
			map_cam.size = ortho_size_large
			
	if car is Node3D:
		map_cam.global_position = car.global_position + Vector3(0, 150, 0)
		player_arrow.rotation = -car.global_rotation.y
		
	_update_speed_trap_icons()
	_update_race_icons()
	_update_garage_icons()

func _apply_trap_label(lbl: Label, stats: Dictionary):
	var s = stats.stars
	var spd = stats.speed
	var star_txt = ""
	var col = Color(0.5, 0.5, 0.5)
	
	if s == 3: star_txt = "★★★"; col = Color(1.0, 0.8, 0.0)
	elif s == 2: star_txt = "★★☆"; col = Color(0.8, 0.8, 0.8)
	elif s == 1: star_txt = "★☆☆"; col = Color(0.8, 0.4, 0.2)
	else: star_txt = "☆☆☆"
	
	lbl.label_settings.font_color = col
	if spd > 0: lbl.text = star_txt + "\n" + str(spd)
	else: lbl.text = star_txt

func _apply_race_label(lbl: Label, stats: Dictionary):
	var s = stats.stars
	var t = stats.time
	var star_txt = ""
	var col = Color(0.5, 0.5, 0.5)
	
	if s == 3: star_txt = "★★★"; col = Color(1.0, 0.8, 0.0)
	elif s == 2: star_txt = "★★☆"; col = Color(0.8, 0.8, 0.8)
	elif s == 1: star_txt = "★☆☆"; col = Color(0.8, 0.4, 0.2)
	else: star_txt = "☆☆☆"
	
	lbl.label_settings.font_color = col
	if t > 0.0:
		var m = floori(t / 60.0)
		var sec = floori(fmod(t, 60.0))
		lbl.text = star_txt + "\n" + "%02d:%02d" % [m, sec]
	else: lbl.text = star_txt

func _update_speed_trap_icons():
	var traps = get_tree().get_nodes_in_group("speed_traps")
	while trap_icons.size() < traps.size():
		var icon = _create_trap_icon()
		container.add_child(icon)
		trap_icons.append(icon)
		
	for i in range(traps.size()):
		var trap = traps[i]
		var icon = trap_icons[i]
		var pos2d = map_cam.unproject_position(trap.global_position)
		icon.position = pos2d
		icon.visible = _is_on_map(pos2d)
		
		if icon.visible:
			var stats = SaveSystem.get_trap_stats(trap.name)
			_apply_trap_label(icon.get_node("Stars"), stats)

func _update_race_icons():
	var races = get_tree().get_nodes_in_group("race_systems")
	
	while race_icons.size() < races.size():
		var node = Node2D.new()
		
		var start_icon = _create_race_start_icon()
		start_icon.name = "StartIcon"
		node.add_child(start_icon)
		
		var finish_icon = Polygon2D.new()
		finish_icon.name = "FinishIcon"
		finish_icon.color = Color(1.0, 0.5, 0.0) 
		finish_icon.polygon = PackedVector2Array([Vector2(0, -12), Vector2(10, 8), Vector2(-10, 8)])
		node.add_child(finish_icon)
		
		var lbl = _create_star_label()
		node.add_child(lbl)
		
		container.add_child(node)
		race_icons.append(node)
		
	var any_race_active = false
	for race in races:
		if race.is_racing:
			any_race_active = true
			break
		
	for i in range(races.size()):
		var race = races[i]
		var holder = race_icons[i]
		var start_icon = holder.get_node("StartIcon")
		var finish_icon = holder.get_node("FinishIcon")
		var stars_lbl = holder.get_node("Stars")
		
		if race.is_racing:
			start_icon.visible = false
			finish_icon.visible = true
			
			if race.finish_line:
				var pos2d = map_cam.unproject_position(race.finish_line.global_position)
				holder.position = pos2d
				holder.visible = _is_on_map(pos2d)
				stars_lbl.visible = false 
				
		elif any_race_active:
			holder.visible = false
			
		else:
			start_icon.visible = true
			finish_icon.visible = false
			stars_lbl.visible = true 
			
			if race.start_line:
				var pos2d = map_cam.unproject_position(race.start_line.global_position)
				holder.position = pos2d
				holder.visible = _is_on_map(pos2d)
				
				if holder.visible:
					var stats = SaveSystem.get_race_stats(race.name)
					_apply_race_label(stars_lbl, stats)

# --- NEW: UPDATE GARAGE ICONS ---
func _update_garage_icons():
	var garages = get_tree().get_nodes_in_group("garage")
	
	while garage_icons.size() < garages.size():
		var icon = _create_garage_icon()
		container.add_child(icon)
		garage_icons.append(icon)
		
	for i in range(garages.size()):
		var garage = garages[i]
		var icon = garage_icons[i]
		var pos2d = map_cam.unproject_position(garage.global_position)
		icon.position = pos2d
		icon.visible = _is_on_map(pos2d)

# --- NEW: DRAW GARAGE ICON ---
func _create_garage_icon() -> Node2D:
	var node = Node2D.new()
	
	var orange_out = Polygon2D.new()
	orange_out.color = Color(1.0, 0.5, 0.0) # Orange Outline
	orange_out.polygon = PackedVector2Array([Vector2(-12, -12), Vector2(12, -12), Vector2(12, 12), Vector2(-12, 12)])
	node.add_child(orange_out)
	
	var white_in = Polygon2D.new()
	white_in.color = Color.WHITE # White Square
	white_in.polygon = PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	node.add_child(white_in)
	
	var black_center = Polygon2D.new()
	black_center.color = Color.BLACK # Black Center
	black_center.polygon = PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)])
	node.add_child(black_center)
	
	return node

func _create_star_label() -> Label:
	var lbl = Label.new()
	lbl.name = "Stars"
	var settings = LabelSettings.new()
	var sys_font = SystemFont.new()
	sys_font.font_weight = 900
	settings.font = sys_font
	settings.font_size = 12 
	settings.outline_color = Color.BLACK
	settings.outline_size = 4
	settings.line_spacing = -2 
	lbl.label_settings = settings
	lbl.position = Vector2(-30, 10) 
	lbl.custom_minimum_size = Vector2(60, 30)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

func _create_trap_icon() -> Node2D:
	var node = Node2D.new()
	var outline = Polygon2D.new()
	outline.color = Color(0.8, 0.0, 0.0)
	outline.polygon = PackedVector2Array([Vector2(0, -16), Vector2(14, 10), Vector2(-14, 10)])
	node.add_child(outline)
	var inner = Polygon2D.new()
	inner.color = Color.WHITE
	inner.polygon = PackedVector2Array([Vector2(0, -11), Vector2(10, 7), Vector2(-10, 7)])
	node.add_child(inner)
	var excl_top = Polygon2D.new()
	excl_top.color = Color.BLACK
	excl_top.polygon = PackedVector2Array([Vector2(-1.5, -4), Vector2(1.5, -4), Vector2(1.0, 2), Vector2(-1.0, 2)])
	node.add_child(excl_top)
	var excl_bot = Polygon2D.new()
	excl_bot.color = Color.BLACK
	excl_bot.polygon = PackedVector2Array([Vector2(-1.5, 3.5), Vector2(1.5, 3.5), Vector2(1.5, 6), Vector2(-1.5, 6)])
	node.add_child(excl_bot)
	
	var lbl = _create_star_label()
	lbl.position = Vector2(-30, 12)
	node.add_child(lbl)
	return node

func _create_race_start_icon() -> Node2D:
	var node = Node2D.new()
	var outline = Polygon2D.new()
	outline.color = Color(0.8, 0.0, 0.0)
	var out_pts = PackedVector2Array()
	for i in range(12):
		var angle = i * (PI / 6.0)
		out_pts.append(Vector2(cos(angle) * 14, sin(angle) * 14))
	outline.polygon = out_pts
	node.add_child(outline)
	var inner = Polygon2D.new()
	inner.color = Color.WHITE
	var in_pts = PackedVector2Array()
	for i in range(12):
		var angle = i * (PI / 6.0)
		in_pts.append(Vector2(cos(angle) * 10, sin(angle) * 10))
	inner.polygon = in_pts
	node.add_child(inner)
	var excl_top = Polygon2D.new()
	excl_top.color = Color.BLACK
	excl_top.polygon = PackedVector2Array([Vector2(-1.5, -5), Vector2(1.5, -5), Vector2(1.0, 1), Vector2(-1.0, 1)])
	node.add_child(excl_top)
	var excl_bot = Polygon2D.new()
	excl_bot.color = Color.BLACK
	excl_bot.polygon = PackedVector2Array([Vector2(-1.5, 2.5), Vector2(1.5, 2.5), Vector2(1.5, 5), Vector2(-1.5, 5)])
	node.add_child(excl_bot)
	return node

func _is_on_map(pos2d: Vector2) -> bool:
	var pad = 15.0
	return not (pos2d.x < -pad or pos2d.x > container.size.x + pad or pos2d.y < -pad or pos2d.y > container.size.y + pad)

func _update_ui_positions(duration: float):
	var vp_size = get_viewport().get_visible_rect().size
	var target_pos: Vector2
	var target_size: Vector2
	var target_cam_size: float
	
	if is_large:
		target_size = LARGE_SIZE
		target_pos = (vp_size / 2.0) - (LARGE_SIZE / 2.0)
		target_cam_size = ortho_size_large
	else:
		target_size = NORMAL_SIZE
		target_pos = Vector2(vp_size.x - NORMAL_SIZE.x - 20, 20)
		target_cam_size = ORTHO_SIZE_NORMAL
		
	var credits_target_pos = target_pos + Vector2(0, target_size.y + 5)
	var credits_target_size = Vector2(target_size.x, 40)
		
	if ui_tween: ui_tween.kill()
		
	if duration > 0.0:
		is_animating = true
		ui_tween = create_tween()
		ui_tween.set_parallel(true)
		ui_tween.set_trans(Tween.TRANS_SINE)
		ui_tween.tween_property(container, "position", target_pos, duration)
		ui_tween.tween_property(container, "size", target_size, duration)
		ui_tween.tween_property(player_arrow, "position", target_size / 2.0, duration)
		ui_tween.tween_property(map_cam, "size", target_cam_size, duration)
		ui_tween.tween_property(credits_container, "position", credits_target_pos, duration)
		ui_tween.tween_property(credits_bg, "size", credits_target_size, duration)
		ui_tween.chain().tween_callback(_on_anim_finished)
	else:
		container.position = target_pos
		container.size = target_size
		player_arrow.position = target_size / 2.0
		map_cam.size = target_cam_size
		credits_container.position = credits_target_pos
		credits_bg.size = credits_target_size
		is_animating = false

func _on_anim_finished():
	is_animating = false
