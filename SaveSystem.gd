extends Node

const SAVE_PATH = "user://szybki_turno_save.json"

var data = {
	"accounts": {},
	"last_user": ""
}
var current_user = ""

func _ready():
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()

func load_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed and parsed is Dictionary:
			data = parsed

func save_data():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))

func create_account(username, password, gender):
	if data.accounts.has(username): return "USERNAME ALREADY EXISTS"
	if username.strip_edges() == "" or password.strip_edges() == "": return "FIELDS CANNOT BE EMPTY"
	
	data.accounts[username] = {
		"password": password,
		"gender": gender,
		"settings": {"is_mph": false, "graphics": 2, "retro": false}, 
		"credits": 0, 
		"selected_car": "Basic",
		"owned_cars": ["Basic", "Pigeon"], # NEW: Car Inventory
		"tuning": {"speed": 0, "handling": 0, "drift": 0, "bonus": 0},
		"races": {},
		"speed_traps": {}
	}
	current_user = username
	data.last_user = username
	save_data()
	return "ACCOUNT CREATED!"

func login(username, password):
	if not data.accounts.has(username): return "USER NOT FOUND"
	if data.accounts[username].password != password: return "INCORRECT PASSWORD"
	
	current_user = username
	data.last_user = username
	
	# Failsafes to patch old accounts seamlessly
	if not data.accounts[username].has("settings"):
		data.accounts[username]["settings"] = {"is_mph": false, "graphics": 2, "retro": false}
	if not data.accounts[username]["settings"].has("retro"):
		data.accounts[username]["settings"]["retro"] = false
	if not data.accounts[username].has("credits"):
		data.accounts[username]["credits"] = 0
	if not data.accounts[username].has("selected_car"):
		data.accounts[username]["selected_car"] = "Basic"
	if not data.accounts[username].has("owned_cars"):
		data.accounts[username]["owned_cars"] = ["Basic", "Pigeon"]
	if not data.accounts[username].has("tuning"):
		data.accounts[username]["tuning"] = {"speed": 0, "handling": 0, "drift": 0, "bonus": 0}
		
	save_data()
	return "LOGIN SUCCESSFUL!"

func logout():
	current_user = ""
	data.last_user = ""
	save_data()

# --- CAR SELECTION & STORE MANAGEMENT ---
func set_selected_car(car_name: String):
	if current_user != "":
		data.accounts[current_user]["selected_car"] = car_name
		save_data()

func get_selected_car() -> String:
	if current_user != "" and data.accounts[current_user].has("selected_car"):
		return data.accounts[current_user]["selected_car"]
	return "Basic"

func is_car_owned(car_name: String) -> bool:
	if current_user != "" and data.accounts[current_user].has("owned_cars"):
		return car_name in data.accounts[current_user]["owned_cars"]
	return false

func purchase_car(car_name: String, cost: int) -> bool:
	if current_user == "": return false
	if data.accounts[current_user]["credits"] >= cost:
		data.accounts[current_user]["credits"] -= cost
		data.accounts[current_user]["owned_cars"].append(car_name)
		save_data()
		return true
	return false

# --- ECONOMY & TUNING MANAGEMENT ---
func add_credits(amount: int):
	if current_user != "":
		var final_amount = amount
		if amount > 0:
			var bonus_lvl = get_tune_level("bonus")
			var multiplier = 1.0 + (bonus_lvl * 0.10)
			final_amount = int(amount * multiplier)
			
		data.accounts[current_user]["credits"] += final_amount
		if data.accounts[current_user]["credits"] < 0:
			data.accounts[current_user]["credits"] = 0
		save_data()

func get_credits() -> int:
	if current_user != "" and data.accounts[current_user].has("credits"):
		return data.accounts[current_user]["credits"]
	return 0

func get_tune_level(tune_type: String) -> int:
	if current_user != "" and data.accounts[current_user].has("tuning"):
		return data.accounts[current_user]["tuning"][tune_type]
	return 0

func purchase_tune(tune_type: String, cost: int) -> bool:
	if current_user == "": return false
	if data.accounts[current_user]["credits"] >= cost:
		data.accounts[current_user]["credits"] -= cost
		data.accounts[current_user]["tuning"][tune_type] += 1
		save_data()
		return true
	return false

# --- SETTINGS MANAGEMENT ---
func save_settings(is_mph: bool, graphics: int, retro: bool):
	if current_user == "": return
	data.accounts[current_user]["settings"] = {"is_mph": is_mph, "graphics": graphics, "retro": retro}
	save_data()

func get_settings() -> Dictionary:
	if current_user != "" and data.accounts[current_user].has("settings"):
		return data.accounts[current_user]["settings"]
	return {"is_mph": false, "graphics": 2, "retro": false} 

# --- HIGHSCORE MANAGEMENT ---
func save_race(race_name: String, time: float, stars: int):
	if current_user == "": return 
	var acc = data.accounts[current_user]
	if not acc.races.has(race_name) or acc.races[race_name].time > time:
		acc.races[race_name] = {"time": time, "stars": stars}
		save_data()

func save_speed_trap(trap_name: String, speed: int, stars: int):
	if current_user == "": return 
	var acc = data.accounts[current_user]
	if not acc.speed_traps.has(trap_name) or acc.speed_traps[trap_name].speed < speed:
		acc.speed_traps[trap_name] = {"speed": speed, "stars": stars}
		save_data()

func get_race_stats(race_name: String) -> Dictionary:
	if current_user != "" and data.accounts[current_user].races.has(race_name):
		return data.accounts[current_user].races[race_name]
	return {"stars": 0, "time": 0.0}

func get_trap_stats(trap_name: String) -> Dictionary:
	if current_user != "" and data.accounts[current_user].speed_traps.has(trap_name):
		return data.accounts[current_user].speed_traps[trap_name]
	return {"stars": 0, "speed": 0}
