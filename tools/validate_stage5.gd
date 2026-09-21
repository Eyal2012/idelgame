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
		_validate_ui_polish(errors, normal, meta_overlay)
		_validate_scaled_memory_blocks(errors, game, story, puzzle)
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


func _validate_ui_polish(errors: PackedStringArray, normal: Control, meta_overlay: Control) -> void:
	var sidebar := normal.get_node("RootMargin/WorkspaceVBox/WorkspaceRow/SidebarPanel") as Control
	var core_button := normal.get_node("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton") as Control
	for node in meta_overlay.find_children("*", "Label", true, false):
		var label := node as Label
		if label.text.contains("MEMORY BUS") or label.text.contains("PROCESS MAP") or label.text.contains("ADDRESS SPACE"):
			errors.append("UI diagnostic text remained in sidebar layer")
	var diagnostic := meta_overlay.get_child(0) as Control
	if diagnostic == null or diagnostic.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		errors.append("UI diagnostic decoration blocks input")
	for node in core_button.get_node("CoreReadout").get_children():
		if node is Control and not core_button.get_global_rect().encloses((node as Control).get_global_rect()):
			errors.append("UI core readout escaped core bounds")
	if sidebar.get_global_rect().has_point(core_button.get_global_rect().get_center()):
		errors.append("UI core overlaps sidebar")


func _arm(game: Node, story: Node, puzzle: Node, balance: float = 1000000.0) -> bool:
	puzzle.reset()
	story.set_flag(&"operator_discovered", true)
	story.set_flag(&"shift_state_unlocked", true)
	game.apply_save_data({"bits": balance, "generator_counts": {"worker": 10, "terminal": 5, "server": 1}, "owned_upgrades": ["input_cache", "terminal_pipeline"]})
	var triggered: bool = puzzle.try_trigger()
	puzzle.advance_for_test(1.0)
	return triggered


func _validate_scaled_memory_blocks(errors: PackedStringArray, game: Node, story: Node, puzzle: Node) -> void:
	# A-F: percentage escrow remains exact, visible, non-negative, and lossless
	# across the requested representative balances.
	for starting_bits in [100.0, 1000.0, 10000.0, 100000.0, 1000000.0]:
		if not _arm(game, story, puzzle, starting_bits):
			errors.append("scaled escrow did not trigger at %.0f Bits" % starting_bits)
			continue
		var expected_escrow: float = minf(floorf(starting_bits), maxf(puzzle.MIN_MEMORY_ESCROW, floorf(starting_bits * puzzle.MEMORY_ESCROW_PERCENT)))
		var block_values: Array[float] = puzzle.get_block_values()
		var block_total := 0.0
		for value in block_values:
			block_total += value
		print("MEMORY_BLOCK_CASE: start=%.0f escrow=%.0f addressable=%.0f blocks=%s" % [starting_bits, puzzle.get_escrow_amount(), game.get_currency(), block_values])
		if not is_equal_approx(puzzle.get_escrow_amount(), expected_escrow) or not is_equal_approx(game.get_currency(), starting_bits - expected_escrow) or game.get_currency() < 0.0:
			errors.append("scaled escrow debit is incorrect at %.0f Bits" % starting_bits)
		if block_values.size() != 5 or not is_equal_approx(block_total, expected_escrow):
			errors.append("five block values do not sum to escrow at %.0f Bits" % starting_bits)
		puzzle.reset()
	# E: deterministic quotient/remainder allocation cannot lose a Bit.
	puzzle.apply_save_data({"active": true, "completed": false, "escrow": 5003.0, "slots": [-1, -1, -1, -1, -1]})
	if puzzle.get_block_values() != [1001.0, 1001.0, 1001.0, 1000.0, 1000.0] or not is_equal_approx(puzzle.get_unresolved_value(), 5003.0):
		errors.append("remainder split is not exact")
	# M: an optional malformed display cache is ignored; escrow remains the sole authority.
	puzzle.apply_save_data({"active": true, "completed": false, "escrow": 100.0, "block_values": [999999.0, -1.0], "slots": [-1, -1, -1, -1, -1]})
	if puzzle.get_block_values() != [20.0, 20.0, 20.0, 20.0, 20.0]:
		errors.append("malformed block-value state influenced authoritative split")
	puzzle.reset()
	game.reset_save_data()
	story.clear()


