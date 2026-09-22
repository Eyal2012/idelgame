extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")
const MAIN_SCENE := preload("res://ui/main/Main.tscn")
const CHECKPOINT_CATALOG := preload("res://ui/debug/debug_checkpoint_catalog.gd")
const PRIMARY := "user://stage6_validator_save.json"
const BACKUP := "user://stage6_validator_backup.json"
const TEMP := "user://stage6_validator.tmp"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var errors: PackedStringArray = []
	var game := _autoload(&"game")
	var story := _autoload(&"story_manager")
	var access := _autoload(&"access_mask_manager")
	var memory := _autoload(&"memory_puzzle")
	var saves := _autoload(&"save_manager")
	var shift := _autoload(&"shift_manager")
	if game == null or story == null or access == null or memory == null or saves == null or shift == null:
		errors.append("required Stage 6 autoload unavailable")
	else:
		saves.set_test_paths(PRIMARY, BACKUP, TEMP)
		saves.reset_save()
		_validate_authority_and_upgrade_flow(errors, game, story, access, memory)
		_validate_save_migration(errors, access, saves)
		await _validate_shift_presentation(errors, story, access, shift)
		saves.reset_save()
		saves.restore_default_paths()
	print("VALIDATION_RESULT:", "OK" if errors.is_empty() else "ERRORS: " + ", ".join(errors))
	get_tree().quit()


func _validate_authority_and_upgrade_flow(errors: PackedStringArray, game: Node, story: Node, access: Node, memory: Node) -> void:
	# A: the event cannot begin before Stage 5 completion.
	access.reset()
	story.clear()
	if access.debug_start_event() or access.event_started:
		errors.append("A Stage 6 activated before Stage 5 completion")
	# E: earlier upgrades remain unchanged before the security event.
	game.set_state({"bits": 1000.0, "generator_counts": {"worker": 3}, "owned_upgrades": []})
	if not game.buy_upgrade(&"input_cache"):
		errors.append("E normal upgrade install failed before Stage 6")
	# Set up a completed Stage 5 with a fresh, installable module.
	game.set_state({"bits": 1000.0, "generator_counts": {"worker": 5}, "owned_upgrades": []})
	story.debug_apply_state({"first_anomaly_started": true, "shift_state_unlocked": true, "operator_discovered": true, "memory_failure_completed": true, "operator_write_detected": true})
	memory.apply_save_data({"active": false, "completed": true, "escrow": 0.0, "slots": [0, 1, 2, 3, 4]})
	access.reset()
	if not access.debug_start_event():
		errors.append("B Stage 6 did not start after Stage 5 completion")
	if access.get_operator_access_mask() != access.READ or not access.has_operator_permission(access.READ) or access.has_operator_permission(access.WRITE):
		errors.append("B/C/D initial Access Mask is not READ-only 0001")
	var before_denied: float = game.get_currency()
	if game.buy_upgrade(&"input_cache"):
		errors.append("F restricted install unexpectedly succeeded")
	if not is_equal_approx(game.get_currency(), before_denied):
		errors.append("G denied install deducted Bits")
	if not access.shift_operator_mask_left() or access.get_operator_access_mask() != access.WRITE:
		errors.append("H/I left shift did not produce WRITE mask 0010")
	if access.has_operator_permission(access.READ) or not access.has_operator_permission(access.WRITE):
		errors.append("J permission transition did not revoke READ and grant WRITE")
	var upgrade_cost: float = game._get_upgrade_definition(&"input_cache").cost
	var before_install: float = game.get_currency()
	if not game.buy_upgrade(&"input_cache"):
		errors.append("K WRITE-authorized install failed")
	if not is_equal_approx(game.get_currency(), before_install - upgrade_cost):
		errors.append("L WRITE install did not deduct the exact cost once")
	if not access.puzzle_completed or not bool(story.get_flag(&"access_mask_puzzle_completed", false)):
		errors.append("M Stage 6 completion flag was not set")
	if not access.shift_operator_mask_right() or access.get_operator_access_mask() != access.READ:
		errors.append("N optional right shift did not restore 0001")
	if access.has_operator_permission(access.SYSTEM) or access.get_operator_access_mask() == 15:
		errors.append("O SYSTEM permission was granted")
	# R: legacy five-Bit puzzle escrow remains a five-way exact split.
	memory.apply_save_data({"active": true, "completed": false, "escrow": 5.0, "slots": [-1, -1, -1, -1, -1]})
	if memory.get_block_values() != [1.0, 1.0, 1.0, 1.0, 1.0]:
		errors.append("R Stage 5 legacy five-Bit escrow changed")


