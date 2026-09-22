extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")

## Runtime gameplay state. Generator definitions live in ContentDB and counts
## are keyed by stable generator id, so new content needs no Game.gd changes.
const CURRENCY_BITS: StringName = &"bits"
const MANUAL_CLICK_POWER: float = 1.0
const WORKER_ID: StringName = &"worker" # Transitional Stage 1 compatibility id.

var bits: float = 0.0
var generator_counts: Dictionary = {}
var owned_upgrades: Dictionary = {}
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
	var range := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"integer_range_manager")
	bits = maxf(0.0, range.clamp_currency(bits + amount) if range != null else bits + amount)
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
	add_currency(get_manual_generation_amount())

func get_manual_generation_amount() -> float:
	var base_power := MANUAL_CLICK_POWER
	var multiplier := 1.0
	var flat_bonus := 0.0
	for upgrade in _get_owned_upgrade_definitions():
		match upgrade.effect_type:
			&"manual_add":
				flat_bonus += upgrade.effect_value
			&"manual_multiplier":
				multiplier *= upgrade.effect_value
			&"generator_manual_exponential":
				multiplier *= pow(upgrade.effect_value, get_generator_count(upgrade.target_id))
			&"generator_manual_share":
				# Retained for compatible future data; this is deliberately not used by
				# WORKER INPUT LINK, whose input is ownership rather than production.
				flat_bonus += get_generator_production(upgrade.target_id) * upgrade.effect_value
	return base_power * multiplier + flat_bonus


## Data-driven summaries for UI/readouts. No caller needs upgrade-id-specific logic.
func get_manual_power_modifier_details() -> Array:
	var details: Array = []
	for upgrade in _get_owned_upgrade_definitions():
		if upgrade.effect_type != &"generator_manual_exponential":
			continue
		var count := get_generator_count(upgrade.target_id)
		details.append({
			"upgrade": upgrade,
			"generator_count": count,
			"multiplier": pow(upgrade.effect_value, count),
		})
	return details

func is_upgrade_owned(upgrade_id: StringName) -> bool: return owned_upgrades.has(upgrade_id)
func is_upgrade_unlocked(upgrade_id: StringName) -> bool:
	var upgrade := _get_upgrade_definition(upgrade_id)
	if upgrade == null or is_upgrade_owned(upgrade_id): return false
	if upgrade.requires_integer_range_started:
		var integer_range := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"integer_range_manager")
		if integer_range == null or not integer_range.stage_started:
			return false
	if not upgrade.unlock_generator_id.is_empty() and get_generator_count(upgrade.unlock_generator_id) < upgrade.unlock_generator_count: return false
	return upgrade.prerequisite_upgrade_id.is_empty() or is_upgrade_owned(upgrade.prerequisite_upgrade_id)
func can_buy_upgrade(upgrade_id: StringName) -> bool:
	var upgrade := _get_upgrade_definition(upgrade_id)
	return upgrade != null and is_upgrade_unlocked(upgrade_id) and can_afford(upgrade.cost) and can_install_upgrade(upgrade_id)


func can_install_upgrade(upgrade_id: StringName) -> bool:
	if _get_upgrade_definition(upgrade_id) == null:
		return false
	var access := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"access_mask_manager")
	return access == null or access.can_install_new_upgrades()


func get_upgrade_install_denial_reason(upgrade_id: StringName) -> String:
	if _get_upgrade_definition(upgrade_id) == null:
		return ""
	var access := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"access_mask_manager")
	return access.get_install_denial_reason() if access != null and not access.can_install_new_upgrades() else ""


func buy_upgrade(upgrade_id: StringName) -> bool:
	var upgrade := _get_upgrade_definition(upgrade_id)
	if upgrade == null or not is_upgrade_unlocked(upgrade_id) or not can_afford(upgrade.cost): return false
	if not can_install_upgrade(upgrade_id):
		var access := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"access_mask_manager")
		if access != null: access.notify_install_denied()
		return false
	if not spend_currency(upgrade.cost): return false
	owned_upgrades[upgrade_id] = true
	var access := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"access_mask_manager")
	if access != null: access.notify_upgrade_installed()
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus != null: event_bus.upgrade_bought.emit(upgrade_id)
	return true


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
	return buy_generators(generator_id, 1) == 1


