extends Node

## Authoritative fictional in-game access register for Stage 6. It never
## interacts with operating-system permissions.
const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")

const READ: int = 1 << 0
const WRITE: int = 1 << 1
const EXECUTE: int = 1 << 2
const SYSTEM: int = 1 << 3
const INITIAL_MASK: int = READ
const STAGE_START_DELAY_SECONDS := 180.0

var operator_access_mask: int = INITIAL_MASK
var event_started := false
var register_discovered := false
var write_permission_discovered := false
var puzzle_completed := false
var _completion_elapsed := 0.0


func _process(delta: float) -> void:
	if event_started or not _is_stage_five_complete():
		return
	_completion_elapsed += maxf(0.0, delta)
	if _completion_elapsed >= STAGE_START_DELAY_SECONDS:
		start_event()


func get_operator_access_mask() -> int:
	return operator_access_mask


func has_operator_permission(permission: int) -> bool:
	return permission > 0 and (operator_access_mask & permission) == permission


func is_restricting_upgrade_installs() -> bool:
	return event_started and not has_operator_permission(WRITE)


func can_install_new_upgrades() -> bool:
	return not is_restricting_upgrade_installs()


func get_install_denial_reason() -> String:
	return "INSTALL DENIED\nOPERATOR WRITE PERMISSION REQUIRED" if is_restricting_upgrade_installs() else ""


func start_event() -> bool:
	if event_started or not _is_stage_five_complete():
		return false
	event_started = true
	operator_access_mask = INITIAL_MASK
	_set_story_flag(&"access_mask_event_started", true)
	_emit_mask_changed()
	_log("SECURITY AUDIT STARTED\nUNAUTHORIZED MEMORY WRITE FOUND\nSOURCE: OPERATOR\nACCESS POLICY INVALID\nAPPLYING RESTRICTED ACCESS PROFILE...\nOPERATOR ACCESS MASK\n0001")
	return true


func discover_register() -> void:
	if not event_started or register_discovered:
		return
	register_discovered = true
	_set_story_flag(&"access_mask_register_discovered", true)
	_log("OPERATOR ACCESS REGISTER LOCATED\nMASK: %s" % get_mask_text())


func shift_operator_mask_left() -> bool:
	if not event_started or operator_access_mask != READ:
		return false
	operator_access_mask = WRITE
	write_permission_discovered = true
	_set_story_flag(&"write_permission_discovered", true)
	_emit_mask_changed()
	_log("ACCESS POLICY MODIFIED\nSOURCE: OPERATOR\nWRITE ACCESS: GRANTED\nREAD ACCESS: REVOKED")
	return true


func shift_operator_mask_right() -> bool:
	if not puzzle_completed or operator_access_mask != WRITE:
		return false
	operator_access_mask = READ
	_emit_mask_changed()
	_log("ACCESS MASK RESTORED\nWRITE ACCESS: REVOKED\nREAD ACCESS: GRANTED")
	return true


func notify_install_denied() -> void:
	if is_restricting_upgrade_installs():
		_log(get_install_denial_reason())


func notify_upgrade_installed() -> void:
	if not event_started or puzzle_completed or not has_operator_permission(WRITE):
		return
	puzzle_completed = true
	_set_story_flag(&"access_mask_puzzle_completed", true)
	_log("ACCESS POLICY MODIFIED\nSOURCE: OPERATOR\nWRITE ACCESS: GRANTED\nREAD ACCESS: REVOKED\nOPERATOR IS MODIFYING ITS OWN ACCESS PROFILE.")


func get_mask_text() -> String:
	return "%04d" % operator_access_mask


func get_save_data() -> Dictionary:
	return {"event_started": event_started, "operator_access_mask": operator_access_mask, "register_discovered": register_discovered, "write_permission_discovered": write_permission_discovered, "puzzle_completed": puzzle_completed, "completion_elapsed": _completion_elapsed}


func apply_save_data(data: Dictionary) -> void:
	var started := bool(data.get("event_started", false))
	event_started = started and _is_stage_five_complete()
	operator_access_mask = _sanitize_mask(data.get("operator_access_mask", INITIAL_MASK)) if event_started else INITIAL_MASK
	register_discovered = event_started and bool(data.get("register_discovered", false))
	write_permission_discovered = event_started and bool(data.get("write_permission_discovered", false)) and has_operator_permission(WRITE)
	puzzle_completed = event_started and bool(data.get("puzzle_completed", false))
	_completion_elapsed = clampf(float(data.get("completion_elapsed", 0.0)), 0.0, STAGE_START_DELAY_SECONDS)
	_sync_story_flags()
	_emit_mask_changed()


func reset() -> void:
	operator_access_mask = INITIAL_MASK
	event_started = false
	register_discovered = false
	write_permission_discovered = false
	puzzle_completed = false
	_completion_elapsed = 0.0
	_sync_story_flags()
	_emit_mask_changed()


func debug_start_event() -> bool:
	return start_event() if OS.is_debug_build() else false


func debug_set_mask(mask: int) -> bool:
	if not OS.is_debug_build() or not event_started or mask != READ and mask != WRITE:
		return false
	operator_access_mask = mask
	write_permission_discovered = mask == WRITE
	_set_story_flag(&"write_permission_discovered", write_permission_discovered)
	_emit_mask_changed()
	return true


func debug_apply_checkpoint(state: StringName) -> bool:
	if not OS.is_debug_build():
		return false
	reset()
	if state == &"inactive":
		return true
	if not _is_stage_five_complete():
		return false
	event_started = true
	register_discovered = state == &"register" or state == &"write" or state == &"complete"
	operator_access_mask = WRITE if state == &"write" or state == &"complete" else READ
	write_permission_discovered = operator_access_mask == WRITE
	puzzle_completed = state == &"complete"
	_sync_story_flags()
	_emit_mask_changed()
	return true


func _sanitize_mask(value: Variant) -> int:
	var mask := int(value) if value is int or value is float else INITIAL_MASK
	return mask if mask == READ or mask == WRITE else INITIAL_MASK


func _is_stage_five_complete() -> bool:
	var story := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"story_manager")
	return story != null and bool(story.get_flag(&"memory_failure_completed", false))


func _sync_story_flags() -> void:
	_set_story_flag(&"access_mask_event_started", event_started)
	_set_story_flag(&"access_mask_register_discovered", register_discovered)
	_set_story_flag(&"write_permission_discovered", write_permission_discovered)
	_set_story_flag(&"access_mask_puzzle_completed", puzzle_completed)


func _set_story_flag(flag_id: StringName, value: bool) -> void:
	var story := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"story_manager")
	if story != null:
		story.set_flag(flag_id, value)


func _emit_mask_changed() -> void:
	var events := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if events != null:
		events.access_mask_changed.emit(operator_access_mask)


func _log(message: String) -> void:
	var events := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if events != null:
		events.system_log_message.emit(message)
