extends Node
## Small, offline-first save system. No account or backend is required.
## Writes to a temporary file and keeps a backup so interrupted writes can recover.

var save_path: String = "user://gully_dash_save.cfg"
var temp_path: String = "user://gully_dash_save.tmp"
var backup_path: String = "user://gully_dash_save.bak"
const SAVE_VERSION: int = 1

const SKIN_PRICES: Dictionary = {
	"classic": 0,
	"blue": 100,
	"pink": 200,
}

const MISSIONS: Dictionary = {
	"collect_25": {"goal": 25, "reward": 30, "stat": "lifetime_coins"},
	"distance_1000": {"goal": 1000, "reward": 40, "stat": "lifetime_distance_m"},
	"play_5": {"goal": 5, "reward": 25, "stat": "lifetime_runs"},
}

signal data_changed

var best_score: int = 0
var bank_coins: int = 0
var lifetime_coins: int = 0
var lifetime_distance_m: int = 0
var lifetime_runs: int = 0
var lifetime_powerups: int = 0
var unlocked_skins: Array[String] = ["classic"]
var selected_skin: StringName = &"classic"
var claimed_missions: Array[String] = []


func _ready() -> void:
	_load_data()


## Allows isolated save locations for tests, migrations and future profile separation.
func set_storage_paths(primary_path: String, temporary_path: String, backup_file_path: String, reload_now: bool = false) -> void:
	if primary_path.is_empty() or temporary_path.is_empty() or backup_file_path.is_empty():
		push_error("Save paths must not be empty.")
		return
	save_path = primary_path
	temp_path = temporary_path
	backup_path = backup_file_path
	if reload_now:
		_load_data()


func record_run(final_score: int, earned_coins: int, distance_m: int, powerups_used: int) -> Array[String]:
	## Commit run results once from the game coordinator. The caller owns the
	## exactly-once guard; values are clamped here as a second line of defense.
	var safe_score: int = maxi(0, final_score)
	var safe_coins: int = clampi(earned_coins, 0, 100000)
	var safe_distance: int = clampi(distance_m, 0, 10000000)
	var safe_powerups: int = clampi(powerups_used, 0, 1000)

	best_score = maxi(best_score, safe_score)
	bank_coins = clampi(bank_coins + safe_coins, 0, 2000000000)
	lifetime_coins = clampi(lifetime_coins + safe_coins, 0, 2000000000)
	lifetime_distance_m = clampi(lifetime_distance_m + safe_distance, 0, 2000000000)
	lifetime_runs = clampi(lifetime_runs + 1, 0, 2000000000)
	lifetime_powerups = clampi(lifetime_powerups + safe_powerups, 0, 2000000000)

	var newly_completed: Array[String] = _award_completed_missions()
	_save_data()
	data_changed.emit()
	return newly_completed


func get_mission_progress(mission_id: String) -> Dictionary:
	if not MISSIONS.has(mission_id):
		return {"goal": 0, "progress": 0, "reward": 0, "completed": false}

	var mission: Dictionary = MISSIONS[mission_id]
	var stat_name: String = String(mission["stat"])
	var progress: int = int(get(stat_name))
	var goal: int = int(mission["goal"])
	return {
		"goal": goal,
		"progress": mini(progress, goal),
		"reward": int(mission["reward"]),
		"completed": claimed_missions.has(mission_id),
		"ready_to_claim": progress >= goal and not claimed_missions.has(mission_id)
	}


func buy_or_select_skin(skin_id: StringName) -> bool:
	var key: String = String(skin_id)
	if not SKIN_PRICES.has(key):
		return false

	if unlocked_skins.has(key):
		selected_skin = skin_id
		_save_data()
		data_changed.emit()
		return true

	var price: int = int(SKIN_PRICES[key])
	if bank_coins < price:
		return false

	bank_coins -= price
	unlocked_skins.append(key)
	selected_skin = skin_id
	_save_data()
	data_changed.emit()
	return true


func is_skin_unlocked(skin_id: StringName) -> bool:
	return unlocked_skins.has(String(skin_id))


func skin_price(skin_id: StringName) -> int:
	return int(SKIN_PRICES.get(String(skin_id), -1))


func _award_completed_missions() -> Array[String]:
	var completed_now: Array[String] = []
	for mission_id in MISSIONS.keys():
		var id: String = String(mission_id)
		if claimed_missions.has(id):
			continue
		var progress: Dictionary = get_mission_progress(id)
		if int(progress["progress"]) >= int(progress["goal"]):
			claimed_missions.append(id)
			var reward: int = int(progress["reward"])
			bank_coins = clampi(bank_coins + reward, 0, 2000000000)
			completed_now.append(id)
	return completed_now


