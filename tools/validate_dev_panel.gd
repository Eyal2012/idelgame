extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")
const MAIN_SCENE := preload("res://ui/main/Main.tscn")
const CHECKPOINT_CATALOG := preload("res://ui/debug/debug_checkpoint_catalog.gd")
const PRIMARY := "user://dev_panel_validator_save.json"
const BACKUP := "user://dev_panel_validator_backup.json"
const TEMP := "user://dev_panel_validator.tmp"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var errors: PackedStringArray = []
	var game := _autoload(&"game")
	var story := _autoload(&"story_manager")
	var puzzle := _autoload(&"memory_puzzle")
	var saves := _autoload(&"save_manager")
	if game == null or story == null or puzzle == null or saves == null:
		errors.append("required autoload unavailable")
	else:
		saves.set_test_paths(PRIMARY, BACKUP, TEMP)
		saves.reset_save()
		var main := MAIN_SCENE.instantiate()
		add_child(main)
		await get_tree().process_frame
		await get_tree().process_frame
		var panel := main.get_node_or_null("UI/DebugOverlay/DevPanel") as DevPanel
		if panel == null:
			errors.append("debug build did not create DevPanel")
		else:
			await _validate_panel(errors, panel, main, game, story, puzzle, saves)
		main.queue_free()
		saves.reset_save()
		saves.restore_default_paths()
	print("VALIDATION_RESULT:", "OK" if errors.is_empty() else "ERRORS: " + ", ".join(errors))
	get_tree().quit()


