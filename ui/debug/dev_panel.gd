class_name DevPanel
extends Control

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")
const NUMBER_FORMATTER := preload("res://core/number_formatter.gd")
const CHECKPOINT_CATALOG := preload("res://ui/debug/debug_checkpoint_catalog.gd")

var _window: PanelContainer
var _content: VBoxContainer
var _tabs: HBoxContainer
var _current_tab := "STATE"
var _tab_down := false
var _debug_access_override := -1
var _reset_armed := false
var _pause_when_open := false
var _state_refresh_elapsed := 0.0
var state_refresh_count: int = 0

const TABS := ["STATE", "ECONOMY", "PROCESSES", "UPGRADES", "STORY", "PUZZLES", "SAVE", "UI"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_set_open(false)
	get_viewport().size_changed.connect(_fit_to_viewport)


func _process(delta: float) -> void:
	if not is_open() or _current_tab != "STATE":
		return
	_state_refresh_elapsed += delta
	if _state_refresh_elapsed >= 0.25:
		_state_refresh_elapsed = 0.0
		state_refresh_count += 1
		_rebuild_content()


func _input(event: InputEvent) -> void:
	if not _debug_access_allowed() or not event is InputEventKey or event.keycode != KEY_TAB:
		return
	if event.pressed:
		if event.echo or _tab_down:
			get_viewport().set_input_as_handled()
			return
		_tab_down = true
		_set_open(not is_open())
		get_viewport().set_input_as_handled()
	elif not event.pressed:
		_tab_down = false
		get_viewport().set_input_as_handled()


func set_debug_access_for_test(enabled: bool) -> void:
	_debug_access_override = 1 if enabled else 0
	if not enabled:
		_set_open(false)


func is_open() -> bool:
	return _window != null and _window.visible


func open() -> void:
	if _debug_access_allowed():
		_set_open(true)


func close() -> void:
	_set_open(false)


func apply_checkpoint(definition: DebugCheckpointDefinition) -> bool:
	if not _debug_access_allowed() or definition == null:
		return false
	var game := _autoload(&"game")
	var story := _autoload(&"story_manager")
	var puzzle := _autoload(&"memory_puzzle")
	var access := _autoload(&"access_mask_manager")
	var scheduler := _autoload(&"scheduler_manager")
	if game == null or story == null or puzzle == null or access == null or scheduler == null:
		return false
	puzzle.debug_reset_current_puzzle()
	var state := {"bits": definition.bits, "generator_counts": definition.generator_counts, "owned_upgrades": Array(definition.owned_upgrades)}
	if not game.debug_apply_state(state):
		return false
	if not story.debug_apply_state(definition.story_flags):
		return false
	var success := true
	match definition.memory_state:
		&"active": success = puzzle.debug_set_progress(definition.memory_progress)
		&"complete": success = puzzle.debug_complete()
		_: puzzle.reset()
	if success:
		success = access.debug_apply_checkpoint(definition.access_mask_state)
	if success:
		success = scheduler.debug_apply_checkpoint(definition.scheduler_state)
	game.debug_refresh_ui()
	_rebuild_content()
	return success


func _build() -> void:
	_window = PanelContainer.new()
	_window.name = "DevWindow"
	_window.mouse_filter = Control.MOUSE_FILTER_STOP
	_window.add_theme_stylebox_override("panel", _panel_style())
	add_child(_window)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 7)
	_window.add_child(shell)
	var title_row := HBoxContainer.new()
	shell.add_child(title_row)
	var title := Label.new()
	title.text = "BIT//SHIFT // DEV PANEL"
	title.add_theme_color_override("font_color", Color("72d5ed"))
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "[TAB] CLOSE"
	close_button.pressed.connect(close)
	title_row.add_child(close_button)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 3)
	shell.add_child(_tabs)
	for tab_name in TABS:
		var tab := Button.new()
		tab.name = tab_name.capitalize() + "Tab"
		tab.text = tab_name
		tab.toggle_mode = true
		tab.button_pressed = tab_name == _current_tab
		tab.pressed.connect(func() -> void: _select_tab(tab_name))
		_tabs.add_child(tab)
	var scroll := ScrollContainer.new()
	scroll.name = "ContentScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(scroll)
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.custom_minimum_size.x = 390.0
	_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_content)
	_fit_to_viewport()
	_rebuild_content()


