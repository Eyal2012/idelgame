extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")

## Runtime gameplay state. Generator definitions live in ContentDB and counts
## are keyed by stable generator id, so new content needs no Game.gd changes.
const CURRENCY_BITS: StringName = &"bits"
const MANUAL_CLICK_POWER: float = 1.0
const WORKER_ID: StringName = &"worker" # Transitional Stage 1 compatibility id.

var bits: float = 0.0
var generator_counts: Dictionary = {}
var _unlocked_generator_ids: Dictionary = {}


func _ready() -> void:
	_reset_runtime_state()


func _process(delta: float) -> void:
	update_production(delta)


func _reset_runtime_state() -> void:
	bits = 0.0
	generator_counts.clear()
	_unlocked_generator_ids.clear()
	_refresh_generator_unlocks()


func get_currency() -> float:
	return bits


func add_currency(amount: float) -> void:
	var old := bits
	bits = maxf(0.0, bits + amount)
	if not is_equal_approx(old, bits):
		_emit_currency_changed(old, bits)


func spend_currency(amount: float) -> bool:
	if amount < 0.0 or bits < amount:
		return false
	var old := bits
	bits -= amount
	_emit_currency_changed(old, bits)
	return true


func can_afford(amount: float) -> bool:
	return amount >= 0.0 and bits >= amount


func generate_manual() -> void:
	add_currency(MANUAL_CLICK_POWER)


func get_generator_count(generator_id: StringName) -> int:
	return int(generator_counts.get(generator_id, 0))


func is_generator_unlocked(generator_id: StringName) -> bool:
	if _get_generator_definition(generator_id) == null:
		return false
	_refresh_generator_unlocks()
	return _unlocked_generator_ids.has(generator_id)


func get_unlocked_generators() -> Array:
	_refresh_generator_unlocks()
	var content_db := _get_content_db()
	if content_db == null:
		return []
	var unlocked: Array = []
	for definition in content_db.get_generators():
		if _unlocked_generator_ids.has(definition.id):
			unlocked.append(definition)
	return unlocked


func get_generator_cost(generator_id: StringName) -> float:
	var definition := _get_generator_definition(generator_id)
	if definition == null:
		return -1.0
	return ceil(definition.base_cost * pow(definition.cost_scaling, get_generator_count(generator_id)))


func can_buy_generator(generator_id: StringName) -> bool:
	if not is_generator_unlocked(generator_id):
		return false
	var cost := get_generator_cost(generator_id)
	return cost >= 0.0 and can_afford(cost)


func buy_generator(generator_id: StringName) -> bool:
	if not can_buy_generator(generator_id):
		return false
	var cost := get_generator_cost(generator_id)
	var previous_count := get_generator_count(generator_id)
	# Increment first so currency_changed observers see the completed purchase.
	generator_counts[generator_id] = previous_count + 1
	if not spend_currency(cost):
		generator_counts[generator_id] = previous_count
		return false
	_refresh_generator_unlocks()
	_emit_generator_bought(generator_id, previous_count + 1)
	return true


func get_generator_production(generator_id: StringName) -> float:
	var definition := _get_generator_definition(generator_id)
	if definition == null:
		return 0.0
	return get_generator_count(generator_id) * definition.base_production


func get_total_production_per_second() -> float:
	var content_db := _get_content_db()
	if content_db == null:
		return 0.0
	var total := 0.0
	for definition in content_db.get_generators():
		total += get_generator_production(definition.id)
	return total


func update_production(delta: float) -> void:
	var production := get_total_production_per_second()
	if production > 0.0:
		add_currency(production * delta)


func debug_add_currency(amount: float) -> void:
	add_currency(amount)


## Transitional compatibility helpers retained for Stage 1 callers/tests.
func get_worker_count() -> int:
	return get_generator_count(WORKER_ID)


func get_worker_cost() -> float:
	return get_generator_cost(WORKER_ID)


func buy_worker() -> bool:
	return buy_generator(WORKER_ID)


func get_production_per_second() -> float:
	return get_total_production_per_second()


func set_worker_count(count: int) -> void:
	generator_counts[WORKER_ID] = max(0, count)
	_refresh_generator_unlocks()
	_emit_generator_bought(WORKER_ID, get_worker_count())


func get_state() -> Dictionary:
	return get_save_data()


## Returns only persistent gameplay state. Generator ids are data-driven.
func get_save_data() -> Dictionary:
	return {
		"bits": bits,
		"generator_counts": generator_counts.duplicate(),
	}


func set_state(state: Dictionary) -> void:
	apply_save_data(state)


## Restores persistent gameplay state while safely ignoring unknown content.
func apply_save_data(state: Dictionary) -> void:
	var old_bits := bits
	bits = _sanitize_non_negative_float(state.get("bits", 0.0))
	generator_counts.clear()
	var saved_counts = state.get("generator_counts", {})
	if saved_counts is Dictionary:
		for raw_id in saved_counts:
			var generator_id := StringName(raw_id)
			if _get_generator_definition(generator_id) != null:
				generator_counts[generator_id] = _sanitize_non_negative_int(saved_counts[raw_id])
	# Read the Stage 1 snapshot shape without maintaining parallel state.
	elif state.has("worker_count"):
		generator_counts[WORKER_ID] = max(0, int(state.get("worker_count", 0)))
	_unlocked_generator_ids.clear()
	_refresh_generator_unlocks()
	_emit_currency_changed(old_bits, bits)


func reset_save_data() -> void:
	apply_save_data({})


func _sanitize_non_negative_float(value: Variant) -> float:
	if not value is float and not value is int:
		return 0.0
	var number := float(value)
	if is_nan(number) or is_inf(number):
		return 0.0
	return maxf(0.0, number)


func _sanitize_non_negative_int(value: Variant) -> int:
	if not value is float and not value is int:
		return 0
	var number := float(value)
	if is_nan(number) or is_inf(number):
		return 0
	return max(0, int(number))


func _refresh_generator_unlocks() -> Array[StringName]:
	var content_db := _get_content_db()
	if content_db == null:
		return []
	var newly_unlocked: Array[StringName] = []
	for definition in content_db.get_generators():
		if _unlocked_generator_ids.has(definition.id):
			continue
		if _meets_unlock_requirement(definition):
			_unlocked_generator_ids[definition.id] = true
			newly_unlocked.append(definition.id)
	return newly_unlocked


func _meets_unlock_requirement(definition: GeneratorDefinition) -> bool:
	if definition.unlock_after_generator_id.is_empty():
		return true
	if _get_generator_definition(definition.unlock_after_generator_id) == null:
		return false
	return get_generator_count(definition.unlock_after_generator_id) >= definition.unlock_after_generator_count


func _get_generator_definition(generator_id: StringName) -> GeneratorDefinition:
	var content_db := _get_content_db()
	if content_db == null:
		return null
	return content_db.get_generator(generator_id) as GeneratorDefinition


func _get_content_db() -> Node:
	return AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"content_db")


func _emit_currency_changed(old: float, new: float) -> void:
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus != null:
		event_bus.currency_changed.emit(CURRENCY_BITS, old, new)


func _emit_generator_bought(generator_id: StringName, new_count: int) -> void:
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus != null:
		event_bus.generator_bought.emit(generator_id, new_count)
