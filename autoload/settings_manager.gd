extends Node

## SettingsManager
##
## Foundation for user settings. No UI yet.
## Settings are stored in-memory and persisted to a small JSON file.

## Path to the settings file.
const SETTINGS_PATH: String = "user://settings.json"

## All known settings with their default values.
## Add new settings here as they are introduced.
const DEFAULTS := {
	"audio": {
		"master_volume": 1.0,
		"music_volume": 1.0,
		"sound_volume": 1.0,
	},
	"display": {
		"fullscreen": false,
		"vsync": true,
	},
	"gameplay": {
		"auto_save": true,
		"auto_save_interval": 300,
	},
	"accessibility": {
		"text_scale": 1.0,
	},
}

## Current settings (a deep copy of DEFAULTS).
var _settings: Dictionary = {}


func _ready() -> void:
	_settings = _deep_copy(DEFAULTS)
	load_settings()


## Return the full settings dictionary.
func get_settings() -> Dictionary:
	return _settings.duplicate(true)


## Get a nested setting by dotted path, e.g. "audio.master_volume".
func get_setting(path: String, default_value: Variant = null) -> Variant:
	var parts := path.split(".")
	var current: Variant = _settings
	for part in parts:
		if current is Dictionary and current.has(part):
			current = current[part]
		else:
			return default_value
	return current


## Set a nested setting by dotted path. Creates intermediate dicts as needed.
func set_setting(path: String, value: Variant) -> void:
	var parts := path.split(".")
	var current: Dictionary = _settings
	for i in range(parts.size() - 1):
		var part := parts[i]
		if not current.has(part) or not (current[part] is Dictionary):
			current[part] = {}
		current = current[part]
	current[parts[parts.size() - 1]] = value


## Persist settings to disk.
func save_settings() -> void:
	var json := JSON.stringify(_settings)
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(json)
	file.close()


## Load settings from disk, merging into defaults.
func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var json := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(json)
	if parsed is Dictionary:
		_merge_defaults(parsed)


## Merge loaded settings over the defaults so unknown/missing keys stay safe.
func _merge_defaults(loaded: Dictionary) -> void:
	var merged: Dictionary = _deep_copy(DEFAULTS)
	_deep_merge(merged, loaded)
	_settings = merged


## Deep copy a dictionary.
func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for k in value:
			result[k] = _deep_copy(value[k])
		return result
	if value is Array:
		var result := []
		for item in value:
			result.append(_deep_copy(item))
		return result
	return value


## Deep merge source into target (source wins on conflicts).
func _deep_merge(target: Dictionary, source: Dictionary) -> void:
	for k in source:
		if source[k] is Dictionary and target.has(k) and target[k] is Dictionary:
			_deep_merge(target[k], source[k])
		else:
			target[k] = source[k]