## Exact sum of sequential, rounded next costs. The UI delegates all bulk math
## here, so BUY 10 always matches ten individual purchases.
func get_generator_bulk_cost(generator_id: StringName, amount: int) -> float:
	var definition := _get_generator_definition(generator_id)
	if definition == null or amount < 1:
		return -1.0
	var total := 0.0
	var owned := get_generator_count(generator_id)
	for index in range(amount):
		var cost: float = ceil(definition.base_cost * pow(definition.cost_scaling, owned + index))
		if is_inf(cost) or total > 1.0e300 - cost:
			return INF
		total += cost
	return total


func get_max_affordable_generator_count(generator_id: StringName) -> int:
	if not is_generator_unlocked(generator_id) or get_generator_cost(generator_id) > bits:
		return 0
	# Costs reach floating-point infinity in a few thousand steps at 1.15, so
	# logarithmic bracketing plus exact bounded sums stays fast even for huge Bits.
	var low := 0
	var high := 1
	while get_generator_bulk_cost(generator_id, high) <= bits:
		low = high
		high *= 2
		if high > 8192:
			break
	while low + 1 < high:
		var middle: int = low + int((high - low) / 2)
		if get_generator_bulk_cost(generator_id, middle) <= bits:
			low = middle
		else:
			high = middle
	return low


## Returns the actual purchased amount (zero for safe failure).
func buy_generators(generator_id: StringName, amount: int) -> int:
	if amount < 1 or not is_generator_unlocked(generator_id):
		return 0
	var cost := get_generator_bulk_cost(generator_id, amount)
	if cost < 0.0 or is_inf(cost) or not can_afford(cost):
		return 0
	var previous_count := get_generator_count(generator_id)
	generator_counts[generator_id] = previous_count + amount
	if not spend_currency(cost):
		generator_counts[generator_id] = previous_count
		return 0
	_refresh_generator_unlocks()
	_emit_generator_bought(generator_id, previous_count + amount)
	_emit_generator_bulk_bought(generator_id, amount, previous_count + amount)
	return amount


func get_generator_production(generator_id: StringName) -> float:
	var definition := _get_generator_definition(generator_id)
	if definition == null:
		return 0.0
	var count := get_generator_count(generator_id)
	if count <= 0:
		return 0.0
	var growth := definition.production_growth
	if is_equal_approx(growth, 1.0):
		return definition.base_production * count * get_generator_production_multiplier(generator_id)
	var geometric_sum := (pow(growth, count) - 1.0) / (growth - 1.0)
	return definition.base_production * geometric_sum * get_generator_production_multiplier(generator_id)


func get_next_generator_production(generator_id: StringName) -> float:
	var definition := _get_generator_definition(generator_id)
	if definition == null:
		return 0.0
	return definition.base_production * pow(definition.production_growth, get_generator_count(generator_id)) * get_generator_production_multiplier(generator_id)


## Intentional extension point for future one-time upgrades/modifiers.
func get_generator_production_multiplier(_generator_id: StringName) -> float:
	var multiplier := get_global_production_multiplier()
	for upgrade in _get_owned_upgrade_definitions():
		if upgrade.effect_type == &"generator_multiplier" and upgrade.target_id == _generator_id:
			multiplier *= upgrade.effect_value
	var scheduler := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"scheduler_manager")
	if scheduler != null:
		multiplier *= scheduler.get_efficiency_multiplier(_generator_id)
	return multiplier

func get_global_production_multiplier() -> float:
	var multiplier := 1.0
	for upgrade in _get_owned_upgrade_definitions():
		if upgrade.effect_type == &"global_production_multiplier": multiplier *= upgrade.effect_value
	return multiplier


func get_total_production_per_second() -> float:
	var content_db := _get_content_db()
	if content_db == null:
		return 0.0
	var total := 0.0
	for definition in content_db.get_generators():
		total += get_generator_production(definition.id)
	return total


func update_production(delta: float) -> void:
	var range := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"integer_range_manager")
	if range != null and range.is_limit_reached(): return
	var production := get_total_production_per_second()
	if production > 0.0:
		add_currency(production * delta)


func debug_add_currency(amount: float) -> void:
	if _debug_access_allowed() and _is_valid_debug_amount(amount):
		add_currency(amount)


