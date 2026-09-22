extends Node
const REG:=preload("res://autoload/autoload_registry.gd")
const MAIN:=preload("res://ui/main/Main.tscn")
const CATALOG:=preload("res://ui/debug/debug_checkpoint_catalog.gd")
func _ready()->void:
	await get_tree().process_frame;var errors:PackedStringArray=[]
	var game:=REG.get_autoload(get_tree(),&"game");var story:=REG.get_autoload(get_tree(),&"story_manager");var access:=REG.get_autoload(get_tree(),&"access_mask_manager");var scheduler:=REG.get_autoload(get_tree(),&"scheduler_manager");var range:=REG.get_autoload(get_tree(),&"integer_range_manager");var saves:=REG.get_autoload(get_tree(),&"save_manager")
	range.reset();if range.start_stage():errors.append("A Stage 8 began before Stage 7")
	var main:=MAIN.instantiate();add_child(main);await get_tree().process_frame;await get_tree().process_frame
	var normal:=main.get_node("UI/NormalUI") as Control;var capacity:=normal.find_child("Int32CapacityLabel",true,false) as Label
	if capacity==null or capacity.visible:errors.append("UI capacity display is visible before Stage 8")
	story.debug_apply_state({"memory_failure_completed":true,"shift_state_unlocked":true});access.debug_apply_checkpoint(&"complete");scheduler.debug_apply_checkpoint(&"complete")
	if not range.start_stage():errors.append("B Stage 8 did not start after Stage 7")
	game.debug_set_bits(game.get_currency());await get_tree().process_frame
	if capacity==null or not capacity.visible or not capacity.text.contains("INT32 CAPACITY"):errors.append("UI capacity display missing during Stage 8")
	if range.get_int32_max()!=2147483647.0:errors.append("C INT32 max incorrect")
	game.debug_set_bits(range.get_int32_max()*0.75);range._check_thresholds();if abs(range.get_capacity_percent()-75.0)>0.01 or not range.threshold_seen.has("0.75"):errors.append("D/E capacity or threshold incorrect")
	var seen_count:int=range.threshold_seen.size();range._check_thresholds();if range.threshold_seen.size()!=seen_count:errors.append("E threshold repeated")
	game.debug_set_bits(range.get_int32_max()-1.0);game.add_currency(100.0)
	if game.get_currency()!=range.get_int32_max() or not range.is_limit_reached():errors.append("I/K exact clamp latch failed")
	var at_limit:float=game.get_currency();game.update_production(10.0);game.generate_manual();if game.get_currency()!=at_limit:errors.append("L/M limit allowed currency growth")
	if game.get_currency()<0:errors.append("N negative overflow")
	var state:Dictionary=range.get_save_data();range.reset();range.apply_save_data(state);if not range.is_limit_reached():errors.append("O/P limit save did not persist")
	var old:Dictionary=saves.migrate_save({"save_version":6,"saved_at_unix":0,"game":{},"story":{},"memory_puzzle":{},"access_mask":{},"scheduler":{}});if int(old.get("save_version",0))!=7 or bool((old.get("integer_range",{}) as Dictionary).get("stage_started",true)):errors.append("Q v6 migration unsafe")
	if capacity==null or not capacity.visible or not capacity.text.contains("OUTPUT HALTED"):errors.append("UI capacity/halted display missing")
	var core:=normal.get_node("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel") as Control;var processes:=normal.get_node("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel") as Control;var sidebar:=normal.get_node("RootMargin/WorkspaceVBox/WorkspaceRow/SidebarPanel") as Control;var log_panel:=normal.get_node("RootMargin/WorkspaceVBox/LogPanel") as Control;var module_bay:=normal.get("upgrade_store") as Control;var core_pos:=core.position;var process_pos:=processes.position;var sidebar_pos:=sidebar.position;var log_pos:=log_panel.position;var module_bay_pos:=module_bay.position
	var shift:=REG.get_autoload(get_tree(),&"shift_manager");shift.set_shift_active_for_test(true);await get_tree().process_frame
	var register:=main.get_node_or_null("UI/MetaOverlay/IntegerRegister") as Control;if register==null or not register.visible or core.position!=core_pos or processes.position!=process_pos or sidebar.position!=sidebar_pos or log_panel.position!=log_pos or module_bay.position!=module_bay_pos:errors.append("SHIFT integer register/stationary layout failed")
	var register_text:=register.get_node_or_null("IntegerRegisterPanel/RegisterText") as Label;if register_text==null or not register_text.text.contains("TYPE   SIGNED INT32") or not register_text.text.contains("MIN    -2,147,483,648") or not register_text.text.contains("MAX     2,147,483,647") or not register_text.text.contains("CURRENT 2,147,483,647") or not register_text.text.contains("UTILIZATION 100.00%") or not register_text.text.contains("HEADROOM 0"):errors.append("SHIFT register values missing")
	var definitions:Dictionary={};for d in CATALOG.get_definitions():definitions[d.id]=d
	var panel:=main.get_node_or_null("UI/DebugOverlay/DevPanel") as DevPanel
	if panel!=null:panel.set_debug_access_for_test(true)
	for id in [&"stage8_ready",&"stage8_started",&"stage8_range_75",&"stage8_range_95",&"stage8_range_99",&"stage8_int32_max"]:
		if not definitions.has(id) or panel==null or not panel.apply_checkpoint(definitions[id]):errors.append("checkpoint failed %s"%id)
		elif id==&"stage8_ready" and (range.stage_started or not scheduler.is_stage7_complete()):errors.append("ready checkpoint state incoherent")
		elif id==&"stage8_started" and (not range.stage_started or range.is_limit_reached()):errors.append("started checkpoint state incoherent")
		elif id==&"stage8_range_75" and (abs(range.get_capacity_percent()-75.0)>0.01 or not range.threshold_seen.has("0.5") or not range.threshold_seen.has("0.75")):errors.append("75 percent checkpoint incoherent")
		elif id==&"stage8_range_95" and (abs(range.get_capacity_percent()-95.0)>0.01 or not range.threshold_seen.has("0.5") or not range.threshold_seen.has("0.75") or not range.threshold_seen.has("0.9") or not range.threshold_seen.has("0.95") or range.threshold_seen.has("0.99") or range.threshold_seen.has("1")):errors.append("95 percent checkpoint incoherent")
		elif id==&"stage8_range_99" and (abs(range.get_capacity_percent()-99.0)>0.01 or not range.threshold_seen.has("0.99") or range.threshold_seen.has("1")):errors.append("99 percent checkpoint incoherent")
	if game.get_currency()!=range.get_int32_max() or not range.is_limit_reached():errors.append("INT32 MAX checkpoint incoherent")
	if (main.get_node("UI/DialogueOverlay") as Control).mouse_filter!=Control.MOUSE_FILTER_IGNORE or (main.get_node("UI/DebugOverlay") as Control).mouse_filter!=Control.MOUSE_FILTER_IGNORE:errors.append("decorative overlays intercept input")
	shift.set_shift_active_for_test(false);shift.clear_test_override();main.queue_free()
	print("VALIDATION_RESULT:","OK" if errors.is_empty() else "ERRORS: "+", ".join(errors));get_tree().quit()
