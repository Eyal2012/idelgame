extends Node

## Authoritative Stage 5 state. UI only selects and places stable bit ids.
const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")
const NUMBER_FORMATTER := preload("res://core/number_formatter.gd")
## The failure is visible at its normal trigger point without becoming punitive.
const MEMORY_ESCROW_PERCENT := 0.05
const MIN_MEMORY_ESCROW := 10.0
const MAX_MEMORY_ESCROW := 2_147_483_647.0
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
			_event(&"memory_intro_progressed", -1, -1)
			_log("MEMORY ACCOUNTING FAILURE\n5 MEMORY BLOCKS DETACHED\nTOTAL UNADDRESSABLE: %s BITS" % NUMBER_FORMATTER.format(get_escrow_amount(), 2))
		elif intro_stage == 1 and intro_elapsed >= 0.95:
			intro_stage = 2
			_event(&"memory_intro_revealed", -1, -1)
			_log("MEMORY MAP ONLINE\nRESTORE EACH MEMORY BLOCK")
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
		and game.owned_upgrades.size() >= 2 and _calculate_escrow(game.get_currency()) > 0.0


func try_trigger() -> bool:
	if not can_trigger():
		return false
	var game := _game()
	if game == null:
		return false
	var expected_balance: float = game.get_currency()
	var escrow_amount: float = _calculate_escrow(expected_balance)
	if escrow_amount <= 0.0 or not game.spend_currency(escrow_amount):
		return false
	escrow = escrow_amount
	active = true
	completed = false
	selected_bit = -1
	intro_stage = 0
	intro_elapsed = 0.0
	completion_stage = 0
	completion_elapsed = 0.0
	_story().set_flag(&"memory_failure_started", true)
	_log("MEMORY ACCOUNTING FAILURE\nEXPECTED BALANCE: %s BITS\nADDRESSABLE: %s BITS\nUNADDRESSABLE: %s BITS" % [
		NUMBER_FORMATTER.format(expected_balance, 2),
		NUMBER_FORMATTER.format(game.get_currency(), 2),
		NUMBER_FORMATTER.format(escrow, 2),
	])
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
	if get_restored_count() == 4:
		_log("MEMORY MAP:\n4 / 5 BLOCKS RESTORED\nUNRESOLVED: 1 MEMORY BLOCK\nVALUE: %s BITS" % NUMBER_FORMATTER.format(get_unresolved_value(), 2))
	else:
		_log("MEMORY BLOCK RESTORED // %d / 5" % get_restored_count())
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


## The stored escrow is the authority for every displayed block amount.
func get_escrow_amount() -> float:
	return escrow


func get_block_values() -> Array[float]:
	var values: Array[float] = []
	var total := int(floorf(maxf(0.0, escrow)))
	var base_value := total / BIT_COUNT
	var remainder := total % BIT_COUNT
	for bit_index in range(BIT_COUNT):
		values.append(float(base_value + (1 if bit_index < remainder else 0)))
	return values


## Accept both stable internal ids (bit_0) and their integer indices.
func get_block_value(block_id: Variant) -> float:
	var bit_index := _block_index_from_id(block_id)
	if not is_valid_bit(bit_index):
		return 0.0
	return get_block_values()[bit_index]


func get_unresolved_value() -> float:
	var total := 0.0
	for bit_index in range(BIT_COUNT):
		if not restored[bit_index]:
			total += get_block_value(bit_index)
	return total


func get_new_escrow_amount(balance: float) -> float:
	return _calculate_escrow(balance)


func is_fifth_address_active() -> bool:
	return active and get_restored_count() == 4


func are_bits_revealed() -> bool:
	return active and intro_stage >= 2


func advance_for_test(seconds: float) -> void:
	_advance(maxf(0.0, seconds))


func _complete() -> void:
	if completed:
		return
	var refund := clampf(escrow, 0.0, MAX_MEMORY_ESCROW)
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
	_log("MEMORY ACCOUNTING RESTORED\n5 / 5 BLOCKS MAPPED\nRESTORED: %s BITS" % NUMBER_FORMATTER.format(refund, 2))
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
	var saved_escrow := _sanitize_escrow(data.get("escrow", 0.0))
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
		# Keep v4's stored amount verbatim. An old in-progress save with escrow=5
		# remains a five-Bit puzzle; only a newly triggered failure is percentage based.
		escrow = saved_escrow
		if escrow <= 0.0:
			active = false
			slots = [-1, -1, -1, -1, -1]
			restored = [false, false, false, false, false]
		else:
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


## Development-only puzzle controls. They use the normal escrow/start and
## placement/completion routes so debug checkpoints never invent invalid state.
func debug_start() -> bool:
	if not OS.is_debug_build():
		return false
	if active:
		return true
	if completed:
		reset()
	var game := _game()
	if game == null:
		return false
	var amount := _calculate_escrow(game.get_currency())
	if amount <= 0.0 or not game.spend_currency(amount):
		return false
	escrow = amount
	active = true
	completed = false
	selected_bit = -1
	intro_stage = 2
	intro_elapsed = 1.0
	completion_stage = 0
	completion_elapsed = 0.0
	var story := _story()
	if story != null:
		story.set_flag(&"memory_failure_started", true)
		story.set_flag(&"memory_failure_completed", false)
		story.set_flag(&"operator_write_detected", false)
	_event(&"memory_failure_started", -1, -1)
	return true


func debug_set_progress(restored_count: int) -> bool:
	if not OS.is_debug_build() or restored_count < 0 or restored_count >= BIT_COUNT:
		return false
	if not debug_start():
		return false
	restored = [false, false, false, false, false]
	slots = [-1, -1, -1, -1, -1]
	selected_bit = -1
	stuck_seconds = 0.0
	for bit_index in range(restored_count):
		restored[bit_index] = true
		slots[bit_index] = bit_index
	_event(&"memory_debug_progress", restored_count, -1)
	return true


func debug_complete() -> bool:
	if not OS.is_debug_build() or not debug_set_progress(BIT_COUNT - 1):
		return false
	return place_bit(BIT_COUNT - 1, BIT_COUNT - 1)


func debug_reset_current_puzzle() -> bool:
	if not OS.is_debug_build():
		return false
	# This is a safe reset: restore active escrow before clearing its state.
	if active and escrow > 0.0:
		var game := _game()
		if game != null:
			game.add_currency(escrow)
	reset()
	var story := _story()
	if story != null:
		story.set_flag(&"memory_failure_started", false)
		story.set_flag(&"memory_failure_completed", false)
		story.set_flag(&"operator_write_detected", false)
	_event(&"memory_debug_reset", -1, -1)
	return true


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


func _sanitize_escrow(value: Variant) -> float:
	return clampf(floorf(_finite_non_negative(value)), 0.0, MAX_MEMORY_ESCROW)


func _calculate_escrow(balance: float) -> float:
	var whole_balance := floorf(maxf(0.0, balance))
	if whole_balance <= 0.0:
		return 0.0
	return minf(whole_balance, maxf(MIN_MEMORY_ESCROW, floorf(whole_balance * MEMORY_ESCROW_PERCENT)))


func _block_index_from_id(block_id: Variant) -> int:
	if block_id is int:
		return int(block_id)
	if block_id is float and is_equal_approx(block_id, floorf(block_id)):
		return int(block_id)
	var text := str(block_id)
	if text.begins_with("bit_"):
		text = text.trim_prefix("bit_")
	if text.is_valid_int():
		return int(text)
	return -1


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