func _fit_to_viewport() -> void:
	if _window == null:
		return
	var layout := get_layout_for_viewport(get_viewport_rect().size)
	_window.position = layout.position
	_window.size = layout.size


func get_layout_for_viewport(viewport_size: Vector2) -> Rect2:
	var desired_size := Vector2(minf(490.0, viewport_size.x - 24.0), minf(740.0, viewport_size.y - 76.0))
	var panel_size := Vector2(maxf(300.0, desired_size.x), maxf(320.0, desired_size.y))
	panel_size.x = minf(panel_size.x, viewport_size.x)
	panel_size.y = minf(panel_size.y, viewport_size.y)
	var panel_position := Vector2(clampf(16.0, 0.0, maxf(0.0, viewport_size.x - panel_size.x)), clampf(52.0, 0.0, maxf(0.0, viewport_size.y - panel_size.y)))
	return Rect2(panel_position, panel_size)


func _set_open(opened: bool) -> void:
	if _window == null:
		return
	_window.visible = opened and _debug_access_allowed()
	set_process(_window.visible)
	_reset_armed = false
	if not opened:
		get_tree().paused = false
		get_viewport().gui_release_focus()
	_fit_to_viewport()


func _select_tab(tab_name: String) -> void:
	_current_tab = tab_name
	for tab in _tabs.get_children():
		if tab is Button:
			(tab as Button).button_pressed = (tab as Button).text == tab_name
	_rebuild_content()


func _rebuild_content() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()
	match _current_tab:
		"STATE": _build_state()
		"ECONOMY": _build_economy()
		"PROCESSES": _build_processes()
		"UPGRADES": _build_upgrades()
		"STORY": _build_story()
		"PUZZLES": _build_puzzles()
		"SAVE": _build_save()
		"UI": _build_ui()


func _build_state() -> void:
	var game := _autoload(&"game")
	var story := _autoload(&"story_manager")
	var puzzle := _autoload(&"memory_puzzle")
	var saves := _autoload(&"save_manager")
	_section("CURRENT STATE")
	if game == null or story == null or puzzle == null:
		_info("SYSTEMS UNAVAILABLE")
		return
	_info("BITS: %s    BITS / SEC: %s    BITS / CLICK: %s" % [NUMBER_FORMATTER.format(game.get_currency()), NUMBER_FORMATTER.format(game.get_total_production_per_second(), 2), NUMBER_FORMATTER.format(game.get_manual_generation_amount(), 2)])
	_info("SAVE VERSION: %s" % (saves.SAVE_VERSION if saves != null else "?"))
	_info("SHIFT: %s    OPERATOR: %s" % ["UNLOCKED" if story.get_flag(&"shift_state_unlocked", false) else "LOCKED", "DISCOVERED" if story.get_flag(&"operator_discovered", false) else "UNKNOWN"])
	var memory_status := "COMPLETE" if puzzle.completed else "%d/5" % puzzle.get_restored_count() if puzzle.active else "INACTIVE"
	_info("STORY: %s    MEMORY PUZZLE: %s" % ["STAGE 5" if puzzle.active or puzzle.completed else "STAGE 4" if story.get_flag(&"first_anomaly_started", false) else "FRESH", memory_status])
	_info("INSTALLED UPGRADES: %d" % game.owned_upgrades.size())
	var db := _autoload(&"content_db")
	if db != null:
		for definition in db.get_generators():
			_info("%s: %d" % [definition.display_name, game.get_generator_count(definition.id)])


