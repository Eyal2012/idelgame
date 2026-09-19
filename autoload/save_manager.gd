extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")

## SaveManager
##
## Architecture for save/load with versioning and migration support.
##
## Stage 0: foundation only. No actual save data is stored yet.
## The save format will be defined when gameplay state exists.

## Current save format version. Bump this when the save schema changes.
const SAVE_VERSION: int = 1

## Path used for the primary save file.
const SAVE_PATH: String = "user://save.dat"

## Path used for backup saves (e.g. before risky operations).
const BACKUP_PATH: String = "user://save_backup.dat"

## Maximum number of backup generations to keep.
const MAX_BACKUPS: int = 3


func _ready() -> void:
	# Ensure the save directory exists.
	var dir = DirAccess.open("user://")
	if dir == null:
		var root = DirAccess.open("/")
		if root != null:
			root.make_dir_recursive("user://")


## Serialize the current session into a save dictionary.
##
## Returns a dict with at least:
##   - "version": int
##   - "timestamp": int (unix seconds)
##   - "state": Variant (game-specific data)
func build_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"timestamp": int(Time.get_unix_time_from_system()),
		"state": _collect_state(),
	}


## Persist the current save data to disk.
func save() -> bool:
	var data: Dictionary = build_save_data()
	var packed: PackedByteArray = var_to_bytes(data)
	var err: Error = _write_file(SAVE_PATH, packed)
	var success: bool = (err == OK)
	_emit_save_completed(success)
	return success


## Load save data from disk and return it, or empty dict on failure.
func load_save() -> Dictionary:
	var packed: PackedByteArray = _read_file(SAVE_PATH)
	if packed.is_empty():
		return {}
	var data = bytes_to_var(packed)
	if not data is Dictionary:
		return {}
	# Migration hook: if the save version is older, migrate before applying.
	data = migrate_save(data)
	return data


## Create a backup of the current save file.
func backup_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var src = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if src == null:
		return false
	var data: PackedByteArray = src.get_buffer(src.get_length())
	src.close()
	var err: Error = _write_file(BACKUP_PATH, data)
	return (err == OK)


## Migrate an older save to the current SAVE_VERSION.
##
## Add migration cases here as the save schema evolves:
##   if data.get("version", 0) < CURRENT:
##       data = _migrate_xxx(data)
func migrate_save(data: Dictionary) -> Dictionary:
	var ver: int = int(data.get("version", 0))
	if ver >= SAVE_VERSION:
		return data
	# Future migrations go here. For now, just stamp the current version.
	data["version"] = SAVE_VERSION
	return data


## Collect runtime state from Game (and other systems) for saving.
func _collect_state() -> Dictionary:
	var state: Dictionary = {}
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if game != null:
		if game.has_method("get_state"):
			state["game"] = game.get_state()
	return state


## Write raw bytes to a file, creating directories as needed.
func _write_file(path: String, data: PackedByteArray) -> Error:
	var dir_path: String = path.get_base_dir()
	var check = DirAccess.open(dir_path)
	if check == null:
		var parent = DirAccess.open("/")
		if parent != null:
			parent.make_dir_recursive(dir_path)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ERR_CANT_OPEN
	file.store_buffer(data)
	file.close()
	return OK


## Read raw bytes from a file. Returns empty PackedByteArray on failure.
func _read_file(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var data: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	return data


## Emit save_completed through EventBus (decoupled).
func _emit_save_completed(success: bool) -> void:
	var eb := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if eb != null:
		eb.save_completed.emit(success)
