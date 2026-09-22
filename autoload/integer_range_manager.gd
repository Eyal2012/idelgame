extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")
const INT32_MAX: float = 2147483647.0
const STAGE_START_DELAY_SECONDS := 180.0
const THRESHOLDS: Array[float] = [0.50, 0.75, 0.90, 0.95, 0.99, 1.0]

var stage_started := false
var integer_limit_reached := false
var _elapsed := 0.0
var threshold_seen: Dictionary = {}

func _process(delta: float) -> void:
	if not stage_started and _stage7_complete():
		_elapsed += maxf(0.0, delta)
		if _elapsed >= STAGE_START_DELAY_SECONDS: start_stage()
	if stage_started: _check_thresholds()

func _ready() -> void:
	var events := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if events != null:
		events.upgrade_bought.connect(_on_upgrade_bought)

func start_stage() -> bool:
	if stage_started or not _stage7_complete(): return false
	stage_started = true
	_log("COMPUTE SCHEDULER: STABLE\nPROCESS UTILIZATION: NOMINAL\nSIGNED INTEGER RANGE: 32-BIT\nMAXIMUM ADDRESSABLE VALUE: 2,147,483,647")
	_emit_changed(); return true

func get_int32_max() -> float: return INT32_MAX
func get_capacity_ratio(value: float = -1.0) -> float:
	var current := value
	if current < 0.0:
		var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
		current = game.get_currency() if game != null else 0.0
	return clampf(current / INT32_MAX, 0.0, 1.0)
func get_capacity_percent() -> float: return get_capacity_ratio() * 100.0
func get_headroom() -> float: return maxf(0.0, INT32_MAX - get_capacity_ratio() * INT32_MAX)
func is_near_capacity() -> bool: return get_capacity_ratio() >= 0.90
func is_limit_reached() -> bool: return integer_limit_reached

func clamp_currency(value: float) -> float:
	if not stage_started: return value
	var clamped := minf(value, INT32_MAX)
	if clamped >= INT32_MAX and not integer_limit_reached:
		integer_limit_reached = true
		_log("INTEGER RANGE LIMIT REACHED\nCURRENT: 2,147,483,647\nMAX: 2,147,483,647\nFURTHER COMMIT: BLOCKED\nSYSTEM: OUTPUT HALTED.")
		_emit_changed()
	return clamped

func get_save_data() -> Dictionary:
	return {"stage_started":stage_started,"integer_limit_reached":integer_limit_reached,"elapsed":_elapsed,"threshold_seen":threshold_seen.duplicate()}
func apply_save_data(data: Dictionary) -> void:
	stage_started = bool(data.get("stage_started", false)) and _stage7_complete()
	integer_limit_reached = stage_started and bool(data.get("integer_limit_reached", false))
	_elapsed = clampf(float(data.get("elapsed",0.0)),0.0,STAGE_START_DELAY_SECONDS)
	threshold_seen = data.get("threshold_seen",{}) if data.get("threshold_seen",{}) is Dictionary else {}
	_emit_changed()
func reset() -> void:
	stage_started=false;integer_limit_reached=false;_elapsed=0.0;threshold_seen={};_emit_changed()
func debug_start() -> bool:
	if not OS.is_debug_build(): return false
	return start_stage()
func debug_set_ratio(ratio: float) -> bool:
	if not OS.is_debug_build() or not stage_started: return false
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if game == null: return false
	game.debug_set_bits(clampf(ratio,0.0,1.0)*INT32_MAX)
	_check_thresholds(); return true
func debug_apply_checkpoint(state: StringName) -> bool:
	if not OS.is_debug_build(): return false
	reset()
	if state == &"inactive" or state == &"ready": return true
	if not _stage7_complete(): return false
	stage_started = true
	var ratio := 0.10
	if state == &"range_75": ratio = 0.75
	elif state == &"range_95": ratio = 0.95
	elif state == &"range_99": ratio = 0.99
	elif state == &"max": ratio = 1.0
	elif state != &"started": return false
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if game == null: return false
	game.debug_set_bits(INT32_MAX * ratio)
	_check_thresholds()
	if state == &"max": clamp_currency(INT32_MAX)
	_emit_changed(); return true

func _check_thresholds() -> void:
	var ratio := get_capacity_ratio()
	for threshold in THRESHOLDS:
		var key := str(threshold)
		if ratio >= threshold and not threshold_seen.has(key):
			threshold_seen[key] = true
			_log("SIGNED RANGE UTILIZATION: %d%%" % roundi(threshold * 100.0))
			if is_equal_approx(threshold, 0.95):
				_log("DIRECTIVE: MAXIMIZE OUTPUT\nFURTHER OUTPUT NOT RECOMMENDED")
			_emit_changed()

func _on_upgrade_bought(upgrade_id: StringName) -> void:
	if stage_started and upgrade_id == &"compute_override_i":
		_log("COMPUTE THROUGHPUT INCREASED\nOUTPUT TARGET: CONTINUE")
func _stage7_complete() -> bool:
	var scheduler := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"scheduler_manager")
	return scheduler != null and scheduler.is_stage7_complete()
func _log(text: String) -> void:
	var eb := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if eb != null: eb.system_log_message.emit(text)
func _emit_changed() -> void:
	var eb := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if eb != null: eb.integer_range_changed.emit()
