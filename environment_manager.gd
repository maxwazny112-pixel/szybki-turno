extends Node

func _ready():
	# 1. Generate the Burnout-Style Sun
	var sun = DirectionalLight3D.new()
	sun.name = "GeneratedSun"
	sun.shadow_enabled = true
	sun.shadow_bias = 0.02 
	sun.shadow_blur = 0.5  
	sun.rotation_degrees = Vector3(-20, 60, 0) 
	sun.light_color = Color(1.0, 0.85, 0.6) 
	
	sun.light_energy = 1.5 
	sun.light_volumetric_fog_energy = 1.5 
	add_child(sun)

	# 2. Generate the Procedural Sky 
	var sky_material = ProceduralSkyMaterial.new()
	
	# BRIGHTENED: Lifted the sky and ground colors so ambient shadows aren't pitch black
	sky_material.sky_top_color = Color(0.3, 0.3, 0.35) 
	sky_material.sky_horizon_color = Color(0.5, 0.5, 0.45) 
	sky_material.ground_bottom_color = Color(0.15, 0.15, 0.15) # Previously 0.05
	sky_material.ground_horizon_color = Color(0.35, 0.35, 0.3)
	
	var generated_sky = Sky.new()
	generated_sky.sky_material = sky_material
	
	# 3. Generate the Environment Settings
	var env_settings = Environment.new()
	env_settings.background_mode = Environment.BG_SKY
	env_settings.sky = generated_sky
	env_settings.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	
	# BRIGHTENED: Increased camera exposure to let more overall light in
	env_settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env_settings.tonemap_exposure = 1.05 # Previously 0.9
	
	# --- POST-PROCESSING ---
	env_settings.adjustment_enabled = true
	# BRIGHTENED: Lowered contrast to stop crushing the shadows
	env_settings.adjustment_contrast = 1.25 # Previously 1.45
	env_settings.adjustment_saturation = 0.55   
	
	env_settings.glow_enabled = true
	env_settings.glow_intensity = 2.0
	env_settings.glow_bloom = 0.3
	env_settings.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	
	# BRIGHTENED: Lowered SSAO so crevices and the underside of the car are visible
	env_settings.ssao_enabled = true
	env_settings.ssao_radius = 1.5
	env_settings.ssao_intensity = 2.0 # Previously 4.0
	
	# --- DIRTY SMOG ---
	env_settings.volumetric_fog_enabled = true
	env_settings.volumetric_fog_density = 0.012 
	env_settings.volumetric_fog_albedo = Color(0.25, 0.22, 0.18) 
	env_settings.volumetric_fog_emission = Color(0.05, 0.05, 0.05)

	# 4. Generate the WorldEnvironment Node
	var world_env = WorldEnvironment.new()
	world_env.name = "GeneratedWorldEnv"
	world_env.environment = env_settings
	add_child(world_env)
