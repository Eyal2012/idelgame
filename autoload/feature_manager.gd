extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")

## FeatureManager
##
## Generic feature unlock/lock system.
##
## Future systems can check things such as:
##   shop, upgrades, prestige, achievements, statistics,
##   story, secret_menu, developer_console
##
## Conceptually:
##   is_unlocked(feature_id)
##   unlock(feature_id)
##   lock(feature_id)
##
## No UI behavior is hard-coded here. UI listens to feature_unlocked /
## feature_locked signals via EventBus.

## Set of feature ids that are currently unlocked.
var _unlocked: Dictionary = {}


func _ready() -> void:
	# Connect to game reset to lock all features.
	var eb := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if eb != null:
		if not eb.is_connected("game_reset", _on_game_reset):
			eb.game_reset.connect(_on_game_reset)


## Return true if the feature is unlocked.
func is_unlocked(feature_id: StringName) -> bool:
	return _unlocked.has(feature_id)


## Unlock a feature. Idempotent.
func unlock(feature_id: StringName) -> void:
	if _unlocked.has(feature_id):
		return
	_unlocked[feature_id] = true
	_emit_feature_changed(feature_id, true)


## Lock a feature. Idempotent.
func lock(feature_id: StringName) -> void:
	if not _unlocked.has(feature_id):
		return
	_unlocked.erase(feature_id)
	_emit_feature_changed(feature_id, false)


## Lock all features (used on game reset).
func _on_game_reset() -> void:
	var ids := _unlocked.keys()
	_unlocked.clear()
	for id in ids:
		_emit_feature_changed(id, false)


## Emit the appropriate EventBus signal for a feature change.
func _emit_feature_changed(feature_id: StringName, unlocked: bool) -> void:
	var eb := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if eb == null:
		return
	if unlocked:
		eb.feature_unlocked.emit(feature_id)
	else:
		eb.feature_locked.emit(feature_id)


## Return a snapshot of all currently unlocked feature ids.
func get_unlocked() -> Array:
	return _unlocked.keys()


## Restore unlocked features from a saved snapshot.
func set_unlocked(ids: Array) -> void:
	_unlocked.clear()
	for id in ids:
		_unlocked[id] = true
