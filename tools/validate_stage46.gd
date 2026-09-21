extends Node
const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")
const PRIMARY := "user://stage46_save.json"
const BACKUP := "user://stage46_backup.json"
const MAIN_SCENE := preload("res://ui/main/Main.tscn")

func _ready() -> void:
	await get_tree().process_frame
	var errors: PackedStringArray=[]
	var game:=AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	var db:=AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"content_db")
	var saves:=AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"save_manager")
	if game==null or db==null or saves==null: errors.append("autoload missing")
	else:
		saves.set_test_paths(PRIMARY,BACKUP); saves.reset_save()
		_validate_manual_power(errors, game, saves)
		if not game.owned_upgrades.is_empty(): errors.append("A fresh owns upgrades")
		if game.buy_upgrade(&"worker_threading"): errors.append("B locked bought")
		game.apply_save_data({"bits":10000.0,"generator_counts":{"worker":5,"terminal":5}})
		var worker_before:float=game.get_generator_production(&"worker")
		if not game.buy_upgrade(&"worker_threading"): errors.append("C unlocked failed")
		if abs(game.get_generator_production(&"worker")-worker_before*2.0)>0.01: errors.append("F worker multiplier")
		var terminal_before:float=game.get_generator_production(&"terminal")
		if abs(terminal_before - 6.0*(pow(1.04,5)-1.0)/0.04)>0.01: errors.append("G target leak")
		if not game.buy_upgrade(&"terminal_pipeline"): errors.append("terminal upgrade failed")
		if not game.buy_upgrade(&"vector_scheduler"): errors.append("global upgrade failed")
		if abs(game.get_global_production_multiplier()-1.25)>0.001: errors.append("H global")
		game.apply_save_data({"bits":1000.0,"generator_counts":{"worker":3},"owned_upgrades":["input_cache"]})
		if abs(game.get_manual_generation_amount() - pow(1.08, 3)) > 0.001: errors.append("I manual")
		if game.buy_upgrade(&"invalid") or db.get_upgrade_validation_errors().size()>0: errors.append("M/N invalid content")
		game.apply_save_data({"bits":10000.0,"generator_counts":{"worker":5},"owned_upgrades":["worker_threading"]})
		if not saves.save(): errors.append("K save")
		game.reset_save_data(); saves.load_game()
		if not game.is_upgrade_owned(&"worker_threading"): errors.append("K restore")
		var v2={"save_version":2,"saved_at_unix":int(Time.get_unix_time_from_system()),"game":{"bits":77.0,"generator_counts":{"worker":2}},"story":{"flags":{"operator_discovered":true}}}
		var f=FileAccess.open(PRIMARY,FileAccess.WRITE);f.store_string(JSON.stringify(v2));f.close();saves.load_game()
		if game.get_currency()!=77.0 or game.get_generator_count(&"worker")!=2 or not game.owned_upgrades.is_empty(): errors.append("L v2 migration")
		await _validate_ui(errors, game)
		saves.reset_save();saves.restore_default_paths()
	print("VALIDATION_RESULT:","OK" if errors.is_empty() else "ERRORS: "+", ".join(errors));get_tree().quit()

