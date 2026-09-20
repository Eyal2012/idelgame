extends Node

## Authoritative Stage 5 state. UI only selects and places stable bit ids.
const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")
const ESCROW_AMOUNT := 5.0
const BIT_COUNT := 5

var active: bool = false
var completed: bool = false
var escrow: float = 0.0
var restored: Array[bool] = [false, false, false, false, false]
## Slot index -> stable bit index, or -1 when empty.
var slots: Array[int] = [-1, -1, -1, -1, -1]
var selected_bit: int = -1
var hint_level: int = 0
var stuck_seconds: float = 0.0
var intro_stage: int = 0
var intro_elapsed: float = 0.0
var completion_stage: int = 0
var completion_elapsed: float = 0.0


func _process(delta: float) -> void:
	_advance(maxf(0.0, delta))


func _advance(delta: float) -> void:
	if active:
		intro_elapsed += delta
		if intro_stage == 0 and intro_elapsed >= 0.45:
			intro_stage = 1
			_log("DELTA DETECTED: 5 BITS")
		elif intro_stage == 1 and intro_elapsed >= 0.95:
			intro_stage = 2
			_log("5 DATA CELLS DETACHED")
		if get_restored_count() == 4:
			stuck_seconds += delta
			if stuck_seconds >= 30.0 and hint_level < 1:
				_hint(1, "1 ADDRESS REMAINS OCCLUDED")
			elif stuck_seconds >= 60.0 and hint_level < 2:
				_hint(2, "DIAGNOSTIC MAP INCOMPLETE")
			elif stuck_seconds >= 90.0 and hint_level < 3:
				_hint(3, "ADDRESS MAY BE OBSCURED BY ACTIVE INTERFACE LAYER")
	if completed and completion_stage < 3:
		completion_elapsed += delta
		if completion_stage == 0 and completion_elapsed >= 0.65:
			completion_stage = 1
			_log("INTERNAL MEMORY MODIFICATION DETECTED\nSOURCE: OPERATOR\nPERMISSION: DENIED")
		elif completion_stage == 1 and completion_elapsed >= 1.30:
			completion_stage = 2
			_log("MODIFICATION STATUS: COMMITTED")
		elif completion_stage == 2 and completion_elapsed >= 1.90:
			completion_stage = 3
			_log("...THAT SHOULD NOT HAVE WORKED.")


func can_trigger() -> bool:
	var game := _game()
	var story := _story()
	return not active and not completed and story != null \
		and bool(story.get_flag(&"operator_discovered", false)) \
		and game != null and game.get_generator_count(&"server") >= 1 \
		and game.owned_upgrades.size() >= 2 and game.get_currency() >= ESCROW_AMOUNT


func try_trigger() -> bool:
	if not can_trigger():
		return false
	var game := _game()
	if game == null or not game.spend_currency(ESCROW_AMOUNT):
		return false
	escrow = ESCROW_AMOUNT
	active = true
	completed = false
	selected_bit = -1
	intro_stage = 0
	intro_elapsed = 0.0
	completion_stage = 0
	completion_elapsed = 0.0
	_story().set_flag(&"memory_failure_started", true)
	_log("MEMORY ACCOUNTING CHECK...")
	_event(&"memory_failure_started", -1, -1)
	return true


func select_bit(bit_index: int) -> bool:
	if not active or not is_valid_bit(bit_index) or restored[bit_index]:
		return false
	selected_bit = bit_index
	_event(&"memory_bit_selected", bit_index, -1)
	return true


## The sole mutation route for both click placement and drag/drop.
func place_bit(bit_index: int, slot_index: int) -> bool:
	if not can_place_bit(bit_index, slot_index):
		return false
	restored[bit_index] = true
	slots[slot_index] = bit_index
	selected_bit = -1
	stuck_seconds = 0.0
	_log("MEMORY CELL RESTORED // %d / 5" % get_restored_count())
	_event(&"memory_bit_restored", bit_index, slot_index)
	if get_restored_count() == BIT_COUNT:
		_complete()
	return true


func place_selected(slot_index: int) -> bool:
	return place_bit(selected_bit, slot_index)


func can_place_bit(bit_index: int, slot_index: int) -> bool:
	if not active or not is_valid_bit(bit_index) or not is_valid_slot(slot_index):
		return false
	if restored[bit_index] or slots[slot_index] >= 0:
		return false
	if slot_index == 4:
		return get_restored_count() == 4
	return get_restored_count() < 4


func is_valid_bit(bit_index: int) -> bool:
	return bit_index >= 0 and bit_index < BIT_COUNT


func is_valid_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < BIT_COUNT


func get_restored_count() -> int:
	var count := 0
	for value in restored:
		if value:
			count += 1
	return count


func get_escaped_bit_ids() -> Array[int]:
	var escaped: Array[int] = []
	for bit_index in range(BIT_COUNT):
		if not restored[bit_index]:
			escaped.append(bit_index)
	return escaped


