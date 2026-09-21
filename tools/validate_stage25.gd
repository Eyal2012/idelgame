extends Node

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")
const NORMAL_UI_SCENE := preload("res://ui/main/NormalUI.tscn")
const PROCESS_ROWS_PATH := NodePath("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows")
const PROCESS_SCROLL_PATH := NodePath("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll")
const IDS := [&"worker", &"terminal", &"server", &"factory", &"data_center"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var errors: PackedStringArray = []
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if game == null:
		errors.append("Game autoload is unavailable")
	else:
		game.set_state({"bits": 0.0, "generator_counts": {}})
		var host := Control.new()
		host.size = Vector2(1280, 720)
		add_child(host)
		var ui := NORMAL_UI_SCENE.instantiate() as Control
		host.add_child(ui)
		await get_tree().process_frame
		await get_tree().process_frame
		_validate_start(errors, ui)
		for index in range(IDS.size()):
			var generator_id: StringName = IDS[index]
			var next_id: StringName = IDS[index + 1] if index + 1 < IDS.size() else &""
			await _acquire_and_validate(errors, ui, game, generator_id, next_id)
		_validate_compact_layout(errors, ui)
		host.queue_free()
	print("VALIDATION_RESULT:", "OK" if errors.is_empty() else "ERRORS: " + ", ".join(errors))
	get_tree().quit()


func _validate_start(errors: PackedStringArray, ui: Control) -> void:
	var rows := ui.get_node_or_null(PROCESS_ROWS_PATH) as VBoxContainer
	if rows == null:
		errors.append("Process rows container is missing")
		return
	if rows.get_child_count() != 1 or rows.get_node_or_null("worker") == null:
		errors.append("Only Worker should be visible at startup")
	for locked_id in IDS.slice(1):
		if rows.get_node_or_null(String(locked_id)) != null:
			errors.append("Locked row is visible at startup: %s" % locked_id)


func _acquire_and_validate(errors: PackedStringArray, ui: Control, game: Node, generator_id: StringName, next_id: StringName) -> void:
	var row_path := NodePath(str(PROCESS_ROWS_PATH) + "/" + str(generator_id))
	var row := ui.get_node_or_null(row_path) as Control
	if row == null:
		errors.append("Unlocked row is missing: %s" % generator_id)
		return
	var button := row.get_node_or_null("Margin/VBox/PurchaseRow/AcquireButton") as Button
	if button == null:
		errors.append("Acquire button is missing for %s" % generator_id)
		return
	game.debug_add_currency(game.get_generator_cost(generator_id))
	# Currency presentation is intentionally coalesced at 15 Hz.
	await get_tree().create_timer(0.08).timeout
	if button.disabled:
		errors.append("Acquire did not enable for funded %s" % generator_id)
		return
	button.emit_signal("pressed")
	await get_tree().process_frame
	if game.get_generator_count(generator_id) != 1:
		errors.append("Acquire button did not purchase %s" % generator_id)
	if not next_id.is_empty() and ui.get_node_or_null(NodePath(str(PROCESS_ROWS_PATH) + "/" + str(next_id))) == null:
		errors.append("%s did not appear after acquiring %s" % [next_id, generator_id])


func _validate_compact_layout(errors: PackedStringArray, ui: Control) -> void:
	var rows := ui.get_node_or_null(PROCESS_ROWS_PATH) as VBoxContainer
	var scroll := ui.get_node_or_null(PROCESS_SCROLL_PATH) as ScrollContainer
	if rows == null or scroll == null:
		return
	if rows.get_child_count() != IDS.size():
		errors.append("All five rows should be visible after progression")
	var row_metrics: PackedStringArray = []
	var max_row_height := 0.0
	for row in rows.get_children():
		if row is Control:
			max_row_height = maxf(max_row_height, row.size.y)
			var section_metrics: PackedStringArray = []
			var row_vbox := row.get_node_or_null("Margin/VBox")
			if row_vbox != null:
				for section in row_vbox.get_children():
					if section is Control:
						section_metrics.append("%s %.1f/min %.1f" % [section.name, section.size.y, section.get_combined_minimum_size().y])
			row_metrics.append("%s=%.1f(min %.1f; %s)" % [row.name, row.size.y, row.custom_minimum_size.y, "; ".join(section_metrics)])
			if row.size.y > 100.0:
				errors.append("Generator row is not compact: %s height=%.1f [%s]" % [row.name, row.size.y, "; ".join(section_metrics)])
			for button_name in ["AcquireButton", "Buy10Button", "MaxButton"]:
				var button := row.get_node_or_null("Margin/VBox/PurchaseRow/" + button_name) as Button
				if button == null or not row.get_global_rect().encloses(button.get_global_rect()):
					errors.append("Generator purchase control is clipped: %s/%s" % [row.name, button_name])
	# Stage 4.6 reserves the top of this same right panel for the compact module
	# bay; the remaining Process list must still expose several rows, not all five.
	if rows.size.y - scroll.size.y > 450.0:
		errors.append("Process scrolling is excessive beside the module bay at 1280x720 rows=%.1f scroll=%.1f [%s]" % [rows.size.y, scroll.size.y, ", ".join(row_metrics)])
	var visible_rows := scroll.size.y / max_row_height if max_row_height > 0.0 else 0.0
	if visible_rows < 2.75:
		errors.append("Fewer than three Process rows are practically visible at 1280x720: %.2f" % visible_rows)
	print("PROCESS_LAYOUT: row_height=%.1f scroll_height=%.1f visible_rows=%.2f" % [max_row_height, scroll.size.y, visible_rows])
	var process_vbox := scroll.get_parent()
	var panel_metrics: PackedStringArray = []
	for child in process_vbox.get_children():
		if child is Control:
			panel_metrics.append("%s=%.1f/min %.1f" % [child.name, child.size.y, child.get_combined_minimum_size().y])
	print("PROCESS_PANEL: %s" % "; ".join(panel_metrics))
