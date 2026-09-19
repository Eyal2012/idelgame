extends Node

## WindowManager
##
## Safe abstraction for future window-related mechanics.
##
## Stage 0: does NOT move, resize, or otherwise manipulate the real window.
## Only exposes clean helper architecture and tracks relevant window info.

## Whether the game window currently has focus.
var window_has_focus: bool = true

## Current window size in pixels (informational).
var window_size: Vector2i = Vector2i.ZERO

## Whether the game is currently running in the editor (informational).
var in_editor: bool = false


func _ready() -> void:
	# Capture initial window info if available.
	var window = get_window()
	if window != null:
		window_size = window.size
		window_has_focus = window.has_focus()


## Return true if the game window has input focus.
func has_focus() -> bool:
	return window_has_focus


## Set focus state (called from signals or tests).
func set_focus(focused: bool) -> void:
	window_has_focus = focused


## Update cached window size.
func set_size(size: Vector2i) -> void:
	window_size = size


## Return the current window size.
func get_size() -> Vector2i:
	return window_size


## Simulate a window focus change (safe, no OS interaction).
## Used by meta events that want to fake a focus loss.
func simulate_focus_loss() -> void:
	set_focus(false)


## Restore focus after a simulated focus loss.
func simulate_focus_restore() -> void:
	set_focus(true)