func _validate_panel(errors: PackedStringArray, panel: DevPanel, main: Node, game: Node, story: Node, puzzle: Node, saves: Node) -> void:
	# A-C: Tab toggles exactly once and suppresses a repeated event.
	_send_tab(panel, true, false)
	if not panel.is_open(): errors.append("A TAB did not open DevPanel")
	_send_tab(panel, true, true)
	if not panel.is_open(): errors.append("C repeated TAB toggled DevPanel")
	_send_tab(panel, false, false)
	_send_tab(panel, true, false)
	if panel.is_open(): errors.append("B TAB did not close DevPanel")
	_send_tab(panel, false, false)
	# D: test-only access gate represents a release build; actual release never instantiates it.
	panel.set_debug_access_for_test(false)
	_send_tab(panel, true, false)
	if panel.is_open(): errors.append("D simulated release opened DevPanel")
	_send_tab(panel, false, false)
	panel.set_debug_access_for_test(true)
	# E-G: actual Economy controls and focused text input use the panel route.
	game.debug_set_bits(0.0)
	panel._current_tab = "ECONOMY"; panel._rebuild_content()
	var add_100 := _find_button(panel, "+100 BITS")
	if add_100 != null: add_100.emit_signal("pressed")
	if not is_equal_approx(game.get_currency(), 100.0): errors.append("E add Bits failed")
	var bits_input := panel.find_child("SetBitsInput", true, false) as LineEdit
	if bits_input == null: errors.append("F set Bits field missing")
	else:
		bits_input.text = "1234"
		var apply: Button = _find_button_in_parent(bits_input.get_parent(), "APPLY")
		if apply != null: apply.emit_signal("pressed")
		if not is_equal_approx(game.get_currency(), 1234.0): errors.append("F set Bits failed")
		bits_input.grab_focus()
		panel.open(); _send_tab(panel, true, false)
		if panel.is_open() or bits_input.text.contains("\t"): errors.append("TAB did not take priority over focused LineEdit")
		_send_tab(panel, false, false)
	if panel._parse_non_negative("NaN") != null or panel._parse_non_negative("-5") != null or game.debug_set_bits(NAN): errors.append("G invalid numeric input accepted")
	# H-J: generic generator and upgrade mutations retain the established formula.
	game.debug_set_generator_count(&"worker", 0)
	panel._current_tab = "PROCESSES"; panel._rebuild_content()
	var add_workers := _find_button(panel, "+10")
	if add_workers != null: add_workers.emit_signal("pressed")
	if game.get_generator_count(&"worker") != 10: errors.append("H generator modification failed")
	panel._current_tab = "UPGRADES"; panel._rebuild_content()
	var worker_link := _find_button(panel, "WORKER INPUT LINK // INSTALL")
	if worker_link != null: worker_link.emit_signal("pressed")
	if not game.is_upgrade_owned(&"input_cache") or abs(game.get_manual_generation_amount() - pow(1.08, 10)) > 0.001: errors.append("I/J Worker Input Link did not update manual power")
	var remove_link := _find_button(panel, "WORKER INPUT LINK // REMOVE")
	if remove_link != null: remove_link.emit_signal("pressed")
	if game.is_upgrade_owned(&"input_cache") or not is_equal_approx(game.get_manual_generation_amount(), 1.0): errors.append("I upgrade removal failed")
	# K-O: resource checkpoints create coherent authoritative states.
	var definitions: Dictionary = {}
	for definition in CHECKPOINT_CATALOG.get_definitions(): definitions[definition.id] = definition
	if definitions.size() < 9: errors.append("checkpoint catalog did not discover current resources")
	if not panel.apply_checkpoint(definitions.get(&"stage4_anomaly_ready")) or game.get_generator_count(&"terminal") < 1 or game.get_currency() < 50.0 or bool(story.get_flag(&"first_anomaly_started", false)):
		errors.append("K Stage 4 checkpoint incoherent")
	if not panel.apply_checkpoint(definitions.get(&"stage5_memory_started")) or not puzzle.active or puzzle.get_restored_count() != 0 or not bool(story.get_flag(&"shift_state_unlocked", false)) or not bool(story.get_flag(&"operator_discovered", false)):
		errors.append("L Stage 5 0/5 checkpoint incoherent")
	if not panel.apply_checkpoint(definitions.get(&"stage5_memory_2")) or not puzzle.active or puzzle.get_restored_count() != 2 or puzzle.escrow <= 0.0:
		errors.append("M Stage 5 2/5 checkpoint incoherent")
	if not panel.apply_checkpoint(definitions.get(&"stage5_memory_4")) or not puzzle.active or puzzle.get_restored_count() != 4 or not puzzle.is_fifth_address_active():
		errors.append("N Stage 5 4/5 checkpoint incoherent")
	if not panel.apply_checkpoint(definitions.get(&"stage5_memory_complete")) or not puzzle.completed or puzzle.active or not bool(story.get_flag(&"memory_failure_completed", false)):
		errors.append("O Stage 5 completion checkpoint incoherent")
	# P: direct story cheats work through the StoryManager API.
	story.debug_set_flag(&"shift_state_unlocked", false)
	story.debug_set_flag(&"operator_discovered", false)
	if not story.debug_set_flag(&"shift_state_unlocked", true) or not story.debug_set_flag(&"operator_discovered", true) or not bool(story.get_flag(&"shift_state_unlocked")) or not bool(story.get_flag(&"operator_discovered")):
		errors.append("P SHIFT/OPERATOR cheats failed")
	# Q-R: save tool routes are real; reset stays confirmation-gated at the panel.
	game.debug_set_bits(4321.0)
	if not saves.debug_force_save() or not FileAccess.file_exists(PRIMARY): errors.append("Q force save did not use SaveManager path")
	game.debug_set_bits(0.0)
	if not saves.debug_reload_save() or game.get_currency() < 4321.0: errors.append("Q reload save did not use SaveManager path")
	panel._current_tab = "SAVE"; panel._rebuild_content()
	var reset_button := _find_button(panel, "RESET SAVE")
	if reset_button == null: errors.append("R reset save control missing")
	else:
		reset_button.emit_signal("pressed")
		if game.get_currency() <= 0.0 or not panel._reset_armed: errors.append("R reset save was not confirmation-gated")
		var confirm_button := _find_button(panel, "CONFIRM RESET SAVE")
		if confirm_button == null: errors.append("R confirmation label missing")
		else: confirm_button.emit_signal("pressed")
	# S: normal gameplay still functions while panel is closed.
	panel.close()
	var before: float = game.get_currency()
	var core := main.get_node_or_null("UI/NormalUI/RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton") as Button
	if core == null: errors.append("S normal Core unavailable")
	else:
		core.emit_signal("pressed")
		if game.get_currency() <= before: errors.append("S normal gameplay failed with panel closed")
	# T: opening/closing panel cannot alter production formula by itself.
	game.debug_set_generator_count(&"worker", 7)
	game.debug_set_upgrade_owned(&"input_cache", true)
	var manual_before: float = game.get_manual_generation_amount()
	var production_before: float = game.get_total_production_per_second()
	panel.open(); panel.close()
	if not is_equal_approx(game.get_manual_generation_amount(), manual_before) or not is_equal_approx(game.get_total_production_per_second(), production_before): errors.append("T DevPanel changed production math")
	# Responsive bounds at the four supported sizes.
	for viewport_size in [Vector2(900, 600), Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]:
		var layout := panel.get_layout_for_viewport(viewport_size)
		if not Rect2(Vector2.ZERO, viewport_size).encloses(layout): errors.append("responsive panel escaped %s" % viewport_size)


func _send_tab(panel: DevPanel, pressed: bool, echo: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_TAB
	event.pressed = pressed
	event.echo = echo
	panel._input(event)


func _find_button(root: Node, expected_text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.text == expected_text:
			return button
	return null


func _find_button_in_parent(parent: Node, expected_text: String) -> Button:
	for node in parent.get_children():
		if node is Button and (node as Button).text == expected_text:
			return node as Button
	return null


func _autoload(id: StringName) -> Node:
	return AUTOLOAD_REGISTRY.get_autoload(get_tree(), id)
