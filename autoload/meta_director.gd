extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")

## MetaDirector
##
## Controls fourth-wall-breaking events.
##
## Stage 0: foundation only. NO individual event logic here.
## Individual events will inherit from MetaEvent (res://meta/base/meta_event.gd).
## MetaDirector only manages scheduling, lifecycle, and cleanup.

const META_EVENT_BASE := preload("res://meta/base/meta_event.gd")

## Currently active meta event (only one at a time for now).
var _active_event: META_EVENT_BASE = null

## Queue of pending event ids waiting to run.
var _queue: Array = []

## Whether the director is currently updating an event.
var _busy: bool = false


func _ready() -> void:
	# Connect to game reset so active events get cancelled.
	_connect_signals()


## Connect to EventBus signals that should interrupt meta events.
func _connect_signals() -> void:
	var eb := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if eb == null:
		return
	if not eb.is_connected("game_reset", _on_game_reset):
		eb.game_reset.connect(_on_game_reset)


## Attempt to start a meta event by id.
## The event resource is loaded from ContentDB.
func start_event(event_id: StringName) -> bool:
	if _busy:
		_queue.append(event_id)
		return false
	var event := _load_event(event_id)
	if event == null:
		return false
	if not event.can_start():
		return false
	_active_event = event
	_busy = true
	event.start()
	_emit_meta_event_started(event_id)
	return true


## Update the active event (call this from _process or _physics_process).
func update(delta: float) -> void:
	if not _busy or _active_event == null:
		return
	_active_event.update(delta)
	if _active_event.is_completed():
		_complete_current()


## Complete the current event and clean up.
func _complete_current() -> void:
	var event_id: StringName = _active_event.id
	_active_event.complete()
	_active_event.cleanup()
	_active_event = null
	_busy = false
	_emit_meta_event_finished(event_id)
	# Start next queued event if any.
	if not _queue.is_empty():
		var next_id: StringName = _queue.pop_front()
		start_event(next_id)


## Cancel the active event (e.g. on game reset).
func cancel_current() -> void:
	if _active_event == null:
		return
	var event_id: StringName = _active_event.id
	_active_event.cancel()
	_active_event.cleanup()
	_active_event = null
	_busy = false
	_emit_meta_event_cancelled(event_id)


## Load a MetaEvent resource by id from ContentDB.
func _load_event(event_id: StringName) -> META_EVENT_BASE:
	var db := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"content_db")
	if db == null:
		return null
	var events: Dictionary = db.load_resource_type(StringName("meta_events"))
	return events.get(event_id, null)


## Called when the game is reset; cancel any active event.
func _on_game_reset() -> void:
	cancel_current()
	_queue.clear()


## Emit meta_event_started via EventBus (decoupled).
func _emit_meta_event_started(event_id: StringName) -> void:
	var eb := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if eb != null:
		eb.meta_event_started.emit(event_id)


## Emit meta_event_finished via EventBus (decoupled).
func _emit_meta_event_finished(event_id: StringName) -> void:
	var eb := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if eb != null:
		eb.meta_event_finished.emit(event_id)


## Emit meta_event_cancelled via EventBus (decoupled).
func _emit_meta_event_cancelled(event_id: StringName) -> void:
	var eb := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if eb != null:
		eb.meta_event_cancelled.emit(event_id)