func _validate_core_and_visuals(errors: PackedStringArray, game: Node, story: Node, puzzle: Node, shift: Node, overlay: Control, normal: Control, meta_overlay: Control) -> void:
	# A-B: fresh state and exact trigger requirements.
	if puzzle.active or puzzle.completed:
		errors.append("A fresh puzzle is not inactive")
	if puzzle.try_trigger():
		errors.append("B trigger ignored requirements")
	if not _arm(game, story, puzzle, 100000.0):
		errors.append("B valid requirements did not trigger")
		return
	await get_tree().process_frame
	var guidance := overlay.get_node_or_null("Guidance") as Label
	var core_title := normal.get_node("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreTitleLabel") as Label
	if guidance == null or not guidance.visible:
		errors.append("UI puzzle guidance is missing at puzzle start")
	elif guidance.get_global_rect().intersects(core_title.get_global_rect()):
		errors.append("UI puzzle guidance overlaps the Core heading")
	elif not guidance.text.contains("MEMORY ACCOUNTING FAILURE") or not guidance.text.contains("5,000 BITS"):
		errors.append("UI start guidance does not present Memory Block accounting")
	var after_escrow: float = game.get_currency()
	var escrow_before_completion: float = puzzle.get_escrow_amount()
	if puzzle.try_trigger():
		errors.append("C trigger was not one-time")
	if not is_equal_approx(escrow_before_completion, 5000.0) or not is_equal_approx(after_escrow, 95000.0) or after_escrow < 0.0:
		errors.append("D/E escrow debit is incorrect")
	if puzzle.get_escaped_bit_ids().size() != 5 or puzzle.get_block_values().size() != 5 or not is_equal_approx(puzzle.get_unresolved_value(), escrow_before_completion) or not is_equal_approx(puzzle.get_block_value(&"bit_0"), 1000.0):
		errors.append("F logical Memory Block count/value is incorrect")
	if overlay == null:
		errors.append("G overlay missing")
		return
	for bit_index in range(5):
		var block := overlay.bits[bit_index] as Button
		if not block.text.contains("MB-%02d" % [bit_index + 1]) or not block.text.contains("1,000"):
			errors.append("G overlay did not present MemoryPuzzle block value")
			break
	shift.set_shift_active_for_test(true)
	await get_tree().process_frame
	if guidance != null and guidance.visible:
		errors.append("UI redundant puzzle guidance remains over the SHIFT route view")
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
	var remaining_ids: Array[int] = puzzle.get_escaped_bit_ids()
	if remaining_ids.size() != 1 or not is_equal_approx(puzzle.get_unresolved_value(), puzzle.get_block_value(remaining_ids[0])):
		errors.append("P unresolved value does not match final Memory Block")
	shift.set_shift_active_for_test(false)
	await get_tree().process_frame
	if guidance == null or not guidance.visible or not guidance.text.contains("4 / 5 BLOCKS RESTORED") or not guidance.text.contains("1,000 BITS"):
		errors.append("P four-of-five Memory Block value display is incorrect")
	shift.set_shift_active_for_test(true)
	await get_tree().process_frame
	if not puzzle.is_fifth_address_active() or not (overlay.slots[4] as Control).visible:
		errors.append("I fifth address discovery failed")
	var before_refund: float = game.get_currency()
	if not overlay.simulate_drag_drop_for_test(4, 4) or not puzzle.completed or puzzle.active:
		errors.append("Q fifth slot did not complete")
	if not is_equal_approx(game.get_currency(), before_refund + escrow_before_completion) or not is_equal_approx(puzzle.escrow, 0.0):
		errors.append("R exact escrow return failed")
	print("MEMORY_BLOCK_PLAYTHROUGH: start=100000 escrow=%.0f addressable=%.0f pre_completion=%.0f post_completion=%.0f" % [escrow_before_completion, after_escrow, before_refund, game.get_currency()])
	if puzzle.place_bit(4, 4) or not is_equal_approx(game.get_currency(), before_refund + escrow_before_completion):
		errors.append("S duplicate completion reward")
	await get_tree().process_frame
	for bit_index in range(5):
		if (overlay.bits[bit_index] as Control).visible:
			errors.append("AD escaped visual remained after completion")
	for slot_index in range(5):
		if (overlay.slots[slot_index] as Control).visible:
			errors.append("AD socket remained after completion")


