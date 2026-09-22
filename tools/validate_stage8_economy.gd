extends Node

const REG := preload("res://autoload/autoload_registry.gd")
const MAIN := preload("res://ui/main/Main.tscn")
const BASE_OWNED := ["input_cache", "terminal_pipeline", "worker_threading"]
const BASE_COUNTS := {"worker": 25, "terminal": 5, "server": 1}
const BOOST_IDS := [&"compute_override_i", &"compute_override_ii", &"compute_override_iii"]
const BOOST_MULTIPLIERS := [40.0, 25.0, 30.0]

func _ready() -> void:
	await get_tree().process_frame
	var errors: PackedStringArray = []
	var game := REG.get_autoload(get_tree(), &"game")
	var story := REG.get_autoload(get_tree(), &"story_manager")
	var access := REG.get_autoload(get_tree(), &"access_mask_manager")
	var scheduler := REG.get_autoload(get_tree(), &"scheduler_manager")
	var integer_range := REG.get_autoload(get_tree(), &"integer_range_manager")
	var content := REG.get_autoload(get_tree(), &"content_db")
	integer_range.reset()
	game.apply_save_data({"bits": 100000.0, "generator_counts": BASE_COUNTS, "owned_upgrades": BASE_OWNED})
	if not content.get_upgrade_validation_errors().is_empty(): errors.append("Stage 8 boost content is invalid")
	if game.is_upgrade_unlocked(BOOST_IDS[0]): errors.append("override I unlocks before Stage 8")
	story.debug_apply_state({"shift_state_unlocked": true, "memory_failure_completed": true, "operator_write_detected": true})
	access.debug_apply_checkpoint(&"complete")
	scheduler.debug_apply_checkpoint(&"complete")
	if not integer_range.start_stage(): errors.append("Stage 8 did not start for economy test")
	var baseline: float = game.get_total_production_per_second()
	if baseline <= 0.0 or not game.is_upgrade_unlocked(BOOST_IDS[0]) or game.is_upgrade_unlocked(BOOST_IDS[1]) or game.is_upgrade_unlocked(BOOST_IDS[2]): errors.append("sequential override unlock state incorrect")
	var main := MAIN.instantiate()
	add_child(main)
	await get_tree().process_frame
	var normal := main.get_node("UI/NormalUI") as Control
	var store: Variant = normal.get("upgrade_store")
	if _available_tile(store, BOOST_IDS[0]) == null:
		errors.append("override I is not visible in the Module Bay at Stage 8 start")
	for index in BOOST_IDS.size():
		var id: StringName = BOOST_IDS[index]
		var definition: UpgradeDefinition = content.get_upgrade(id)
		if definition == null or definition.cost <= 0.0 or not definition.requires_integer_range_started:
			errors.append("missing Stage 8 boost data %s" % id)
			continue
		var production_before: float = game.get_total_production_per_second()
		if _available_tile(store, id) == null:
			errors.append("%s is not visible when unlocked" % id)
		else:
			store.call("_on_module_pressed", id)
			if StringName(store.get("_selected")) != id or not (store.get("_inspector") as Control).visible:
				errors.append("%s Module Bay selection/inspector failed" % id)
		game.debug_set_bits(definition.cost)
		if not game.buy_upgrade(id):
			errors.append("could not buy %s" % id)
			continue
		if not is_equal_approx(game.get_currency(), 0.0): errors.append("%s price deduction is not exact" % id)
		var production_after: float = game.get_total_production_per_second()
		if not is_equal_approx(production_after, production_before * BOOST_MULTIPLIERS[index]): errors.append("%s multiplier did not apply exactly once" % id)
		if game.buy_upgrade(id): errors.append("%s installed twice" % id)
		if index + 1 < BOOST_IDS.size() and not game.is_upgrade_unlocked(BOOST_IDS[index + 1]): errors.append("next override did not unlock after %s" % id)
	var saved: Dictionary = game.get_save_data()
	game.apply_save_data({"bits": 0.0, "generator_counts": {}, "owned_upgrades": []})
	game.apply_save_data(saved)
	for id in BOOST_IDS:
		if not game.is_upgrade_owned(id): errors.append("%s did not survive save/load" % id)
		elif _installed_tile(store, id) == null: errors.append("%s installed state is missing from the Module Bay" % id)
	if not is_equal_approx(game.get_global_production_multiplier(), 30000.0): errors.append("final global multiplier is not 30000x")
	game.debug_set_bits(integer_range.get_int32_max() - 1.0)
	game.add_currency(game.get_total_production_per_second() * 10.0)
	var at_limit: float = game.get_currency()
	game.update_production(10.0)
	if at_limit != integer_range.get_int32_max() or game.get_currency() != at_limit or not integer_range.is_limit_reached(): errors.append("final boosts bypassed range latch")
	print("ECONOMY_PROFILE: baseline=%.3f final=%.3f multiplier=%.0f" % [baseline, baseline * 30000.0, game.get_global_production_multiplier()])
	print("VALIDATION_RESULT:", "OK" if errors.is_empty() else "ERRORS: " + ", ".join(errors))
	main.queue_free()
	get_tree().quit()


func _available_tile(store: Variant, upgrade_id: StringName) -> Button:
	if store == null:
		return null
	var grid: GridContainer = store.get("_grid") as GridContainer
	if grid == null:
		return null
	for tile in grid.get_children():
		if tile is Button and StringName(tile.get_meta(&"upgrade_id", &"")) == upgrade_id:
			return tile as Button
	return null


func _installed_tile(store: Variant, upgrade_id: StringName) -> Button:
	if store == null:
		return null
	var grid: HBoxContainer = store.get("_installed_grid") as HBoxContainer
	if grid == null:
		return null
	for tile in grid.get_children():
		if tile is Button and StringName(tile.get_meta(&"upgrade_id", &"")) == upgrade_id:
			return tile as Button
	return null
