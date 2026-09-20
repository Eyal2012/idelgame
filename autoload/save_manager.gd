extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")

## Versioned, JSON persistence for runtime gameplay state.
const SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://save.json"
const BACKUP_PATH: String = "user://save_backup.json"
const TEMP_PATH: String = "user://save.tmp"
const AUTOSAVE_INTERVAL_SECONDS: float = 12.0
const MAX_OFFLINE_SECONDS: int = 24 * 60 * 60

var last_offline_seconds: int = 0
var last_offline_earnings: float = 0.0
var _primary_path: String = SAVE_PATH
var _backup_path: String = BACKUP_PATH
var _temp_path: String = TEMP_PATH
var _autosave_elapsed: float = 0.0
var _has_loaded_session: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_initial_load")


func _initial_load() -> void:
	# Tool scenes manage explicit isolated paths themselves.
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path.begins_with("res://tools/Validate"):
		return
	load_game()


func _process(delta: float) -> void:
	_autosave_elapsed += delta
	if _autosave_elapsed >= AUTOSAVE_INTERVAL_SECONDS:
		_autosave_elapsed = 0.0
		save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		if _has_loaded_session:
			save()


func build_save_data() -> Dictionary:
	var game := _get_game()
	return {
		"save_version": SAVE_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"game": game.get_save_data() if game != null else {"bits": 0.0, "generator_counts": {}},
	}


func save() -> bool:
	_emit_save_started()
	var encoded := JSON.stringify(build_save_data(), "\t")
	var success := _safe_write(_primary_path, _backup_path, _temp_path, encoded)
	_emit_save_completed(success)
	return success


## Loads exactly once during normal startup. Explicit calls are safe and do not
## award the same offline interval twice because a later load reads a new save.
func load_game() -> bool:
	_emit_load_started()
	last_offline_seconds = 0
	last_offline_earnings = 0.0
	var loaded := _read_valid_save(_primary_path)
	if loaded.is_empty():
		loaded = _read_valid_save(_backup_path)
		if not loaded.is_empty():
			push_warning("Primary save was unusable; recovered from backup.")
	var game := _get_game()
	if game == null:
		_emit_load_completed(false)
		return false
	if loaded.is_empty():
		push_warning("No usable save found; starting a fresh game.")
		game.reset_save_data()
		_has_loaded_session = true
		_emit_load_completed(false)
		return false
	var normalized := migrate_save(loaded)
	game.apply_save_data(normalized.get("game", {}))
	_apply_offline_progress(game, int(normalized.get("saved_at_unix", 0)))
	_has_loaded_session = true
	_emit_load_completed(true)
	return true


## Migration dispatch is sequential: add one function per future transition.
func migrate_save(data: Dictionary) -> Dictionary:
	var migrated := data.duplicate(true)
	var version := _sanitize_version(migrated.get("save_version", 0))
	while version < SAVE_VERSION:
		match version:
			0:
				migrated = _migrate_v0_to_v1(migrated)
			_:
				break
		version = _sanitize_version(migrated.get("save_version", SAVE_VERSION))
	if version > SAVE_VERSION:
		push_warning("Save version is newer than this build; loading known fields only.")
	migrated["save_version"] = SAVE_VERSION
	migrated["saved_at_unix"] = max(0, int(migrated.get("saved_at_unix", 0)))
	if not migrated.get("game", {}) is Dictionary:
		migrated["game"] = {}
	return migrated


func _migrate_v0_to_v1(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	result["game"] = result.get("game", result.get("state", {}))
	result["saved_at_unix"] = result.get("saved_at_unix", result.get("timestamp", 0))
	result["save_version"] = 1
	return result


## Validator injection: never point tests at the player's default files.
func set_test_paths(primary_path: String, backup_path: String, temp_path: String = "") -> void:
	_primary_path = primary_path
	_backup_path = backup_path
	_temp_path = temp_path if not temp_path.is_empty() else primary_path + ".tmp"


func restore_default_paths() -> void:
	_primary_path = SAVE_PATH
	_backup_path = BACKUP_PATH
	_temp_path = TEMP_PATH
	# Test sessions explicitly restore defaults after cleanup; do not let their
	# shutdown notification create or overwrite a player save.
	_has_loaded_session = false


func reset_save(include_backup: bool = true) -> void:
	_remove_if_exists(_primary_path)
	_remove_if_exists(_temp_path)
	if include_backup:
		_remove_if_exists(_backup_path)
	var game := _get_game()
	if game != null:
		game.reset_save_data()


func _apply_offline_progress(game: Node, saved_at: int) -> void:
	var elapsed: int = max(0, int(Time.get_unix_time_from_system()) - max(0, saved_at))
	last_offline_seconds = min(elapsed, MAX_OFFLINE_SECONDS)
	last_offline_earnings = game.get_total_production_per_second() * last_offline_seconds
	if last_offline_earnings > 0.0:
		game.add_currency(last_offline_earnings)


func _safe_write(primary: String, backup: String, temp: String, encoded: String) -> bool:
	if _write_text(temp, encoded) != OK or _read_valid_save(temp).is_empty():
		_remove_if_exists(temp)
		return false
	var existing := _read_valid_save(primary)
	if not existing.is_empty() and not _copy_file(primary, backup + ".tmp"):
		_remove_if_exists(temp)
		return false
	if not existing.is_empty():
		_remove_if_exists(backup)
		if DirAccess.rename_absolute(backup + ".tmp", backup) != OK:
			_remove_if_exists(temp)
			return false
	_remove_if_exists(primary)
	if DirAccess.rename_absolute(temp, primary) != OK:
		return false
	return true


func _read_valid_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}
	var parsed = json.data
	file.close()
	if not parsed is Dictionary:
		return {}
	# Permit the foundation-era v0 shape so migrate_save() remains the one route
	# for every supported historical format.
	if not (parsed.has("save_version") or parsed.has("version")):
		return {}
	if not (parsed.has("saved_at_unix") or parsed.has("timestamp")):
		return {}
	if not (parsed.get("game", parsed.get("state", {})) is Dictionary):
		return {}
	return parsed


func _write_text(path: String, content: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ERR_CANT_OPEN
	file.store_string(content)
	file.close()
	return OK


func _copy_file(source: String, destination: String) -> bool:
	var input := FileAccess.open(source, FileAccess.READ)
	if input == null:
		return false
	var bytes := input.get_buffer(input.get_length())
	input.close()
	var output := FileAccess.open(destination, FileAccess.WRITE)
	if output == null:
		return false
	output.store_buffer(bytes)
	output.close()
	return not _read_valid_save(destination).is_empty()


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _sanitize_version(value: Variant) -> int:
	return int(value) if value is int or value is float else 0


func _get_game() -> Node:
	return AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")


func _emit_save_started() -> void:
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus != null:
		event_bus.save_started.emit()


func _emit_save_completed(success: bool) -> void:
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus != null:
		event_bus.save_completed.emit(success)


func _emit_load_started() -> void:
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus != null:
		event_bus.load_started.emit()


func _emit_load_completed(success: bool) -> void:
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus != null:
		event_bus.load_completed.emit(success)