func _load_data() -> void:
	var config := ConfigFile.new()
	var err: Error = config.load(save_path)
	var primary_valid: bool = err == OK and int(config.get_value("meta", "version", -1)) == SAVE_VERSION

	if not primary_valid:
		# A parse error OR an incompatible primary can recover from a valid backup.
		var backup := ConfigFile.new()
		var backup_error: Error = backup.load(backup_path)
		var backup_valid: bool = backup_error == OK and int(backup.get_value("meta", "version", -1)) == SAVE_VERSION
		if backup_valid:
			config = backup
			err = OK
		else:
			err = ERR_FILE_CORRUPT

	if err == OK and int(config.get_value("meta", "version", -1)) == SAVE_VERSION:
		best_score = maxi(0, int(config.get_value("stats", "best_score", 0)))
		bank_coins = maxi(0, int(config.get_value("stats", "bank_coins", 0)))
		lifetime_coins = maxi(0, int(config.get_value("stats", "lifetime_coins", 0)))
		lifetime_distance_m = maxi(0, int(config.get_value("stats", "lifetime_distance_m", 0)))
		lifetime_runs = maxi(0, int(config.get_value("stats", "lifetime_runs", 0)))
		lifetime_powerups = maxi(0, int(config.get_value("stats", "lifetime_powerups", 0)))

		var loaded_skins: Variant = config.get_value("cosmetics", "unlocked_skins", ["classic"])
		unlocked_skins.clear()
		if loaded_skins is Array:
			for skin in loaded_skins:
				var skin_id := String(skin)
				if SKIN_PRICES.has(skin_id) and not unlocked_skins.has(skin_id):
					unlocked_skins.append(skin_id)
		if not unlocked_skins.has("classic"):
			unlocked_skins.push_front("classic")

		var loaded_skin := String(config.get_value("cosmetics", "selected_skin", "classic"))
		selected_skin = StringName(loaded_skin if unlocked_skins.has(loaded_skin) else "classic")

		var loaded_claims: Variant = config.get_value("missions", "claimed", [])
		claimed_missions.clear()
		if loaded_claims is Array:
			for mission_id in loaded_claims:
				if MISSIONS.has(String(mission_id)) and not claimed_missions.has(String(mission_id)):
					claimed_missions.append(String(mission_id))
	else:
		# If this was a new install or an incompatible version, start clean.
		_reset_defaults()
		_save_data()

	data_changed.emit()


func _reset_defaults() -> void:
	best_score = 0
	bank_coins = 0
	lifetime_coins = 0
	lifetime_distance_m = 0
	lifetime_runs = 0
	lifetime_powerups = 0
	unlocked_skins = ["classic"]
	selected_skin = &"classic"
	claimed_missions = []


func _save_data() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "version", SAVE_VERSION)
	config.set_value("stats", "best_score", best_score)
	config.set_value("stats", "bank_coins", bank_coins)
	config.set_value("stats", "lifetime_coins", lifetime_coins)
	config.set_value("stats", "lifetime_distance_m", lifetime_distance_m)
	config.set_value("stats", "lifetime_runs", lifetime_runs)
	config.set_value("stats", "lifetime_powerups", lifetime_powerups)
	config.set_value("cosmetics", "unlocked_skins", unlocked_skins)
	config.set_value("cosmetics", "selected_skin", String(selected_skin))
	config.set_value("missions", "claimed", claimed_missions)

	var err: Error = config.save(temp_path)
	if err != OK:
		push_error("Could not write temporary save file: %s" % error_string(err))
		return

	var primary_path: String = ProjectSettings.globalize_path(save_path)
	var temp_path: String = ProjectSettings.globalize_path(temp_path)
	var backup_path: String = ProjectSettings.globalize_path(backup_path)

	# Keep one previous known-good save. If the primary is corrupt, do not
	# overwrite the good backup with the corrupt file.
	var primary_valid: bool = false
	if FileAccess.file_exists(save_path):
		var existing := ConfigFile.new()
		var existing_error: Error = existing.load(save_path)
		primary_valid = existing_error == OK and int(existing.get_value("meta", "version", -1)) == SAVE_VERSION

	if primary_valid:
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		err = DirAccess.rename_absolute(primary_path, backup_path)
		if err != OK:
			push_error("Could not rotate save file to backup: %s" % error_string(err))
			return
	elif FileAccess.file_exists(save_path):
		err = DirAccess.remove_absolute(primary_path)
		if err != OK:
			push_error("Could not remove invalid primary save: %s" % error_string(err))
			return

	err = DirAccess.rename_absolute(temp_path, primary_path)
	if err != OK:
		push_error("Could not commit save file: %s" % error_string(err))
		if FileAccess.file_exists(backup_path) and not FileAccess.file_exists(save_path):
			DirAccess.rename_absolute(backup_path, primary_path)
		return
