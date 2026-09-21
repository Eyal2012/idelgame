extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")

## StoryManager
##
## Owns generic story flags and the current chapter.
##
## Stage 0: foundation only. No actual story content yet.
## Flags are stored as a simple dictionary so they can be saved/loaded.

## Current chapter id. Empty string means "no chapter".
var current_chapter: StringName = StringName()

## All known story flags. Values are Variant (bool, int, float, string).
var _flags: Dictionary = {}

const FIRST_ANOMALY_STARTED: StringName = &"first_anomaly_started"
const SHIFT_STATE_UNLOCKED: StringName = &"shift_state_unlocked"
const OPERATOR_DISCOVERED: StringName = &"operator_discovered"
const DEFAULT_FLAGS: Dictionary = {
	FIRST_ANOMALY_STARTED: false,
	SHIFT_STATE_UNLOCKED: false,
	OPERATOR_DISCOVERED: false,
	&"memory_failure_started": false,
	&"memory_failure_completed": false,
	&"operator_write_detected": false,
}


func _ready() -> void:
	_reset_defaults()


## Set a story flag, emitting story_flag_changed if the value changes.
func set_flag(flag_id: StringName, value: Variant) -> void:
	var old_value = _flags.get(flag_id, null)
	_flags[flag_id] = value
	if old_value != value:
		_emit_story_flag_changed(flag_id, old_value, value)


## Get a story flag, returning default_value if not set.
func get_flag(flag_id: StringName, default_value: Variant = null) -> Variant:
	return _flags.get(flag_id, default_value)


## Return true if the flag is set (exists in the flag dictionary).
func has_flag(flag_id: StringName) -> bool:
	return _flags.has(flag_id)


## Set the current chapter, emitting story_chapter_started on change.
func set_chapter(chapter_id: StringName) -> void:
	if current_chapter == chapter_id:
		return
	current_chapter = chapter_id
	_emit_story_chapter_started(chapter_id)


## Return a snapshot of all flags (for save/load).
func get_flags() -> Dictionary:
	return _flags.duplicate()


## Restore flags from a saved snapshot.
func set_flags(flags: Dictionary) -> void:
	_flags.clear()
	_reset_defaults()
	for raw_id in flags:
		var flag_id := StringName(raw_id)
		if DEFAULT_FLAGS.has(flag_id):
			_flags[flag_id] = bool(flags[raw_id])


func get_save_data() -> Dictionary:
	return {"flags": get_flags(), "current_chapter": String(current_chapter)}


func apply_save_data(data: Dictionary) -> void:
	set_flags(data.get("flags", {}) if data.get("flags", {}) is Dictionary else {})
	current_chapter = StringName(data.get("current_chapter", ""))


## Clear all story state (used on game reset).
func clear() -> void:
	_flags.clear()
	_reset_defaults()
	current_chapter = StringName()


## Debug-only entry points keep developer tools from depending on private flags.
func debug_set_flag(flag_id: StringName, value: Variant) -> bool:
	if not OS.is_debug_build() or not DEFAULT_FLAGS.has(flag_id):
		return false
	set_flag(flag_id, value)
	return true


func debug_apply_state(flags: Dictionary, chapter_id: StringName = &"") -> bool:
	if not OS.is_debug_build():
		return false
	clear()
	for raw_id in flags:
		debug_set_flag(StringName(raw_id), flags[raw_id])
	if not chapter_id.is_empty():
		set_chapter(chapter_id)
	return true


func debug_reset_story() -> bool:
	if not OS.is_debug_build():
		return false
	clear()
	return true


func _reset_defaults() -> void:
	for flag_id in DEFAULT_FLAGS:
		if not _flags.has(flag_id):
			_flags[flag_id] = DEFAULT_FLAGS[flag_id]


## Emit story_flag_changed through EventBus (decoupled).
func _emit_story_flag_changed(flag_id: StringName, old_value: Variant, new_value: Variant) -> void:
	var eb := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if eb != null:
		eb.story_flag_changed.emit(flag_id, old_value, new_value)


## Emit story_chapter_started through EventBus (decoupled).
func _emit_story_chapter_started(chapter_id: StringName) -> void:
	var eb := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if eb != null:
		eb.story_chapter_started.emit(chapter_id)