func _validate_save_states(errors: PackedStringArray, game: Node, story: Node, saves: Node, puzzle: Node) -> void:
	# K: a pre-Stage-5.2 v4 save keeps its explicitly stored five-Bit escrow.
	var legacy_save: Dictionary = saves.build_save_data()
	legacy_save["saved_at_unix"] = int(Time.get_unix_time_from_system())
	legacy_save["game"] = {"bits": 995.0, "generator_counts": {"worker": 10, "terminal": 5, "server": 1}, "owned_upgrades": ["input_cache", "terminal_pipeline"]}
	legacy_save["story"] = {"flags": {"operator_discovered": true, "shift_state_unlocked": true}}
	legacy_save["memory_puzzle"] = {"active": true, "completed": false, "escrow": 5.0, "slots": [0, 1, -1, -1, -1], "hint_level": 0}
	var legacy_file := FileAccess.open(PRIMARY, FileAccess.WRITE)
	if legacy_file == null:
		errors.append("K legacy v4 fixture write failed")
	else:
		legacy_file.store_string(JSON.stringify(legacy_save))
		legacy_file.close()
		game.reset_save_data(); puzzle.reset(); story.clear(); saves.load_game()
		if not puzzle.active or puzzle.get_restored_count() != 2 or not is_equal_approx(puzzle.get_escrow_amount(), 5.0) or not is_equal_approx(puzzle.get_unresolved_value(), 3.0):
			errors.append("K old v4 mid-puzzle escrow was reinterpreted")
	# T: exactly two mappings persist without a second debit.
	_arm(game, story, puzzle)
	puzzle.place_bit(0, 0)
	puzzle.place_bit(2, 2)
	var bits_at_two: float = game.get_currency()
	if not saves.save():
		errors.append("T save failed")
	game.reset_save_data(); puzzle.reset(); saves.load_game()
	if not puzzle.active or puzzle.get_restored_count() != 2 or puzzle.get_escaped_bit_ids().size() != 3 or not is_equal_approx(puzzle.escrow, 50000.0) or not is_equal_approx(game.get_currency(), bits_at_two):
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
	puzzle.apply_save_data({"active": true, "completed": false, "escrow": 500.75, "restored": [true, true, true, true, true], "block_values": [999999.0], "slots": [0, 0, 99, -1, -1]})
	if not is_equal_approx(puzzle.escrow, 500.0) or puzzle.get_restored_count() != 1 or puzzle.slots[1] != -1 or puzzle.get_block_values() != [100.0, 100.0, 100.0, 100.0, 100.0]:
		errors.append("W duplicate/malformed Memory Block sanitization failed")
	puzzle.apply_save_data({"active": true, "completed": false, "escrow": -1.0, "slots": [-1, -1, -1, -1, -1]})
	if puzzle.active or puzzle.escrow != 0.0:
		errors.append("W non-positive active escrow sanitization failed")
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
		var processes := normal.get_node("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel") as Control
		for bit_index in range(5):
			if (overlay.bits[bit_index] as Control).get_global_rect().intersects(processes.get_global_rect()):
				errors.append("AE puzzle Bit covers Process controls at %s" % viewport_size)
		for slot_index in range(4):
			if (overlay.slots[slot_index] as Control).get_global_rect().intersects(processes.get_global_rect()):
				errors.append("AE puzzle socket covers Process controls at %s" % viewport_size)
		for left in range(centers.size()):
			for right in range(left + 1, centers.size()):
				if centers[left].distance_to(centers[right]) < 45.0:
					errors.append("AE clustered bits at %s" % viewport_size)
		puzzle.reset()
