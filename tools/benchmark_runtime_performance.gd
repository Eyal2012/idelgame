extends Node

## Development-only architectural benchmark. It intentionally reports timings
## but only fails on behavioral/performance regressions, never machine FPS.
const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")
const MAIN_SCENE := preload("res://ui/main/Main.tscn")
const PRIMARY := "user://performance_benchmark_save.json"
const BACKUP := "user://performance_benchmark_backup.json"
const TEMP := "user://performance_benchmark.tmp"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var errors: PackedStringArray = []
	var game := _autoload(&"game")
	var story := _autoload(&"story_manager")
	var puzzle := _autoload(&"memory_puzzle")
	var saves := _autoload(&"save_manager")
	var events := _autoload(&"event_bus")
	if game == null or story == null or puzzle == null or saves == null or events == null:
		errors.append("required performance systems unavailable")
	else:
		saves.set_test_paths(PRIMARY, BACKUP, TEMP)
		saves.reset_save()
		var main := MAIN_SCENE.instantiate()
		add_child(main)
		await get_tree().process_frame
		await get_tree().process_frame
		await _run_benchmark(errors, main, game, story, puzzle, events)
		main.queue_free()
		saves.reset_save()
		saves.restore_default_paths()
	print("PERFORMANCE_RESULT:", "OK" if errors.is_empty() else "ERRORS: " + ", ".join(errors))
	get_tree().quit()


func _run_benchmark(errors: PackedStringArray, main: Node, game: Node, story: Node, puzzle: Node, events: Node) -> void:
	var normal := main.get_node("UI/NormalUI") as Control
	var store: Variant = normal.upgrade_store
	var panel := main.get_node("UI/DebugOverlay/DevPanel") as DevPanel
	var counts := {"currency": 0}
	events.currency_changed.connect(func(_a: StringName, _b: float, _c: float) -> void: counts["currency"] += 1)
	game.debug_apply_state({"bits": 2000000000.0, "generator_counts": {"worker": 1000, "terminal": 500, "server": 250, "factory": 100, "data_center": 50}, "owned_upgrades": _all_upgrade_ids()})
	story.debug_apply_state({"first_anomaly_started": true, "shift_state_unlocked": true, "operator_discovered": true, "memory_failure_completed": true, "operator_write_detected": true})
	puzzle.debug_complete()
	await get_tree().process_frame
	var structural_before: int = store.structural_refresh_count
	var passive_before: int = normal.passive_refresh_count
	var panel_before: int = panel.state_refresh_count
	var start := Time.get_ticks_usec()
	for _frame in range(120):
		await get_tree().process_frame
	var elapsed_ms := float(Time.get_ticks_usec() - start) / 1000.0
	var passive_delta: int = normal.passive_refresh_count - passive_before
	print("PERF_HEAVY_COMPLETED: frames=120 elapsed_ms=%.2f currency_signals=%d ui_passive_refreshes=%d module_rebuilds=%d" % [elapsed_ms, int(counts["currency"]), passive_delta, store.structural_refresh_count - structural_before])
	if counts["currency"] < 100: errors.append("heavy state did not exercise passive currency path")
	if passive_delta > 35: errors.append("passive NormalUI refresh exceeded 15Hz architecture")
	if store.structural_refresh_count != structural_before: errors.append("Module Bay rebuilt from passive currency ticks")
	if panel.state_refresh_count != panel_before: errors.append("hidden DevPanel refreshed while closed")
	# Geometric production should be near constant in Process ownership count.
	game.debug_set_generator_count(&"worker", 10)
	var small_us := _measure_production(game, 4000)
	game.debug_set_generator_count(&"worker", 10000)
	var large_us := _measure_production(game, 4000)
	print("PERF_GENERATOR_MATH: workers=10 %.2fus workers=10000 %.2fus" % [small_us, large_us])
	if large_us > small_us * 8.0 + 50.0: errors.append("generator production scaled materially with owned count")
	# Repeated panel, SHIFT, puzzle and Core interactions must return to a stable node range.
	var node_before := _node_count(main)
	for _index in range(100):
		panel.open(); panel.close()
		var shift := _autoload(&"shift_manager")
		shift.set_shift_active_for_test(true); shift.set_shift_active_for_test(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var node_after := _node_count(main)
	if node_after > node_before + 4: errors.append("panel/SHIFT stress grew node count %d -> %d" % [node_before, node_after])
	game.debug_set_generator_count(&"worker", 25)
	game.debug_set_upgrade_owned(&"input_cache", true)
	var core: Button = normal.core_button as Button
	for _click in range(50): core.emit_signal("pressed")
	if not is_instance_valid(normal._core_feedback_tween) or abs(game.get_manual_generation_amount() - pow(1.08, 25)) > 0.001:
		errors.append("rapid Core click stress broke tween bound or Worker Input Link")
	# Active puzzle/SHIFT can redraw on state events, but should not rebuild controls.
	puzzle.debug_reset_current_puzzle()
	game.debug_set_bits(100000.0)
	puzzle.debug_set_progress(4)
	var overlay := normal.get_node("MemoryPuzzleOverlay") as Control
	var bit_count: int = overlay.bits.size()
	for _index in range(30):
		events.system_log_message.emit("PERF EVENT")
	if normal._system_log_history.size() > normal.SYSTEM_LOG_HISTORY_LIMIT or bit_count != 5:
		errors.append("bounded log or MemoryPuzzleOverlay regression")
	print("PERF_STRESS: nodes=%d->%d overlay_bits=%d log_history=%d" % [node_before, node_after, bit_count, normal._system_log_history.size()])


func _measure_production(game: Node, iterations: int) -> float:
	var start := Time.get_ticks_usec()
	for _index in range(iterations):
		game.get_total_production_per_second()
	return float(Time.get_ticks_usec() - start) / float(iterations)


func _all_upgrade_ids() -> Array:
	var ids: Array = []
	var db := _autoload(&"content_db")
	if db != null:
		for definition in db.get_upgrades(): ids.append(definition.id)
	return ids


func _node_count(node: Node) -> int:
	var count := 1
	for child in node.get_children(): count += _node_count(child)
	return count


func _autoload(id: StringName) -> Node:
	return AUTOLOAD_REGISTRY.get_autoload(get_tree(), id)