## Development-only mutation surface. The Dev Panel uses these methods instead
## of reaching into persistent dictionaries, so regular gameplay math remains
## the one authoritative implementation.
func debug_set_bits(amount: float) -> bool:
	if not _debug_access_allowed() or not _is_valid_debug_amount(amount):
		return false
	var old := bits
	bits = amount
	_emit_currency_changed(old, bits)
	return true


func debug_set_generator_count(generator_id: StringName, count: int) -> bool:
	if not _debug_access_allowed() or _get_generator_definition(generator_id) == null or count < 0:
		return false
	generator_counts[generator_id] = count
	_refresh_generator_unlocks()
	_emit_generator_bought(generator_id, count)
	return true


func debug_set_upgrade_owned(upgrade_id: StringName, owned: bool) -> bool:
	if not _debug_access_allowed() or _get_upgrade_definition(upgrade_id) == null:
		return false
	if owned:
		owned_upgrades[upgrade_id] = true
	else:
		owned_upgrades.erase(upgrade_id)
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus != null:
		event_bus.upgrade_bought.emit(upgrade_id)
	_emit_currency_changed(bits, bits)
	return true


func debug_set_all_upgrades(owned: bool) -> bool:
	if not _debug_access_allowed():
		return false
	var content_db := _get_content_db()
	if content_db == null:
		return false
	for definition in content_db.get_upgrades():
		if owned:
			owned_upgrades[definition.id] = true
		else:
			owned_upgrades.erase(definition.id)
		var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
		if event_bus != null:
			event_bus.upgrade_bought.emit(definition.id)
	_emit_currency_changed(bits, bits)
	return true


func debug_apply_state(state: Dictionary) -> bool:
	if not _debug_access_allowed():
		return false
	apply_save_data(state)
	var content_db := _get_content_db()
	if content_db != null:
		for definition in content_db.get_generators():
			_emit_generator_bought(definition.id, get_generator_count(definition.id))
		for definition in content_db.get_upgrades():
			if is_upgrade_owned(definition.id):
				var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
				if event_bus != null:
					event_bus.upgrade_bought.emit(definition.id)
	return true


func debug_refresh_ui() -> void:
	if not _debug_access_allowed():
		return
	_emit_currency_changed(bits, bits)
	var content_db := _get_content_db()
	if content_db != null:
		for definition in content_db.get_generators():
			_emit_generator_bought(definition.id, get_generator_count(definition.id))


func _debug_access_allowed() -> bool:
	return OS.is_debug_build()


func _is_valid_debug_amount(amount: float) -> bool:
	return not is_nan(amount) and not is_inf(amount) and amount >= 0.0


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
		"owned_upgrades": owned_upgrades.keys(),
	}


func set_state(state: Dictionary) -> void:
	apply_save_data(state)


## Restores persistent gameplay state while safely ignoring unknown content.
func apply_save_data(state: Dictionary) -> void:
	var old_bits := bits
	bits = _sanitize_non_negative_float(state.get("bits", 0.0))
	generator_counts.clear()
	owned_upgrades.clear()
	var saved_counts = state.get("generator_counts", {})
	if saved_counts is Dictionary:
		for raw_id in saved_counts:
			var generator_id := StringName(raw_id)
			if _get_generator_definition(generator_id) != null:
				generator_counts[generator_id] = _sanitize_non_negative_int(saved_counts[raw_id])
	# Read the Stage 1 snapshot shape without maintaining parallel state.
	elif state.has("worker_count"):
		generator_counts[WORKER_ID] = max(0, int(state.get("worker_count", 0)))
	var saved_upgrades = state.get("owned_upgrades", [])
	if saved_upgrades is Array:
		for raw_id in saved_upgrades:
			var upgrade_id := StringName(raw_id)
			if _get_upgrade_definition(upgrade_id) != null: owned_upgrades[upgrade_id] = true
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

func _get_upgrade_definition(upgrade_id: StringName) -> UpgradeDefinition:
	var content_db := _get_content_db()
	return content_db.get_upgrade(upgrade_id) as UpgradeDefinition if content_db != null else null

func _get_owned_upgrade_definitions() -> Array:
	var definitions: Array = []
	for raw_id in owned_upgrades:
		var definition := _get_upgrade_definition(StringName(raw_id))
		if definition != null: definitions.append(definition)
	return definitions


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


func _emit_generator_bulk_bought(generator_id: StringName, amount: int, new_count: int) -> void:
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus != null:
		event_bus.generator_bulk_bought.emit(generator_id, amount, new_count)
