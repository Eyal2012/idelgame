extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")
const MAIN_SCENE := preload("res://ui/main/Main.tscn")
const PRIMARY := "user://stage5_validator_save.json"
const BACKUP := "user://stage5_validator_backup.json"
const TEMP := "user://stage5_validator.tmp"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var errors: PackedStringArray = []
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	var story := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"story_manager")
	var saves := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"save_manager")
	var puzzle := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"memory_puzzle")
	var shift := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"shift_manager")
	if game == null or story == null or saves == null or puzzle == null or shift == null:
		errors.append("required Stage 5 autoload unavailable")
	else:
		saves.set_test_paths(PRIMARY, BACKUP, TEMP)
		saves.reset_save()
		var main := MAIN_SCENE.instantiate()
		add_child(main)
		await get_tree().process_frame
		await get_tree().process_frame
		var normal := main.get_node("UI/NormalUI") as Control
		var overlay := normal.get_node_or_null("MemoryPuzzleOverlay") as Control
		var meta_overlay := main.get_node("UI/MetaOverlay") as Control
		await _validate_core_and_visuals(errors, game, story, puzzle, shift, overlay, normal, meta_overlay)
		await _validate_save_states(errors, game, story, saves, puzzle)
		_validate_invalid_state(errors, puzzle)
		_validate_economy(errors, game, story, puzzle)
		await _validate_responsive_reachability(errors, game, story, puzzle, shift, overlay, normal)
		shift.set_shift_active_for_test(false)
		shift.clear_test_override()
		main.queue_free()
		saves.reset_save()
		saves.restore_default_paths()
	print("VALIDATION_RESULT:", "OK" if errors.is_empty() else "ERRORS: " + ", ".join(errors))
	get_tree().quit()


func _arm(game: Node, story: Node, puzzle: Node) -> bool:
	puzzle.reset()
	story.set_flag(&"operator_discovered", true)
	story.set_flag(&"shift_state_unlocked", true)
	game.apply_save_data({"bits": 1000000.0, "generator_counts": {"worker": 10, "terminal": 5, "server": 1}, "owned_upgrades": ["input_cache", "terminal_pipeline"]})
	var triggered: bool = puzzle.try_trigger()
	puzzle.advance_for_test(1.0)
	return triggered


func _validate_core_and_visuals(errors: PackedStringArray, game: Node, story: Node, puzzle: Node, shift: Node, overlay: Control, normal: Control, meta_overlay: Control) -> void:
	# A-B: fresh state and exact trigger requirements.
	if puzzle.active or puzzle.completed:
		errors.append("A fresh puzzle is not inactive")
	if puzzle.try_trigger():
		errors.append("B trigger ignored requirements")
	if not _arm(game, story, puzzle):
		errors.append("B valid requirements did not trigger")
		return
	var after_escrow: float = game.get_currency()
	if puzzle.try_trigger():
		errors.append("C trigger was not one-time")
	if not is_equal_approx(puzzle.escrow, 5.0) or not is_equal_approx(after_escrow, 999995.0) or after_escrow < 0.0:
		errors.append("D/E escrow debit is incorrect")
	if puzzle.get_escaped_bit_ids().size() != 5:
		errors.append("F logical bit count is incorrect")
	shift.set_shift_active_for_test(true)
	if overlay == null:
		errors.append("G overlay missing")
		return
	await get_tree().process_frame
	var visible_bits := 0
	for bit_index in range(5):
		if (overlay.bits[bit_index] as Control).visible:
			visible_bits += 1
	if visible_bits != 5:
		errors.append("G visual bit count is incorrect")
	for slot_index in range(4):
		if not (overlay.slots[slot_index] as Control).visible:
			errors.append("H primary socket %d is absent" % slot_index)
	if (overlay.slots[4] as Control).visible:
		errors.append("I fifth address appeared early")
	var base_position := (normal.get_node("RootMargin") as Control).position
	if (normal.get_node("RootMargin") as Control).position != base_position or not meta_overlay.visible:
		errors.append("AB/AC SHIFT diagnostic state is incorrect")
	# J-K: invoke the physical control handlers, then the same placement authority.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	overlay._on_bit_gui_input(click, 0)
	if puzzle.selected_bit != 0:
		errors.append("J click selection failed")
	overlay._on_socket_pressed(0)
	if puzzle.slots[0] != 0:
		errors.append("K click placement failed")
	# L-M: drag uses socket hit-testing; invalid drops leave state unchanged.
	if not overlay.simulate_drag_drop_for_test(1, 1) or puzzle.slots[1] != 1:
		errors.append("L drag placement failed")
	if overlay.simulate_invalid_drag_for_test(2) or puzzle.restored[2]:
		errors.append("M invalid drag changed state")
	# N-O: no logical bit or socket can be reused.
	if puzzle.place_bit(0, 2) or puzzle.place_bit(2, 0):
		errors.append("N/O duplicate mapping accepted")
	if not puzzle.place_bit(2, 2) or not puzzle.place_bit(3, 3) or puzzle.completed:
		errors.append("P four of five state is incorrect")
	await get_tree().process_frame
	if not puzzle.is_fifth_address_active() or not (overlay.slots[4] as Control).visible:
		errors.append("I fifth address discovery failed")
	var before_refund: float = game.get_currency()
	if not overlay.simulate_drag_drop_for_test(4, 4) or not puzzle.completed or puzzle.active:
		errors.append("Q fifth slot did not complete")
	if not is_equal_approx(game.get_currency(), before_refund + 5.0) or not is_equal_approx(puzzle.escrow, 0.0):
		errors.append("R exact escrow return failed")
	if puzzle.place_bit(4, 4) or not is_equal_approx(game.get_currency(), before_refund + 5.0):
		errors.append("S duplicate completion reward")
	await get_tree().process_frame
	for bit_index in range(5):
		if (overlay.bits[bit_index] as Control).visible:
			errors.append("AD escaped visual remained after completion")
	for slot_index in range(5):
		if (overlay.slots[slot_index] as Control).visible:
			errors.append("AD socket remained after completion")