func _build_economy() -> void:
	_section("ECONOMY CHEATS")
	var game := _autoload(&"game")
	for amount in [100.0, 1000.0, 100000.0, 1000000.0]:
		_button("+%s BITS" % NUMBER_FORMATTER.format(amount), func() -> void: game.debug_add_currency(amount))
	var set_row := HBoxContainer.new()
	_content.add_child(set_row)
	var input := LineEdit.new()
	input.name = "SetBitsInput"
	input.placeholder_text = "SET BITS (non-negative finite)"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_row.add_child(input)
	_button_in(set_row, "APPLY", func() -> void:
		var value: Variant = _parse_non_negative(input.text)
		if value == null: input.placeholder_text = "INVALID NUMBER"; return
		game.debug_set_bits(float(value)))
	_button("SET TO 0", func() -> void: game.debug_set_bits(0.0))
	_button("NEAR INT32 LIMIT // 2,147,483,000", func() -> void: game.debug_set_bits(2147483000.0))
	_button("INT32 MAX // 2,147,483,647", func() -> void: game.debug_set_bits(2147483647.0))


func _build_processes() -> void:
	_section("PROCESS COUNTS // DATA-DRIVEN")
	var db := _autoload(&"content_db")
	var game := _autoload(&"game")
	if db == null or game == null:
		return
	for definition in db.get_generators():
		var row := VBoxContainer.new()
		_content.add_child(row)
		var label := Label.new()
		label.text = "%s // OWNED: %d" % [definition.display_name, game.get_generator_count(definition.id)]
		row.add_child(label)
		var controls := HBoxContainer.new()
		row.add_child(controls)
		for delta in [-1, 1, 10]:
			_button_in(controls, ("%+d" % delta), func() -> void: game.debug_set_generator_count(definition.id, max(0, game.get_generator_count(definition.id) + delta)); _rebuild_content())
		var input := LineEdit.new()
		input.name = "SetProcessCount_" + String(definition.id)
		input.placeholder_text = "SET"
		input.custom_minimum_size.x = 70
		controls.add_child(input)
		_button_in(controls, "APPLY", func() -> void:
			var value: Variant = _parse_non_negative_int(input.text)
			if value != null: game.debug_set_generator_count(definition.id, int(value)); _rebuild_content())


func _build_upgrades() -> void:
	_section("UPGRADE CHEATS // DATA-DRIVEN")
	var game := _autoload(&"game")
	var db := _autoload(&"content_db")
	_button("INSTALL ALL UPGRADES", func() -> void: game.debug_set_all_upgrades(true); _rebuild_content())
	_button("CLEAR ALL UPGRADES", func() -> void: game.debug_set_all_upgrades(false); _rebuild_content())
	if db == null:
		return
	for definition in db.get_upgrades():
		var owned: bool = game.is_upgrade_owned(definition.id)
		_button("%s // %s" % [definition.display_name, "REMOVE" if owned else "INSTALL"], func() -> void: game.debug_set_upgrade_owned(definition.id, not game.is_upgrade_owned(definition.id)); _rebuild_content())


func _build_story() -> void:
	_section("JUMP TO // CHECKPOINTS")
	var by_stage: Dictionary = {}
	for definition in CHECKPOINT_CATALOG.get_definitions():
		if not by_stage.has(definition.stage): by_stage[definition.stage] = definition
	for stage in by_stage:
		var definition: DebugCheckpointDefinition = by_stage[stage]
		_button("JUMP %s" % stage, func() -> void: apply_checkpoint(definition))
	_section("ALL CHECKPOINTS")
	for definition in CHECKPOINT_CATALOG.get_definitions():
		_button(definition.display_name, func() -> void: apply_checkpoint(definition))
	_section("SHIFT / OPERATOR")
	var story := _autoload(&"story_manager")
	_button("UNLOCK SHIFT", func() -> void: story.debug_set_flag(&"shift_state_unlocked", true))
	_button("LOCK SHIFT", func() -> void: story.debug_set_flag(&"shift_state_unlocked", false))
	_button("DISCOVER OPERATOR", func() -> void: story.debug_set_flag(&"operator_discovered", true))
	_button("RESET OPERATOR DISCOVERY", func() -> void: story.debug_set_flag(&"operator_discovered", false))
	var meta := _autoload(&"meta_director")
	var access := _autoload(&"access_mask_manager")
	_button("FORCE FIRST ANOMALY", func() -> void: meta.debug_force_first_anomaly())
	_button("ACCESS MASK: 0001", func() -> void: access.debug_set_mask(access.READ) if access != null else null)
	_button("ACCESS MASK: 0010", func() -> void: access.debug_set_mask(access.WRITE) if access != null else null)


