extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")

## Game
##
## Owns the important runtime idle-game state.
## Does NOT own UI state. UI observes Game through EventBus.
##
## Stage 1: basic idle loop.
##   - One currency: Bits
##   - Manual click reward: +1 Bit
##   - One generator: Worker (1 Bit/sec, cost 10, scaling 1.15x)

## Currency id for the single starting currency.
const CURRENCY_BITS: StringName = StringName("bits")

## Manual click reward in Bits.
const MANUAL_CLICK_POWER: float = 1.0

## Worker generator constants.
const WORKER_ID: StringName = StringName("worker")
const WORKER_BASE_PRODUCTION: float = 1.0   # Bits per second per Worker
const WORKER_BASE_COST: float = 10.0
const WORKER_COST_SCALING: float = 1.15

## Current Bits amount.
var bits: float = 0.0

## Number of Workers owned.
var worker_count: int = 0


func _ready() -> void:
	_reset_runtime_state()


func _process(delta: float) -> void:
	update_production(delta)


## Reset all runtime state to initial values.
func _reset_runtime_state() -> void:
	bits = 0.0
	worker_count = 0


## Return the current Bits amount.
func get_currency() -> float:
	return bits


## Add Bits and emit currency_changed.
func add_currency(amount: float) -> void:
	var old := bits
	bits = maxf(0.0, bits + amount)
	if not is_equal_approx(old, bits):
		_emit_currency_changed(old, bits)


## Attempt to spend Bits. Returns true on success, false if insufficient.
func spend_currency(amount: float) -> bool:
	if amount < 0.0:
		return false
	if bits < amount:
		return false
	var old := bits
	bits -= amount
	_emit_currency_changed(old, bits)
	return true


## Return true if the player can afford the given amount.
func can_afford(amount: float) -> bool:
	return amount >= 0.0 and bits >= amount


## Perform one manual generate click.
func generate_manual() -> void:
	add_currency(MANUAL_CLICK_POWER)


## Return the current Worker count.
func get_worker_count() -> int:
	return worker_count


## Return the cost of the next Worker (base_cost * scaling^owned).
## Costs deliberately retain fractional Bits so the UI and affordability check use
## one exact formula rather than applying different rounding rules.
func get_worker_cost() -> float:
	return WORKER_BASE_COST * pow(WORKER_COST_SCALING, worker_count)


## Attempt to buy one Worker.
## Returns true on success, false if the player cannot afford it.
func buy_worker() -> bool:
	var cost := get_worker_cost()
	if not can_afford(cost):
		return false
	spend_currency(cost)
	worker_count += 1
	_emit_generator_bought(WORKER_ID, worker_count)
	return true


## Return total passive Bits production per second.
func get_production_per_second() -> float:
	return worker_count * WORKER_BASE_PRODUCTION


## Process passive production. Call this from _process or _physics_process.
func update_production(delta: float) -> void:
	var prod := get_production_per_second()
	if prod <= 0.0:
		return
	add_currency(prod * delta)


## Debug helper: instantly add Bits without spending.
func debug_add_currency(amount: float) -> void:
	add_currency(amount)


## Debug helper: instantly set Worker count.
func set_worker_count(count: int) -> void:
	worker_count = max(0, count)
	_emit_generator_bought(WORKER_ID, worker_count)


## Emit currency_changed through EventBus (decoupled).
func _emit_currency_changed(old: float, new: float) -> void:
	var eb := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if eb != null:
		eb.currency_changed.emit(CURRENCY_BITS, old, new)


## Emit generator_bought through EventBus (decoupled).
func _emit_generator_bought(generator_id: StringName, new_count: int) -> void:
	var eb := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if eb != null:
		eb.generator_bought.emit(generator_id, new_count)


## Return a snapshot of gameplay state (used by SaveManager).
func get_state() -> Dictionary:
	return {
		"bits": bits,
		"worker_count": worker_count,
	}


## Restore gameplay state from a snapshot.
func set_state(state: Dictionary) -> void:
	bits = maxf(0.0, float(state.get("bits", 0.0)))
	worker_count = int(state.get("worker_count", 0))
