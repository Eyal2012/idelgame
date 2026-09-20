extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")
const MAIN_SCENE := preload("res://ui/main/Main.tscn")
const PRIMARY := "user://stage4_validator_save.json"
const BACKUP := "user://stage4_validator_backup.json"
const TEMP := "user://stage4_validator.tmp"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var errors: PackedStringArray = []
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	var saves := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"save_manager")
	var story := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"story_manager")
	var meta := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"meta_director")
	var shift := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"shift_manager")
	if game == null or saves == null or story == null or meta == null or shift == null:
		errors.append("Required Stage 4 autoload unavailable")
	else:
		saves.set_test_paths(PRIMARY, BACKUP, TEMP)
		saves.reset_save()
		_validate_v1_migration(errors, game, saves, story)
		saves.reset_save()
		await _validate_anomaly_and_shift(errors, game, saves, story, meta, shift)
		saves.reset_save()
		saves.restore_default_paths()
	print("VALIDATION_RESULT:", "OK" if errors.is_empty() else "ERRORS: " + ", ".join(errors))
	get_tree().quit()


func _validate_v1_migration(errors: PackedStringArray, game: Node, saves: Node, story: Node) -> void:
	_write(PRIMARY, {"save_version": 1, "saved_at_unix": _now(), "game": {"bits": 222.0, "generator_counts": {"worker": 2, "terminal": 1}}})
	if not saves.load_game():
		errors.append("A/B: v1 save did not load and migrate")
	if game.get_currency() != 222.0 or game.get_generator_count(&"worker") != 2 or game.get_generator_count(&"terminal") != 1:
		errors.append("C/D: v1 migration changed game progress")
	for flag_id in [&"first_anomaly_started", &"shift_state_unlocked", &"operator_discovered"]:
		if bool(story.get_flag(flag_id, true)):
			errors.append("E: migrated story flag did not default false: %s" % flag_id)
	if not saves.save() or int(_read(PRIMARY).get("save_version", 0)) != saves.SAVE_VERSION:
		errors.append("B: migration did not save current structure")


func _validate_anomaly_and_shift(errors: PackedStringArray, game: Node, saves: Node, story: Node, meta: Node, shift: Node) -> void:
	# Fresh state: A/B/H and invalid-id safety.
	if bool(story.get_flag(&"shift_state_unlocked", true)) or bool(story.get_flag(&"first_anomaly_started", true)):
		errors.append("A/B: fresh story state was not locked")
	if meta.start_event(&"invalid_event"):
		errors.append("O: invalid meta id did not fail safely")
	if bool(story.get_flag(&"unknown_story_flag", false)):
		errors.append("O: invalid story flag did not fail safely")
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var normal := main.get_node("UI/NormalUI") as Control
	var root_margin := normal.get_node("RootMargin") as Control
	var overlay := main.get_node("UI/MetaOverlay") as Control
	var operator_button := overlay.get_node_or_null("HiddenOperator") as Button
	if operator_button == null or operator_button.visible:
		errors.append("H: hidden Operator object is available before unlock")
	var started_counter := {"value": 0}
	var callback := func(event_id: StringName) -> void:
		if event_id == &"first_anomaly":
			started_counter["value"] += 1
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	event_bus.meta_event_started.connect(callback)
	# C-E: intended ordinary progression condition; complete deterministically.
	game.apply_save_data({"bits": 150.0, "generator_counts": {"worker": 1, "terminal": 1}})
	for _step in range(6):
		meta._process(0.6)
	if not bool(story.get_flag(&"first_anomaly_started", false)) or not bool(story.get_flag(&"shift_state_unlocked", false)):
		errors.append("C/E: progression did not complete first anomaly")
	if meta.start_first_anomaly() or started_counter["value"] != 1:
		errors.append("D/N: first anomaly was not one-time")
	# F/G/I plus all requested sizes: activation must return to its exact base.
	var base_position := root_margin.position
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(900, 600)]:
		get_viewport().size = viewport_size
		await get_tree().process_frame
		shift.set_shift_active_for_test(true)
		if not shift.is_shift_active() or root_margin.position != base_position or not overlay.visible or not operator_button.visible:
			errors.append("F/I: SHIFT layer did not activate at %s" % viewport_size)
		shift.set_shift_active_for_test(false)
		if shift.is_shift_active() or root_margin.position != base_position or overlay.visible:
			errors.append("G/UI: SHIFT layout drift at %s" % viewport_size)
	# J/K: discovery is idempotent and does not create a second event/reward.
	shift.set_shift_active_for_test(true)
	operator_button.emit_signal("pressed")
	if not bool(story.get_flag(&"operator_discovered", false)) or operator_button.visible:
		errors.append("J: Operator discovery did not persist in story state")
	operator_button.emit_signal("pressed")
	if started_counter["value"] != 1:
		errors.append("K/N: repeated discovery retriggered meta state")
	shift.set_shift_active_for_test(false)
	shift.clear_test_override()
	# L/M: save/load flags and normal generator math continue to work.
	if not saves.save():
		errors.append("L: v2 save failed")
	story.clear()
	game.reset_save_data()
	saves.load_game()
	if not bool(story.get_flag(&"operator_discovered", false)) or not bool(story.get_flag(&"shift_state_unlocked", false)):
		errors.append("L: saved meta flags did not restore")
	if game.get_generator_count(&"terminal") != 1 or game.get_total_production_per_second() != 7.0:
		errors.append("M: generator gameplay changed after meta save/load")
	event_bus.meta_event_started.disconnect(callback)
	main.queue_free()


func _now() -> int:
	return int(Time.get_unix_time_from_system())


func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	return json.data if json.data is Dictionary else {}
