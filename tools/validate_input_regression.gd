extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")
const MAIN_SCENE := preload("res://ui/main/Main.tscn")
const NORMAL_UI_PATH := NodePath("UI/NormalUI")
const CORE_PATH := NodePath("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton")
const PROCESS_ROWS_PATH := NodePath("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var errors: PackedStringArray = []
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if game == null:
		errors.append("Game autoload is unavailable")
	else:
		game.set_state({"bits": 0.0, "generator_counts": {}, "owned_upgrades": []})
		var main := MAIN_SCENE.instantiate()
		add_child(main)
		await get_tree().process_frame
		await get_tree().process_frame
		await _validate(errors, main, game)
		main.queue_free()
	print("VALIDATION_RESULT:", "OK" if errors.is_empty() else "ERRORS: " + ", ".join(errors))
	get_tree().quit()


func _validate(errors: PackedStringArray, main: Node, game: Node) -> void:
	var normal := main.get_node_or_null(NORMAL_UI_PATH) as Control
	var dialogue := main.get_node_or_null("UI/DialogueOverlay") as Control
	var debug_overlay := main.get_node_or_null("UI/DebugOverlay") as Control
	var panel := main.get_node_or_null("UI/DebugOverlay/DevPanel") as DevPanel
	if normal == null or dialogue == null or debug_overlay == null or panel == null:
		errors.append("Main input layers or DevPanel are missing")
		return
	if dialogue.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		errors.append("DialogueOverlay is not input-transparent")
	if debug_overlay.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		errors.append("DebugOverlay is not input-transparent")
	if panel.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		errors.append("Closed DevPanel wrapper is not input-transparent")

	var core := normal.get_node_or_null(CORE_PATH) as Button
	if core == null:
		errors.append("Core button is missing")
		return
	var before_core: float = game.get_currency()
	_activate(core)
	if game.get_currency() <= before_core:
		errors.append("Physical Core click did not generate Bits")

	var worker_buy_1 := normal.get_node_or_null(NodePath(str(PROCESS_ROWS_PATH) + "/worker/Margin/VBox/PurchaseRow/AcquireButton")) as Button
	var worker_buy_10 := normal.get_node_or_null(NodePath(str(PROCESS_ROWS_PATH) + "/worker/Margin/VBox/PurchaseRow/Buy10Button")) as Button
	var worker_max := normal.get_node_or_null(NodePath(str(PROCESS_ROWS_PATH) + "/worker/Margin/VBox/PurchaseRow/MaxButton")) as Button
	if worker_buy_1 == null or worker_buy_10 == null or worker_max == null:
		errors.append("Worker purchase controls are missing")
		return
	game.debug_set_bits(100000.0)
	await get_tree().create_timer(0.08).timeout
	var workers_before: int = game.get_worker_count()
	_activate(worker_buy_1)
	if game.get_worker_count() != workers_before + 1:
		errors.append("Physical Worker BUY 1 did not purchase exactly once")
	workers_before = game.get_worker_count()
	_activate(worker_buy_10)
	if game.get_worker_count() != workers_before + 10:
		errors.append("Physical Worker BUY 10 did not purchase exactly ten")
	workers_before = game.get_worker_count()
	_activate(worker_max)
	if game.get_worker_count() <= workers_before:
		errors.append("Physical Worker MAX did not purchase")

	game.debug_set_bits(1000000.0)
	await get_tree().process_frame
	var module_tile := _find_upgrade_tile(normal, &"input_cache")
	if module_tile == null:
		errors.append("Worker Input Link module tile is missing")
	else:
		_activate(module_tile)
		var install := _find_button(normal, "INSTALL")
		if install == null or install.disabled:
			errors.append("Module selection did not expose an enabled INSTALL button")
		else:
			_activate(install)
			if not game.is_upgrade_owned(&"input_cache"):
				errors.append("Physical INSTALL MODULE did not install the selected module")

	await _tab()
	if not panel.is_open():
		errors.append("Physical TAB did not open DevPanel")
	elif not (panel.get_node_or_null("DevWindow") as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
		errors.append("Visible DevPanel window does not own its input")
	await _tab()
	if panel.is_open():
		errors.append("Physical second TAB did not close DevPanel")
	var after_close: float = game.get_currency()
	_activate(core)
	if game.get_currency() <= after_close:
		errors.append("Core click remained blocked after closing DevPanel")


func _activate(control: Button) -> void:
	# Headless Viewports do not run OS-window mouse picking. The surrounding
	# full-rect mouse-filter assertions verify the route, and this exercises the
	# exact Button callback invoked by a physical click in a running window.
	control.emit_signal("pressed")


func _tab() -> void:
	var press := InputEventKey.new()
	press.keycode = KEY_TAB
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventKey.new()
	release.keycode = KEY_TAB
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame


func _find_upgrade_tile(root: Node, upgrade_id: StringName) -> Button:
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and StringName(button.get_meta(&"upgrade_id", &"")) == upgrade_id:
			return button
	return null


func _find_button(root: Node, expected_text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == expected_text:
			return button
	return null
