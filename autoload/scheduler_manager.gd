extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")
const STAGE_START_DELAY_SECONDS := 180.0
const STARVED_GENERATOR_ID: StringName = &"terminal"
const EFFICIENCY_MULTIPLIER := 0.75
const CANONICAL_QUEUE: Array[StringName] = [&"buffer_read", &"worker_execute", &"result_verify", &"output_commit"]
const INITIAL_QUEUE: Array[StringName] = [&"buffer_read", &"output_commit", &"worker_execute", &"result_verify"]

var event_started := false
var event_completed := false
var execution_queue: Array[StringName] = INITIAL_QUEUE.duplicate()
var _completion_elapsed := 0.0


func _process(delta: float) -> void:
	if event_started or not _is_stage_six_complete(): return
	_completion_elapsed += maxf(0.0, delta)
	if _completion_elapsed >= STAGE_START_DELAY_SECONDS: start_event()

func is_stage7_active() -> bool: return event_started and not event_completed
func is_stage7_complete() -> bool: return event_completed
func get_execution_queue() -> Array[StringName]: return execution_queue.duplicate()
func get_starved_generator_id() -> StringName: return STARVED_GENERATOR_ID
func get_efficiency_multiplier(generator_id: StringName = STARVED_GENERATOR_ID) -> float:
	return EFFICIENCY_MULTIPLIER if is_stage7_active() and generator_id == STARVED_GENERATOR_ID else 1.0
func is_queue_valid() -> bool: return execution_queue == CANONICAL_QUEUE

func get_dependency_error() -> String:
	if is_queue_valid(): return "EXECUTION ORDER: VALID"
	var output_index := execution_queue.find(&"output_commit")
	var verify_index := execution_queue.find(&"result_verify")
	if output_index < verify_index: return "DEPENDENCY VIOLATION\nOUTPUT COMMIT WAITING FOR RESULT VERIFY"
	var verify := execution_queue.find(&"result_verify")
	var execute := execution_queue.find(&"worker_execute")
	if verify < execute: return "DEPENDENCY VIOLATION\nRESULT VERIFY WAITING FOR WORKER EXECUTE"
	return "DEPENDENCY VIOLATION\nWORKER EXECUTE WAITING FOR BUFFER READ"

func start_event() -> bool:
	if event_started or not _is_stage_six_complete(): return false
	event_started = true; event_completed = false; execution_queue = INITIAL_QUEUE.duplicate()
	_set_flag(&"scheduler_desync_started", true); _emit_changed()
	_log("SCHEDULER INTEGRITY CHECK\nEXECUTION ORDER: UNSTABLE\nPROCESS STARVATION DETECTED\nAUTOMATIC RECOVERY: FAILED\nOPERATOR INTERVENTION: NOT AUTHORIZED\nMANUAL SCHEDULER ACCESS AVAILABLE")
	return true

func move_task_up(task_id: StringName) -> bool: return _move(task_id, -1)
func move_task_down(task_id: StringName) -> bool: return _move(task_id, 1)
func _move(task_id: StringName, direction: int) -> bool:
	if not is_stage7_active(): return false
	var index := execution_queue.find(task_id); var target := index + direction
	if index < 0 or target < 0 or target >= execution_queue.size(): return false
	var value := execution_queue[index]; execution_queue[index] = execution_queue[target]; execution_queue[target] = value
	_emit_changed()
	if is_queue_valid(): _complete()
	return true

func _complete() -> void:
	if event_completed: return
	event_completed = true
	_set_flag(&"scheduler_desync_completed", true); _emit_changed()
	_log("PROCESS STARVATION CLEARED\nEXECUTION ORDER: VALID\nSCHEDULER OVERRIDE SOURCE: OPERATOR\nOPERATOR CONTROL SCOPE INCREASING")

func get_save_data() -> Dictionary:
	return {"event_started":event_started,"event_completed":event_completed,"execution_queue":Array(execution_queue),"completion_elapsed":_completion_elapsed}
func apply_save_data(data: Dictionary) -> void:
	event_started = bool(data.get("event_started",false)) and _is_stage_six_complete()
	event_completed = event_started and bool(data.get("event_completed",false))
	execution_queue = _sanitize_queue(data.get("execution_queue", INITIAL_QUEUE))
	if event_completed: execution_queue = CANONICAL_QUEUE.duplicate()
	_completion_elapsed = clampf(float(data.get("completion_elapsed",0.0)),0.0,STAGE_START_DELAY_SECONDS)
	_sync_flags(); _emit_changed()
func reset() -> void:
	event_started=false;event_completed=false;execution_queue=INITIAL_QUEUE.duplicate();_completion_elapsed=0.0;_sync_flags();_emit_changed()
func debug_apply_checkpoint(state: StringName) -> bool:
	if not OS.is_debug_build(): return false
	reset()
	if state == &"inactive": return true
	if not _is_stage_six_complete(): return false
	if state==&"ready": _completion_elapsed=STAGE_START_DELAY_SECONDS; return true
	event_started=true
	if state==&"partial": execution_queue=[&"buffer_read",&"worker_execute",&"output_commit",&"result_verify"]
	elif state==&"complete": execution_queue=CANONICAL_QUEUE.duplicate();event_completed=true
	_sync_flags();_emit_changed();return true

func _sanitize_queue(value: Variant) -> Array[StringName]:
	if not value is Array or value.size()!=CANONICAL_QUEUE.size(): return INITIAL_QUEUE.duplicate()
	var result:Array[StringName]=[]
	for raw in value:
		var id:=StringName(raw)
		if not CANONICAL_QUEUE.has(id) or result.has(id): return INITIAL_QUEUE.duplicate()
		result.append(id)
	return result
func _is_stage_six_complete() -> bool:
	var access:=AUTOLOAD_REGISTRY.get_autoload(get_tree(),&"access_mask_manager")
	return access != null and access.puzzle_completed
func _sync_flags()->void: _set_flag(&"scheduler_desync_started",event_started);_set_flag(&"scheduler_desync_completed",event_completed)
func _set_flag(id:StringName,value:bool)->void:
	var story:=AUTOLOAD_REGISTRY.get_autoload(get_tree(),&"story_manager");if story!=null:story.set_flag(id,value)
func _emit_changed()->void:
	var eb:=AUTOLOAD_REGISTRY.get_autoload(get_tree(),&"event_bus");if eb!=null:eb.scheduler_queue_changed.emit()
func _log(text:String)->void:
	var eb:=AUTOLOAD_REGISTRY.get_autoload(get_tree(),&"event_bus");if eb!=null:eb.system_log_message.emit(text)