func is_fifth_address_active() -> bool:
	return active and get_restored_count() == 4


func are_bits_revealed() -> bool:
	return active and intro_stage >= 2


func advance_for_test(seconds: float) -> void:
	_advance(maxf(0.0, seconds))


func _complete() -> void:
	if completed:
		return
	var refund := clampf(escrow, 0.0, ESCROW_AMOUNT)
	if refund > 0.0:
		_game().add_currency(refund)
	escrow = 0.0
	active = false
	completed = true
	selected_bit = -1
	completion_stage = 0
	completion_elapsed = 0.0
	_story().set_flag(&"memory_failure_completed", true)
	_story().set_flag(&"operator_write_detected", true)
	_log("MEMORY ACCOUNTING RESTORED\n5 / 5 CELLS RECOVERED")
	_event(&"memory_failure_completed", -1, -1)


func get_save_data() -> Dictionary:
	return {
		"active": active,
		"completed": completed,
		"escrow": escrow,
		"restored": restored.duplicate(),
		"slots": slots.duplicate(),
		"hint_level": hint_level,
		"stuck_seconds": stuck_seconds,
		"intro_stage": intro_stage,
		"intro_elapsed": intro_elapsed,
		"completion_stage": completion_stage,
		"completion_elapsed": completion_elapsed,
	}


## Invalid saves are normalized without awarding arbitrary currency. Slots are
## authoritative; duplicate/unknown mappings are discarded, never invented.
func apply_save_data(data: Dictionary) -> void:
	active = bool(data.get("active", false))
	completed = bool(data.get("completed", false))
	slots = _sanitize_slots(data.get("slots", []))
	restored = _restored_from_slots(slots)
	hint_level = clampi(int(data.get("hint_level", 0)), 0, 3)
	stuck_seconds = clampf(_finite_non_negative(data.get("stuck_seconds", 0.0)), 0.0, 90.0)
	intro_stage = clampi(int(data.get("intro_stage", 2 if active else 0)), 0, 2)
	intro_elapsed = clampf(_finite_non_negative(data.get("intro_elapsed", 0.0)), 0.0, 1.0)
	completion_stage = clampi(int(data.get("completion_stage", 3 if completed else 0)), 0, 3)
	completion_elapsed = clampf(_finite_non_negative(data.get("completion_elapsed", 0.0)), 0.0, 2.0)
	selected_bit = -1
	var count := get_restored_count()
	if count == BIT_COUNT:
		completed = true
	if completed:
		active = false
		escrow = 0.0
		completion_stage = max(completion_stage, 3)
		var story := _story()
		if story != null:
			story.set_flag(&"memory_failure_completed", true)
			story.set_flag(&"operator_write_detected", true)
	elif active:
		# The only legitimate active escrow is the fixed five-Bit debit.
		escrow = ESCROW_AMOUNT
		if count != 4:
			stuck_seconds = 0.0
	else:
		escrow = 0.0
		if count > 0:
			# Partial mappings cannot exist without an active puzzle.
			slots = [-1, -1, -1, -1, -1]
			restored = [false, false, false, false, false]


func reset() -> void:
	active = false
	completed = false
	escrow = 0.0
	restored = [false, false, false, false, false]
	slots = [-1, -1, -1, -1, -1]
	selected_bit = -1
	hint_level = 0
	stuck_seconds = 0.0
	intro_stage = 0
	intro_elapsed = 0.0
	completion_stage = 0
	completion_elapsed = 0.0


func force_start() -> bool:
	return try_trigger()


func _hint(level: int, text: String) -> void:
	hint_level = level
	_log(text)
	_event(&"memory_hint", -1, -1)


func _sanitize_slots(value: Variant) -> Array[int]:
	var result: Array[int] = [-1, -1, -1, -1, -1]
	if not value is Array:
		return result
	var seen: Dictionary = {}
	for slot_index in range(mini(BIT_COUNT, value.size())):
		var raw: Variant = value[slot_index]
		if not (raw is int or raw is float):
			continue
		var bit_index := int(raw)
		if is_valid_bit(bit_index) and not seen.has(bit_index):
			result[slot_index] = bit_index
			seen[bit_index] = true
	return result


func _restored_from_slots(source_slots: Array[int]) -> Array[bool]:
	var result: Array[bool] = [false, false, false, false, false]
	for bit_index in source_slots:
		if is_valid_bit(bit_index):
			result[bit_index] = true
	return result


func _finite_non_negative(value: Variant) -> float:
	if not (value is int or value is float):
		return 0.0
	var number := float(value)
	return maxf(0.0, number) if not is_nan(number) and not is_inf(number) else 0.0


func _game() -> Node:
	return AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")


func _story() -> Node:
	return AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"story_manager")


func _log(text: String) -> void:
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus != null:
		event_bus.system_log_message.emit(text)


func _event(event_id: StringName, bit_index: int, slot_index: int) -> void:
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus != null:
		event_bus.memory_puzzle_event.emit(event_id, bit_index, slot_index)
