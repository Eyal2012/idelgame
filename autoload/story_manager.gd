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


func _ready() -> void:
	# Initialize with defaults if needed.
	pass


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
	_flags = flags.duplicate()


## Clear all story state (used on game reset).
func clear() -> void:
	_flags.clear()
	current_chapter = StringName()


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
