extends Area3D

@export var star_1_speed: int = 70
@export var star_2_speed: int = 120
@export var star_3_speed: int = 150

var is_active = true

func _ready():
	add_to_group("speed_traps")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if not is_active: return
	
	if body.name == "PlayerCar" or body is CharacterBody3D:
		var ui = body.get_node_or_null("SpeedTrapUI")
		if ui:
			var horiz_vel = Vector3(body.velocity.x, 0, body.velocity.z)
			var is_mph = body.get("is_mph")
			if is_mph == null: is_mph = false
			
			var mult = 2.23694 if is_mph else 3.6
			var unit = "MPH" if is_mph else "KMH"
			var speed_val = int(horiz_vel.length() * mult)
			
			# 1. Calculate the base performance
			var stars = 0
			var base_reward = 0
			
			if speed_val >= star_3_speed: 
				stars = 3
				base_reward = 50
			elif speed_val >= star_2_speed: 
				stars = 2
				base_reward = 25
			elif speed_val >= star_1_speed: 
				stars = 1
				base_reward = 10
			
			# 2. Process Economy and Anti-Farming Logic
			if stars > 0:
				var past_stats = SaveSystem.get_trap_stats(self.name)
				var is_repeat = past_stats.stars > 0 # If they have ANY stars on record, it's a repeat
				
				var final_reward = base_reward
				if is_repeat:
					final_reward = int(base_reward * 0.25) # 75% Penalty for farming
					
				SaveSystem.add_credits(final_reward)
				SaveSystem.save_speed_trap(self.name, speed_val, stars)
			
			ui.trigger_trap(speed_val, star_1_speed, star_2_speed, star_3_speed, unit)
			
			# 3. Apply the 10-Second Anti-Spam Cooldown
			is_active = false
			await get_tree().create_timer(10.0).timeout
			is_active = true