func _validate_save_states(errors: PackedStringArray, game: Node, story: Node, saves: Node, puzzle: Node) -> void:
	# T: exactly two mappings persist without a second debit.
	_arm(game, story, puzzle)
	puzzle.place_bit(0, 0)
	puzzle.place_bit(2, 2)
	var bits_at_two: float = game.get_currency()
	if not saves.save():
		errors.append("T save failed")
	game.reset_save_data(); puzzle.reset(); saves.load_game()
	if not puzzle.active or puzzle.get_restored_count() != 2 or puzzle.get_escaped_bit_ids().size() != 3 or not is_equal_approx(puzzle.escrow, 5.0) or not is_equal_approx(game.get_currency(), bits_at_two):
		errors.append("T 2/5 reload failed")
	# U: fifth-address phase and elapsed hint data persist at four mappings.
	puzzle.place_bit(1, 1)
	puzzle.place_bit(3, 3)
	puzzle.advance_for_test(31.0)
	var hint_before: int = puzzle.hint_level
	if not saves.save():
		errors.append("U save failed")
	game.reset_save_data(); puzzle.reset(); saves.load_game()
	if not puzzle.active or puzzle.get_restored_count() != 4 or not puzzle.is_fifth_address_active() or puzzle.hint_level != hint_before:
		errors.append("U 4/5 reload failed")
	# V: completed state cannot leak escrow or reactivate after loading.
	puzzle.place_bit(4, 4)
	if not saves.save():
		errors.append("V save failed")
	game.reset_save_data(); puzzle.reset(); story.clear(); saves.load_game()
	if not puzzle.completed or puzzle.active or puzzle.escrow != 0.0 or not bool(story.get_flag(&"memory_failure_completed", false)) or not bool(story.get_flag(&"operator_write_detected", false)):
		errors.append("V completed reload failed")


func _validate_invalid_state(errors: PackedStringArray, puzzle: Node) -> void:
	puzzle.apply_save_data({"active": true, "completed": false, "escrow": 500.0, "restored": [true, true, true, true, true], "slots": [0, 0, 99, -1, -1]})
	if puzzle.escrow > 5.0 or puzzle.get_restored_count() != 1 or puzzle.slots[1] != -1:
		errors.append("W duplicate/large escrow sanitization failed")
	puzzle.apply_save_data({"active": true, "completed": false, "escrow": -1.0, "slots": [0, 1, 2, 3, 4]})
	if not puzzle.completed or puzzle.active or puzzle.escrow != 0.0:
		errors.append("W all-restored sanitization failed")
	puzzle.apply_save_data({"active": false, "completed": true, "escrow": 500.0, "slots": []})
	if puzzle.escrow != 0.0 or puzzle.active:
		errors.append("W completed escrow sanitization failed")
	puzzle.reset()


func _validate_economy(errors: PackedStringArray, game: Node, story: Node, puzzle: Node) -> void:
	if not _arm(game, story, puzzle):
		errors.append("X setup failed")
		return
	var before_production: float = game.get_currency()
	game.update_production(1.0)
	if game.get_currency() <= before_production:
		errors.append("X production paused during puzzle")
	if abs(game.get_manual_generation_amount() - pow(1.08, 10)) > 0.001:
		errors.append("Y Worker Input Link changed during puzzle")
	if not game.buy_generator(&"worker"):
		errors.append("Z process purchase failed during puzzle")
	if not game.buy_upgrade(&"worker_threading"):
		errors.append("AA upgrade purchase failed during puzzle")
	puzzle.reset()


func _validate_responsive_reachability(errors: PackedStringArray, game: Node, story: Node, puzzle: Node, shift: Node, overlay: Control, normal: Control) -> void:
	if overlay == null:
		return
	for viewport_size in [Vector2(900, 600), Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]:
		if not _arm(game, story, puzzle):
			errors.append("AE setup failed at %s" % viewport_size)
			continue
		var ui_parent := normal.get_parent() as Control
		ui_parent.size = viewport_size
		await get_tree().process_frame
		shift.set_shift_active_for_test(true)
		await get_tree().process_frame
		var centers: Array[Vector2] = []
		for bit_index in range(5):
			var rect := (overlay.bits[bit_index] as Control).get_global_rect()
			if not (overlay.bits[bit_index] as Control).visible or rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > viewport_size.x or rect.end.y > viewport_size.y:
				errors.append("AE unreachable bit at %s" % viewport_size)
			centers.append(rect.get_center())
		for left in range(centers.size()):
			for right in range(left + 1, centers.size()):
				if centers[left].distance_to(centers[right]) < 45.0:
					errors.append("AE clustered bits at %s" % viewport_size)
		puzzle.reset()
