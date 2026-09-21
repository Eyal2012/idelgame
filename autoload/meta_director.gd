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
var _first_anomaly_active: bool = false
var _first_anomaly_elapsed: float = 0.0
var _first_anomaly_step: int = 0

const FIRST_ANOMALY_EVENT_ID: StringName = &"first_anomaly"
const ANOMALY_REQUIRED_BITS: float = 50.0
const ANOMALY_REQUIRED_GENERATOR: StringName = &"terminal"


func _ready() -> void:
	# Connect to game reset so active events get cancelled.
	_connect_signals()


func _process(delta: float) -> void:
	_check_first_anomaly_condition()
	var memory := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"memory_puzzle")
	if memory != null:
		memory.try_trigger()
	_update_first_anomaly(delta)
	update(delta)


## The condition is evaluated outside presentation and starts only once per save.
func _check_first_anomaly_condition() -> void:
	if _first_anomaly_active or _is_first_anomaly_complete():
		return
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if game != null and game.get_generator_count(ANOMALY_REQUIRED_GENERATOR) >= 1 and game.get_currency() >= ANOMALY_REQUIRED_BITS:
		start_first_anomaly()


func start_first_anomaly() -> bool:
	if _first_anomaly_active or _is_first_anomaly_complete():
		return false
	var story := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"story_manager")
	if story == null:
		return false
	story.set_flag(&"first_anomaly_started", true)
	_first_anomaly_active = true
	_first_anomaly_elapsed = 0.0
	_first_anomaly_step = 0
	_emit_meta_event_started(FIRST_ANOMALY_EVENT_ID)
	_emit_log("SCHEDULER CHECK...")
	return true


## Debug-only route for the developer panel. This still uses the normal event
## sequence instead of making UI code reproduce anomaly timing or rewards.
func debug_force_first_anomaly() -> bool:
	return start_first_anomaly() if OS.is_debug_build() else false


func is_first_anomaly_active() -> bool:
	return _first_anomaly_active


func _update_first_anomaly(delta: float) -> void:
	if not _first_anomaly_active:
		return
	_first_anomaly_elapsed += delta
	if _first_anomaly_step == 0 and _first_anomaly_elapsed >= 0.55:
		_first_anomaly_step = 1
		_emit_log("EXTERNAL INPUT SOURCE DETECTED")
	elif _first_anomaly_step == 1 and _first_anomaly_elapsed >= 1.10:
		_first_anomaly_step = 2
		_emit_log("PROCESS TABLE MISMATCH")
	elif _first_anomaly_step == 2 and _first_anomaly_elapsed >= 1.65:
		_first_anomaly_step = 3
		_emit_log("1 PROCESS UNACCOUNTED FOR")
		_emit_anomaly_visual()
	elif _first_anomaly_step == 3 and _first_anomaly_elapsed >= 2.20:
		_first_anomaly_step = 4
		_emit_log("ATTEMPTING PROCESS REALIGNMENT...")
	elif _first_anomaly_step == 4 and _first_anomaly_elapsed >= 2.70:
		_first_anomaly_step = 5
		var story := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"story_manager")
		if story != null:
			story.set_flag(&"shift_state_unlocked", true)
		_emit_log("SHIFT STATE // AVAILABLE")
		_first_anomaly_active = false
		_emit_meta_event_finished(FIRST_ANOMALY_EVENT_ID)


func _is_first_anomaly_complete() -> bool:
	var story := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"story_manager")
	return story != null and bool(story.get_flag(&"first_anomaly_started", false))


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
	_first_anomaly_active = false


func _emit_log(message: String) -> void:
	var eb := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if eb != null:
		eb.system_log_message.emit(message)


func _emit_anomaly_visual() -> void:
	var eb := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if eb != null:
		eb.anomaly_visual_requested.emit()


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