func _validate_save_migration(errors: PackedStringArray, access: Node, saves: Node) -> void:
	# P: Stage 6 state persists independently of Story flags.
	access.debug_apply_checkpoint(&"write")
	var saved: Dictionary = access.get_save_data()
	access.reset()
	access.apply_save_data(saved)
	if not access.event_started or access.get_operator_access_mask() != access.WRITE or not access.has_operator_permission(access.WRITE):
		errors.append("P save/load did not preserve Access Mask state")
	# Q: v4 gains an inactive, safe READ default and the later Stage 8 range
	# state must also remain inactive when migrated through the current schema.
	var old_save := {"save_version": 4, "saved_at_unix": 0, "game": {}, "story": {"flags": {"memory_failure_completed": true}}, "memory_puzzle": {}}
	var migrated: Dictionary = saves.migrate_save(old_save)
	var old_access: Dictionary = migrated.get("access_mask", {})
	var old_range: Dictionary = migrated.get("integer_range", {})
	if int(migrated.get("save_version", 0)) != 7 or bool(old_access.get("event_started", true)) or int(old_access.get("operator_access_mask", 0)) != access.READ or bool(old_range.get("stage_started", true)):
		errors.append("Q v4 migration did not create inactive READ-default access/range state")


func _validate_shift_presentation(errors: PackedStringArray, story: Node, access: Node, shift: Node) -> void:
	story.debug_apply_state({"shift_state_unlocked": true, "operator_discovered": true, "memory_failure_completed": true})
	access.debug_apply_checkpoint(&"restricted")
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var normal := main.get_node_or_null("UI/NormalUI") as Control
	var dialogue := main.get_node_or_null("UI/DialogueOverlay") as Control
	var debug_layer := main.get_node_or_null("UI/DebugOverlay") as Control
	var meta := main.get_node_or_null("UI/MetaOverlay") as Control
	var register := meta.get_node_or_null("AccessRegister") as Control if meta != null else null
	if normal == null or register == null or dialogue == null or debug_layer == null:
		errors.append("S/T Stage 6 presentation layers are missing")
	else:
		var root_margin := normal.get_node("RootMargin") as Control
		var base_position := root_margin.position
		shift.set_shift_active_for_test(true)
		await get_tree().process_frame
		if root_margin.position != base_position:
			errors.append("S normal UI moved under SHIFT")
		if not register.visible or register.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			errors.append("S Access Register did not appear as a non-blocking SHIFT diagnostic")
		var panel := register.get_node_or_null("AccessRegisterPanel") as Control
		var left := register.find_child("ShiftLeftButton", true, false) as Button
		if panel == null or panel.mouse_filter != Control.MOUSE_FILTER_IGNORE or left == null or left.mouse_filter != Control.MOUSE_FILTER_STOP:
			errors.append("T Access Register input filters are incorrect")
		if dialogue.mouse_filter != Control.MOUSE_FILTER_IGNORE or debug_layer.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			errors.append("T fixed input-transparent wrapper layers regressed")
		for viewport_size in [Vector2(900, 600), Vector2(1280, 720), Vector2(2560, 1440)]:
			var layout: Rect2 = register.get_layout_for_viewport(viewport_size)
			if not Rect2(Vector2.ZERO, viewport_size).encloses(layout):
				errors.append("Stage 6 Access Register clips at %s" % viewport_size)
		var definitions: Dictionary = {}
		for definition in CHECKPOINT_CATALOG.get_definitions():
			definitions[definition.id] = definition
		var dev_panel := main.get_node_or_null("UI/DebugOverlay/DevPanel") as DevPanel
		if not definitions.has(&"stage6_ready") or not definitions.has(&"stage6_access_restricted") or not definitions.has(&"stage6_access_register") or not definitions.has(&"stage6_write_enabled") or not definitions.has(&"stage6_complete"):
			errors.append("Stage 6 checkpoint resources are incomplete")
		elif dev_panel == null or not dev_panel.apply_checkpoint(definitions[&"stage6_write_enabled"]) or access.get_operator_access_mask() != access.WRITE:
			errors.append("DevPanel did not apply the Stage 6 WRITE checkpoint")
	shift.set_shift_active_for_test(false)
	shift.clear_test_override()
	main.queue_free()


func _autoload(id: StringName) -> Node:
	return AUTOLOAD_REGISTRY.get_autoload(get_tree(), id)
