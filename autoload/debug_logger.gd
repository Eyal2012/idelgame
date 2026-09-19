extends Node

## DebugLogger
##
## Lightweight development logger with named categories.
##
## Categories:
##   GAME, SAVE, STORY, META, CONTENT
##
## Easy to disable noisy logging later by setting enabled = false.

## Master switch for all logging.
var enabled: bool = true

## Categories that are explicitly silenced.
const SILENCED_CATEGORIES := [
	# Add category names here to silence them, e.g. StringName("CONTENT")
]

## Valid log categories.
const CATEGORIES := {
	"GAME": StringName("GAME"),
	"SAVE": StringName("SAVE"),
	"STORY": StringName("STORY"),
	"META": StringName("META"),
	"CONTENT": StringName("CONTENT"),
	"FEATURE": StringName("FEATURE"),
	"UI": StringName("UI"),
	"NET": StringName("NET"),
}


func _ready() -> void:
	# In the editor, be quieter by default.
	if Engine.is_editor_hint():
		enabled = false


## Log an informational message.
func log_info(category: StringName, message: String) -> void:
	_log(category, "INFO", message)


## Log a warning.
func log_warn(category: StringName, message: String) -> void:
	_log(category, "WARN", message)


## Log an error.
func log_error(category: StringName, message: String) -> void:
	_log(category, "ERROR", message)


## Internal logging implementation.
func _log(category: StringName, level: String, message: String) -> void:
	if not enabled:
		return
	if SILENCED_CATEGORIES.has(category):
		return
	print("[%s] %s: %s" % [category, level, message])


## Convenience: log to GAME category.
func log_game(message: String) -> void:
	log_info(CATEGORIES.GAME, message)


## Convenience: log to SAVE category.
func log_save(message: String) -> void:
	log_info(CATEGORIES.SAVE, message)


## Convenience: log to STORY category.
func log_story(message: String) -> void:
	log_info(CATEGORIES.STORY, message)


## Convenience: log to META category.
func log_meta(message: String) -> void:
	log_info(CATEGORIES.META, message)


## Convenience: log to CONTENT category.
func log_content(message: String) -> void:
	log_info(CATEGORIES.CONTENT, message)