func _validate_manual_power(errors: PackedStringArray, game: Node, saves: Node) -> void:
	const GROWTH := 1.08
	# A: Workers alone must not modify manual power.
	game.apply_save_data({"bits": 0.0, "generator_counts": {"worker": 10}})
	if not is_equal_approx(game.get_manual_generation_amount(), 1.0): errors.append("manual A no-upgrade worker leak")
	# B-F: formula uses ownership count, including the zero-worker base case.
	for count in [0, 1, 5, 10, 25]:
		game.apply_save_data({"bits": 1000000.0, "generator_counts": {"worker": count}, "owned_upgrades": ["input_cache"]})
		var expected := pow(GROWTH, count)
		if abs(game.get_manual_generation_amount() - expected) > 0.0001: errors.append("manual %d workers" % count)
	# G: a normal purchase refreshes the calculation without reopening any UI.
	game.apply_save_data({"bits": 1000000.0, "generator_counts": {"worker": 10}, "owned_upgrades": ["input_cache"]})
	if game.buy_generator(&"worker") != true or abs(game.get_manual_generation_amount() - pow(GROWTH, 11)) > 0.0001: errors.append("manual G next worker refresh")
	# H: both ownership and count survive the normal save/load route.
	var before_save: float = game.get_manual_generation_amount()
	if not saves.save(): errors.append("manual H save")
	game.reset_save_data(); saves.load_game()
	if abs(game.get_manual_generation_amount() - before_save) > 0.0001: errors.append("manual H restore")
	# I-J: production modifiers and non-Worker counts cannot affect this effect.
	game.apply_save_data({"bits": 1000000.0, "generator_counts": {"worker": 10}, "owned_upgrades": ["input_cache", "worker_threading"]})
	if abs(game.get_manual_generation_amount() - pow(GROWTH, 10)) > 0.0001: errors.append("manual I production double-count")
	game.apply_save_data({"bits": 1000000.0, "generator_counts": {"worker": 10, "terminal": 99, "server": 99, "factory": 99, "data_center": 99}, "owned_upgrades": ["input_cache"]})
	if abs(game.get_manual_generation_amount() - pow(GROWTH, 10)) > 0.0001: errors.append("manual J other generator leak")
	# K-L: exact bulk and max APIs refresh once their final ownership count is committed.
	game.apply_save_data({"bits": 1000000.0, "generator_counts": {"worker": 3}, "owned_upgrades": ["input_cache"]})
	if game.buy_generators(&"worker", 10) != 10 or abs(game.get_manual_generation_amount() - pow(GROWTH, 13)) > 0.0001: errors.append("manual K buy ten")
	var maximum: int = game.get_max_affordable_generator_count(&"worker")
	if maximum < 1 or game.buy_generators(&"worker", maximum) != maximum or abs(game.get_manual_generation_amount() - pow(GROWTH, 13 + maximum)) > 0.0001: errors.append("manual L max")
	game.reset_save_data()

