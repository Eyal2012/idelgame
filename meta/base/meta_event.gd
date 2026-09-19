extends Resource

## MetaEvent
##
## Base class for all fourth-wall-breaking events.
##
## Every event follows a predictable lifecycle:
##   can_start() -> start() -> update() -> complete()/cancel() -> cleanup()
##
## MetaDirector does NOT need to know how individual events work.
## It only calls these methods. Events are responsible for cleaning up
## everything they change in cleanup().
##
## Events should be created as Resources (res://meta/events/*.tres)
## and registered in ContentDB under the "meta_events" resource type.

## Stable id for this event. Must be unique.
@export var id: StringName = StringName()

## Human-readable name (informational only; never used as an identifier).
@export var display_name: String = ""

## Whether this event is currently active.
var _active: bool = false

## Whether this event has completed successfully.
var _completed: bool = false


## Return true if this event is allowed to start right now.
## Override in subclasses. Default: true.
func can_start() -> bool:
	return true


## Begin the event. Override in subclasses.
## Do NOT clean up here; cleanup() is always called afterwards.
func start() -> void:
	_active = true
	_completed = false


## Per-frame update while active. Override in subclasses.
func update(delta: float) -> void:
	pass


## Mark the event as completed. Call this from update() when done.
func complete() -> void:
	_completed = true


## Cancel the event (e.g. on game reset). Override if you need to undo progress.
func cancel() -> void:
	_active = false


## Clean up everything this event changed. ALWAYS called after complete()/cancel().
## Override in subclasses to undo any modifications to Game state, UI, etc.
func cleanup() -> void:
	_active = false
	_completed = false


## Return true if the event is currently active.
func is_active() -> bool:
	return _active


## Return true if the event has completed.
func is_completed() -> bool:
	return _completed