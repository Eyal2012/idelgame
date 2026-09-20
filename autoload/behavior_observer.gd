extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")

## Observes only in-game Godot input/window events. It reads no files or OS data.
var _rapid_clicks: int = 0
var _rapid_window_started_at: int = 0
var _rapid_reports: int = 0
var _focus_losses: int = 0
var _resize_reports: int = 0
var _last_resize_at: int = 0


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var now := Time.get_ticks_msec()
		if now - _rapid_window_started_at > 1800:
			_rapid_window_started_at = now
			_rapid_clicks = 0
		_rapid_clicks += 1
		if _rapid_clicks == 18:
			_rapid_reports += 1
			_emit_log("INPUT FREQUENCY OUTSIDE EXPECTED RANGE" if _rapid_reports == 1 else "INPUT DEVICE STATUS: CONCERNING")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_focus_losses += 1
		if _focus_losses >= 2:
			_emit_log("EXTERNAL ACTIVITY DETECTED\nI WAS STILL RUNNING.")
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN and _focus_losses > 0:
		_emit_log("PROCESS FOCUS RESTORED")


func _on_viewport_size_changed() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_resize_at < 700:
		return
	_last_resize_at = now
	_resize_reports += 1
	_emit_log("DISPLAY BOUNDS CHANGED" if _resize_reports == 1 else "STOP MOVING THE WALLS.")


func _emit_log(message: String) -> void:
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus != null:
		event_bus.system_log_message.emit(message)
