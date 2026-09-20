extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")

## Reusable presentation-only registry. Future puzzles can pair any normal
## Control with a hidden sibling/overlay and get drift-free SHIFT transforms.
var _pairs: Array[Dictionary] = []
var _active: bool = false
var _test_override_enabled: bool = false
var _test_override_value: bool = false


func _process(_delta: float) -> void:
	var wants_shift := _test_override_value if _test_override_enabled else Input.is_key_pressed(KEY_SHIFT)
	set_shift_active(wants_shift and is_shift_available())


func register_shift_pair(normal_element: Control, hidden_element: Control, offset: Vector2 = Vector2(8.0, -6.0)) -> void:
	if normal_element == null or hidden_element == null:
		return
	for pair in _pairs:
		if pair.normal == normal_element:
			return
	_pairs.append({"normal": normal_element, "hidden": hidden_element, "base_position": normal_element.position, "offset": Vector2.ZERO})
	hidden_element.visible = false


func unregister_shift_pair(normal_element: Control) -> void:
	for index in range(_pairs.size() - 1, -1, -1):
		var pair: Dictionary = _pairs[index]
		if pair.normal == normal_element:
			_restore_pair(pair)
			_pairs.remove_at(index)


func is_shift_available() -> bool:
	var story := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"story_manager")
	return story != null and bool(story.get_flag(&"shift_state_unlocked", false))


func is_shift_active() -> bool:
	return _active


func set_shift_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	for pair in _pairs:
		_apply_pair(pair)
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus != null:
		event_bus.shift_state_changed.emit(_active)


## Development hook used only by isolated validators.
func set_shift_active_for_test(active: bool) -> void:
	_test_override_enabled = true
	_test_override_value = active
	set_shift_active(active and is_shift_available())


func clear_test_override() -> void:
	_test_override_enabled = false


func _apply_pair(pair: Dictionary) -> void:
	var normal := pair.normal as Control
	var hidden := pair.hidden as Control
	if not is_instance_valid(normal) or not is_instance_valid(hidden):
		return
	# SHIFT is an alternate diagnostic state, never a layout transform.
	normal.position = pair.base_position
	hidden.visible = _active
	if hidden.has_method("set_shift_active"):
		hidden.set_shift_active(_active)


func _restore_pair(pair: Dictionary) -> void:
	var normal := pair.normal as Control
	var hidden := pair.hidden as Control
	if is_instance_valid(normal):
		normal.position = pair.base_position
	if is_instance_valid(hidden):
		hidden.visible = false
