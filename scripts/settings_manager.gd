extends Node
## Local player preferences. Defaults are deliberately conservative and offline.

const SETTINGS_PATH := "user://gully_dash_settings.cfg"

var sound_enabled: bool = true
var haptics_enabled: bool = true
var reduced_motion: bool = false


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		sound_enabled = bool(config.get_value("accessibility", "sound_enabled", true))
		haptics_enabled = bool(config.get_value("accessibility", "haptics_enabled", true))
		reduced_motion = bool(config.get_value("accessibility", "reduced_motion", false))


func toggle_sound() -> void:
	sound_enabled = not sound_enabled
	_save()


func toggle_haptics() -> void:
	haptics_enabled = not haptics_enabled
	_save()


func toggle_reduced_motion() -> void:
	reduced_motion = not reduced_motion
	_save()


func vibrate(duration_ms: int = 35) -> void:
	if not haptics_enabled or not OS.has_feature("mobile"):
		return
	Input.vibrate_handheld(clampi(duration_ms, 1, 200))


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("accessibility", "sound_enabled", sound_enabled)
	config.set_value("accessibility", "haptics_enabled", haptics_enabled)
	config.set_value("accessibility", "reduced_motion", reduced_motion)
	var err: Error = config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Could not save settings: %s" % error_string(err))