func _build_puzzles() -> void:
	_section("MEMORY PUZZLE // AUTHORITATIVE TOOLS")
	var puzzle := _autoload(&"memory_puzzle")
	_button("START MEMORY PUZZLE", func() -> void: puzzle.debug_start(); _rebuild_content())
	for progress in range(5):
		_button("SET %d/5" % progress, func() -> void: puzzle.debug_set_progress(progress); _rebuild_content())
	_button("COMPLETE MEMORY PUZZLE", func() -> void: puzzle.debug_complete(); _rebuild_content())
	_button("RESET CURRENT PUZZLE", func() -> void: puzzle.debug_reset_current_puzzle(); _rebuild_content())


func _build_save() -> void:
	_section("SAVE TOOLS")
	var saves := _autoload(&"save_manager")
	_info("SAVE TARGET: %s" % ("DEV // user://dev_save.json" if saves.debug_is_using_dev_save() else "PLAYER // cheats modify current save"))
	if not saves.debug_is_using_dev_save():
		_info("Launch a debug build with `-- --dev-save` to use the isolated DEV SAVE.")
	_button("FORCE SAVE", func() -> void: saves.debug_force_save())
	_button("RELOAD SAVE", func() -> void: saves.debug_reload_save(); _rebuild_content())
	_button("AUTOSAVE: %s" % ("ON" if saves.debug_is_autosave_enabled() else "OFF"), func() -> void: saves.debug_set_autosave_enabled(not saves.debug_is_autosave_enabled()); _rebuild_content())
	_button("RESET STORY", func() -> void: _autoload(&"story_manager").debug_reset_story(); _autoload(&"memory_puzzle").debug_reset_current_puzzle(); _rebuild_content())
	_button("CONFIRM RESET SAVE" if _reset_armed else "RESET SAVE", func() -> void:
		if _reset_armed: saves.debug_reset_save(); _reset_armed = false
		else: _reset_armed = true
		_rebuild_content())


func _build_ui() -> void:
	_section("UI STATE TOOLS")
	var game := _autoload(&"game")
	var story := _autoload(&"story_manager")
	_button("UNLOCK ALL CURRENT UI", func() -> void: story.debug_set_flag(&"first_anomaly_started", true); story.debug_set_flag(&"shift_state_unlocked", true); story.debug_set_flag(&"operator_discovered", true); game.debug_refresh_ui())
	_button("FORCE SHIFT UNLOCK", func() -> void: story.debug_set_flag(&"shift_state_unlocked", true))
	_button("REFRESH UI", func() -> void: game.debug_refresh_ui())
	_button("ENTER TOP-DOWN PROTOTYPE", func() -> void: close(); get_tree().change_scene_to_file("res://dev/topdown/TopDownPrototype.tscn"))
	_button("PAUSE WHILE OPEN: %s" % ("ON" if _pause_when_open else "OFF"), func() -> void: _pause_when_open = not _pause_when_open; get_tree().paused = _pause_when_open and is_open(); _rebuild_content())


func _section(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("bc9cff"))
	label.add_theme_font_size_override("font_size", 13)
	_content.add_child(label)


func _info(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("b4c3e4"))
	_content.add_child(label)


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	_content.add_child(button)
	return button


func _button_in(parent: Container, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _parse_non_negative(text: String) -> Variant:
	var clean := text.strip_edges()
	if clean.is_empty() or not clean.is_valid_float():
		return null
	var value := clean.to_float()
	return value if not is_nan(value) and not is_inf(value) and value >= 0.0 else null


func _parse_non_negative_int(text: String) -> Variant:
	var clean := text.strip_edges()
	if clean.is_empty() or not clean.is_valid_int():
		return null
	var value := clean.to_int()
	return value if value >= 0 else null


func _autoload(id: StringName) -> Node:
	return AUTOLOAD_REGISTRY.get_autoload(get_tree(), id)


func _debug_access_allowed() -> bool:
	return OS.is_debug_build() and _debug_access_override != 0


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101328f2")
	style.border_color = Color("72d5ed")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	return style