func _validate_ui(errors: PackedStringArray, game: Node) -> void:
	var story := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"story_manager")
	var puzzle := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"memory_puzzle")
	var shift := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"shift_manager")
	if story == null or puzzle == null or shift == null:
		errors.append("P Stage 5 autoload missing")
		return
	puzzle.reset()
	story.clear()
	shift.set_shift_active_for_test(false)
	var main := MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var ui := main.get_node("UI/NormalUI") as Control
	var store: Variant = ui.upgrade_store
	var manual_power := ui.get_node_or_null("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton/CoreReadout/ManualPowerLabel") as Label
	var worker_link := ui.get_node_or_null("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton/CoreReadout/WorkerLinkLabel") as Label
	var meta_overlay := main.get_node("UI/MetaOverlay") as Control
	var puzzle_overlay := ui.get_node("MemoryPuzzleOverlay") as Control
	if manual_power == null or not manual_power.text.contains("1 BIT / CLICK"):
		errors.append("Q manual base readout")
	# P-R: a real pointer press/release selects distinct available modules and
	# populates the inspector rather than merely checking that nodes exist.
	game.apply_save_data({"bits":1000000.0,"generator_counts":{"worker":5,"terminal":5,"server":1}})
	store._refresh()
	await get_tree().process_frame
	var first := _available_tile(store, &"input_cache")
	var second := _available_tile(store, &"worker_threading")
	if first == null or second == null:
		errors.append("P available module tiles missing")
	else:
		await _click_control(first)
		if store._selected != &"input_cache" or not store._inspector.visible or not store._detail.text.contains("WORKER INPUT LINK"):
			errors.append("P real click did not select first available module")
		await _click_control(second)
		if store._selected != &"worker_threading" or not store._detail.text.contains("WORKER THREADING"):
			errors.append("Q real click did not change selected module inspector")
	# S-T: affordable modules install, while unaffordable modules remain inspectable.
	game.apply_save_data({"bits":100.0,"generator_counts":{"worker":5,"terminal":5,"server":1}})
	store._refresh()
	await get_tree().process_frame
	var affordable := _available_tile(store, &"input_cache")
	var unaffordable := _available_tile(store, &"worker_threading")
	if affordable == null or unaffordable == null:
		errors.append("S affordability fixture modules missing")
	else:
		await _click_control(affordable)
		if store._install.disabled or not store._detail.text.contains("60 BITS"):
			errors.append("S affordable module inspector/install state is incorrect")
		await _click_control(unaffordable)
		if not store._install.disabled or not store._detail.text.contains("150 BITS"):
			errors.append("T unaffordable module was not inspectable/disabled")
		await _click_control(_available_tile(store, &"input_cache"))
		var before_install: float = game.get_currency()
		store._install.emit_signal("pressed")
		var after_install: float = game.get_currency()
		await get_tree().process_frame
		if not game.is_upgrade_owned(&"input_cache") or abs(after_install - (before_install - 60.0)) > 0.001:
			errors.append("U install did not deduct exact Bits or grant ownership")
		elif _available_tile(store, &"input_cache") != null or _installed_tile(store, &"input_cache") == null:
			errors.append("U installed module did not move between grids")
		else:
			var installed := _installed_tile(store, &"input_cache")
			await _click_control(installed)
			if store._selected != &"input_cache" or store._install.visible or not store._detail.text.contains("WORKER INPUT LINK"):
				errors.append("U installed module inspector state is incorrect")
			elif not manual_power.text.contains("1.47 BITS / CLICK") or worker_link == null or not worker_link.visible or not worker_link.text.contains("1.47"):
				errors.append("U Worker Input Link formula/readout changed")
	# V-W: full-rect decorative overlays remain input-transparent while inactive,
	# during an active Memory Puzzle, during SHIFT, and after completion.
	if meta_overlay.mouse_filter != Control.MOUSE_FILTER_IGNORE or puzzle_overlay.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		errors.append("V overlay root intercepts Module Bay input")
	story.set_flag(&"operator_discovered", true)
	story.set_flag(&"shift_state_unlocked", true)
	game.apply_save_data({"bits":1000000.0,"generator_counts":{"worker":5,"terminal":5,"server":1},"owned_upgrades":["input_cache","terminal_pipeline"]})
	store._refresh()
	puzzle.reset()
	if not puzzle.try_trigger():
		errors.append("V active puzzle fixture failed")
	else:
		puzzle.advance_for_test(1.0)
		await get_tree().process_frame
		var active_tile := _available_tile(store, &"worker_threading")
		if active_tile == null:
			errors.append("V active puzzle module missing")
		else:
			await _click_control(active_tile)
			if store._selected != &"worker_threading":
				errors.append("V active puzzle overlay blocked module selection")
		shift.set_shift_active_for_test(true)
		await get_tree().process_frame
		var shift_tile := _available_tile(store, &"vector_scheduler")
		if shift_tile == null:
			errors.append("W SHIFT module missing")
		else:
			await _click_control(shift_tile)
			if store._selected != &"vector_scheduler":
				errors.append("W SHIFT overlay blocked module selection")
		for bit_index in range(4):
			puzzle.place_bit(bit_index, bit_index)
		puzzle.place_bit(4, 4)
		await get_tree().process_frame
		shift.set_shift_active_for_test(false)
		await get_tree().process_frame
		var completed_tile := _available_tile(store, &"worker_threading")
		if completed_tile != null:
			await _click_control(completed_tile)
			if store._selected != &"worker_threading":
				errors.append("W completed puzzle state blocked module selection")
	shift.set_shift_active_for_test(false)
	shift.clear_test_override()
	puzzle.reset()
	main.queue_free()
	await get_tree().process_frame


func _available_tile(store: Variant, upgrade_id: StringName) -> Button:
	for child in store._grid.get_children():
		var tile := child as Button
		if tile != null and StringName(tile.get_meta(&"upgrade_id", &"")) == upgrade_id:
			return tile
	return null


func _installed_tile(store: Variant, upgrade_id: StringName) -> Button:
	for child in store._installed_grid.get_children():
		var tile := child as Button
		if tile != null and StringName(tile.get_meta(&"upgrade_id", &"")) == upgrade_id:
			return tile
	return null


## Godot's headless dummy renderer does not route synthetic pointer events to
## Controls, so invoke the real Button.pressed route that physical clicks emit.
func _click_control(control: Control) -> void:
	if control == null or not control.visible:
		return
	var button := control as Button
	if button == null:
		return
	button.emit_signal("pressed")
	await get_tree().process_frame
