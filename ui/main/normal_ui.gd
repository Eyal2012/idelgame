extends Control

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")
const GENERATOR_ROW_SCENE := preload("res://ui/components/GeneratorRow.tscn")
const NUMBER_FORMATTER := preload("res://core/number_formatter.gd")
const UPGRADE_STORE := preload("res://ui/components/upgrade_store.gd")
const MEMORY_OVERLAY := preload("res://ui/meta/memory_puzzle_overlay.gd")

var bits_label: Label
var manual_power_label: Label
var per_second_label: Label
var worker_link_label: Label
var core_button: Button
var system_log_label: Label
var process_rows: VBoxContainer
var shift_indicator: Label
var upgrade_store: PanelContainer
var _core_feedback_tween: Tween
var _anomaly_tween: Tween
var _displayed_generator_ids: Dictionary = {}
var _unlock_message_pending: bool = false
const PASSIVE_DISPLAY_INTERVAL := 1.0 / 15.0
const SYSTEM_LOG_HISTORY_LIMIT := 60
var _passive_display_elapsed := 0.0
var _passive_display_dirty := false
var _system_log_history: Array[String] = []
var economy_refresh_count: int = 0
var passive_refresh_count: int = 0


func _ready() -> void:
	bits_label = get_node("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton/CoreReadout/BitsLabel")
	manual_power_label = get_node("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton/CoreReadout/ManualPowerLabel")
	per_second_label = get_node("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton/CoreReadout/PerSecondInsideLabel")
	worker_link_label = get_node("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton/CoreReadout/WorkerLinkLabel")
	core_button = get_node("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton")
	system_log_label = get_node("RootMargin/WorkspaceVBox/LogPanel/LogVBox/SystemLogLabel")
	process_rows = get_node("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows")
	shift_indicator = get_node("RootMargin/WorkspaceVBox/HeaderPanel/HeaderRow/ShiftIndicator")
	core_button.pressed.connect(_on_generate_pressed)
	var upgrades_button := get_node("RootMargin/WorkspaceVBox/WorkspaceRow/SidebarPanel/SidebarVBox/UpgradesNavLabel") as Button
	upgrades_button.pressed.connect(_toggle_upgrades)
	upgrade_store = UPGRADE_STORE.new()
	var processes_vbox := process_rows.get_parent().get_parent() as VBoxContainer
	processes_vbox.add_child(upgrade_store)
	processes_vbox.move_child(upgrade_store, 0)
	var memory_overlay:=MEMORY_OVERLAY.new();memory_overlay.name="MemoryPuzzleOverlay";add_child(memory_overlay)
	_connect_signals()
	_configure_shift_layer()
	_apply_theme()
	_sync_generator_rows(false)
	_refresh()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	call_deferred("_apply_responsive_layout")


func _process(delta: float) -> void:
	if not _passive_display_dirty:
		return
	_passive_display_elapsed += delta
	if _passive_display_elapsed < PASSIVE_DISPLAY_INTERVAL:
		return
	_passive_display_elapsed = 0.0
	_passive_display_dirty = false
	passive_refresh_count += 1
	_refresh()
	_refresh_passive_children()


func _connect_signals() -> void:
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus == null:
		return
	if not event_bus.is_connected("currency_changed", _on_currency_changed):
		event_bus.currency_changed.connect(_on_currency_changed)
	if not event_bus.is_connected("generator_bought", _on_generator_bought):
		event_bus.generator_bought.connect(_on_generator_bought)
	if not event_bus.is_connected("upgrade_bought", _on_upgrade_bought):
		event_bus.upgrade_bought.connect(_on_upgrade_bought)
	if not event_bus.is_connected("load_completed", _on_load_completed):
		event_bus.load_completed.connect(_on_load_completed)
	if not event_bus.is_connected("system_log_message", _on_system_log_message):
		event_bus.system_log_message.connect(_on_system_log_message)
	if not event_bus.is_connected("anomaly_visual_requested", _on_anomaly_visual_requested):
		event_bus.anomaly_visual_requested.connect(_on_anomaly_visual_requested)
	if not event_bus.is_connected("shift_state_changed", _on_shift_state_changed):
		event_bus.shift_state_changed.connect(_on_shift_state_changed)
	if not event_bus.is_connected("story_flag_changed", _on_story_flag_changed):
		event_bus.story_flag_changed.connect(_on_story_flag_changed)


func _configure_shift_layer() -> void:
	var shift := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"shift_manager")
	var overlay := get_node_or_null("../MetaOverlay")
	var core_panel := get_node("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel") as Control
	if overlay != null and overlay.has_method("configure"):
		overlay.configure(core_panel)
		if overlay.has_signal("operator_selected"):
			overlay.operator_selected.connect(_on_operator_selected)
	if shift != null and overlay is Control:
		shift.register_shift_pair(get_node("RootMargin") as Control, overlay as Control)
	_refresh_shift_indicator()


func _sync_generator_rows(reveal_new_rows: bool) -> Array:
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if game == null:
		return []
	var newly_displayed: Array = []
	for definition in game.get_unlocked_generators():
		if _displayed_generator_ids.has(definition.id):
			continue
		var row := GENERATOR_ROW_SCENE.instantiate()
		process_rows.add_child(row)
		row.configure(definition)
		row.generator_acquired.connect(_on_generator_acquired)
		_displayed_generator_ids[definition.id] = true
		newly_displayed.append(definition)
		if reveal_new_rows:
			row.call_deferred("play_reveal")
	return newly_displayed


func _apply_theme() -> void:
	_style_panel(get_node("RootMargin/WorkspaceVBox/HeaderPanel"), Color("11152a"), Color("363a65"), 6, 14, 7)
	_style_panel(get_node("RootMargin/WorkspaceVBox/WorkspaceRow/SidebarPanel"), Color("0d1122"), Color("2b3154"), 6, 14, 14)
	_style_panel(get_node("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel"), Color("10152a"), Color("454177"), 10, 18, 16)
	_style_panel(get_node("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel"), Color("0d1122"), Color("2b3154"), 6, 14, 14)
	_style_panel(get_node("RootMargin/WorkspaceVBox/LogPanel"), Color("0b1020"), Color("28304d"), 6, 14, 10)

	_set_label_color("RootMargin/WorkspaceVBox/HeaderPanel/HeaderRow/BrandLabel", Color("f1efff"))
	_set_label_color("RootMargin/WorkspaceVBox/HeaderPanel/HeaderRow/SystemStatusLabel", Color("72d5ed"))
	_set_label_color("RootMargin/WorkspaceVBox/HeaderPanel/HeaderRow/BuildLabel", Color("9aa5c2"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/SidebarPanel/SidebarVBox/SidebarTitleLabel", Color("8e9bbd"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/SidebarPanel/SidebarVBox/CoreNavLabel", Color("bc9cff"))
	for path in ["ProcessesNavLabel", "UpgradesNavLabel", "ArchiveNavLabel", "SettingsNavLabel"]:
		_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/SidebarPanel/SidebarVBox/" + path, Color("66718d"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreTitleLabel", Color("9aa5c2"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton/CoreReadout/ManualPowerLabel", Color("aab7d8"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton/CoreReadout/PerSecondInsideLabel", Color("72d5ed"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton/CoreReadout/WorkerLinkLabel", Color("a99ad7"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreStatusLabel", Color("7783a2"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessesTitleLabel", Color("9aa5c2"))
	_set_label_color("RootMargin/WorkspaceVBox/LogPanel/LogVBox/LogTitleLabel", Color("9aa5c2"))
	_style_core_button()


func _style_panel(panel: PanelContainer, background: Color, border: Color, radius: int, horizontal_margin: float, vertical_margin: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal_margin
	style.content_margin_right = horizontal_margin
	style.content_margin_top = vertical_margin
	style.content_margin_bottom = vertical_margin
	panel.add_theme_stylebox_override("panel", style)


func _style_core_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("171332")
	normal.border_color = Color("8168d7")
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.set_corner_radius_all(128)
	var hover := normal.duplicate()
	hover.bg_color = Color("211b45")
	hover.border_color = Color("a88cff")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("0d1025")
	pressed.border_color = Color("72d5ed")
	core_button.add_theme_stylebox_override("normal", normal)
	core_button.add_theme_stylebox_override("hover", hover)
	core_button.add_theme_stylebox_override("pressed", pressed)
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton/CoreReadout/CoreCaptionLabel", Color("a99ad7"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton/CoreReadout/BitsLabel", Color("f4f1ff"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton/CoreReadout/CorePromptLabel", Color("7ddbf0"))


func _set_label_color(path: NodePath, color: Color) -> void:
	var label := get_node(path) as Control
	label.add_theme_color_override("font_color", color)

func _toggle_upgrades() -> void:
	if upgrade_store.has_method("_refresh"): upgrade_store._refresh()

func _apply_responsive_layout() -> void:
	var viewport_size:=get_viewport_rect().size
	var width:=viewport_size.x
	var left:=150.0 if width<1500.0 else 180.0 if width<2200.0 else 205.0
	var right:=380.0 if width<1500.0 else 465.0 if width<2200.0 else 540.0
	var core_size:=250.0 if width<1500.0 else 330.0 if width<2200.0 else 400.0
	var sidebar:=get_node("RootMargin/WorkspaceVBox/WorkspaceRow/SidebarPanel") as Control
	var processes:=get_node("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel") as Control
	var log_panel:=get_node("RootMargin/WorkspaceVBox/LogPanel") as Control
	sidebar.custom_minimum_size.x=left;processes.custom_minimum_size.x=right
	core_button.custom_minimum_size=Vector2(core_size,core_size)
	log_panel.custom_minimum_size.y=96.0 if viewport_size.y<900.0 else 124.0 if viewport_size.y<1200.0 else 148.0
	upgrade_store.set_responsive_layout(int(width),int(viewport_size.y))


func _refresh() -> void:
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if game == null:
		return
	economy_refresh_count += 1
	_set_label_text(bits_label, "%s\nBITS" % NUMBER_FORMATTER.format(game.get_currency()))
	_set_label_text(per_second_label, "+%s / SEC" % NUMBER_FORMATTER.format(game.get_total_production_per_second(), 2))
	var manual_power: float = game.get_manual_generation_amount()
	_set_label_text(manual_power_label, "+%s %s / CLICK" % [NUMBER_FORMATTER.format(manual_power, 2), "BIT" if is_equal_approx(manual_power, 1.0) else "BITS"])
	var modifier_details: Array = game.get_manual_power_modifier_details()
	if modifier_details.is_empty():
		get_node("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreStatusLabel").text = "CORE READY // INPUT ACCEPTED"
		worker_link_label.visible = false
	else:
		var detail: Dictionary = modifier_details[0]
		worker_link_label.visible = true
		worker_link_label.text = "WORKER LINK  ×%s" % NUMBER_FORMATTER.format(float(detail["multiplier"]), 2)
		get_node("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreStatusLabel").text = "CORE READY // LINK ACTIVE"


func _on_generate_pressed() -> void:
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if game != null:
		game.generate_manual()
		_append_system_log("Manual computation accepted\nBit stream incremented\nAwaiting input...")
		_refresh()
		_play_core_feedback()


func _on_generator_acquired(generator_id: StringName) -> void:
	if _unlock_message_pending:
		_unlock_message_pending = false
		return
	var content_db := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"content_db")
	var definition: GeneratorDefinition = content_db.get_generator(generator_id) as GeneratorDefinition if content_db != null else null
	if definition != null:
		_append_system_log("%s ACQUIRED\nCOMPUTE OUTPUT INCREASED\nAwaiting operator input..." % definition.display_name)


func _play_core_feedback() -> void:
	if is_instance_valid(_core_feedback_tween):
		_core_feedback_tween.kill()
	core_button.modulate = Color(0.88, 0.95, 1.0, 1.0)
	_core_feedback_tween = create_tween()
	_core_feedback_tween.tween_property(core_button, "modulate", Color.WHITE, 0.16)


func _play_capacity_feedback() -> void:
	if is_instance_valid(_core_feedback_tween):
		_core_feedback_tween.kill()
	core_button.modulate = Color(0.74, 0.98, 1.0, 1.0)
	_core_feedback_tween = create_tween()
	_core_feedback_tween.tween_property(core_button, "modulate", Color.WHITE, 0.32)


func _on_currency_changed(_currency_id: StringName, _old: float, _new: float) -> void:
	_passive_display_dirty = true


func _on_generator_bought(_generator_id: StringName, _new_count: int) -> void:
	_play_capacity_feedback()
	var newly_displayed := _sync_generator_rows(true)
	if not newly_displayed.is_empty():
		var unlocked_definition: GeneratorDefinition = newly_displayed[0]
		_unlock_message_pending = true
		_append_system_log("NEW PROCESS DISCOVERED\n%s ONLINE\nAwaiting operator input..." % unlocked_definition.display_name)
		_refresh()
		_refresh_passive_children()


func _on_upgrade_bought(_upgrade_id: StringName) -> void:
	_refresh()
	_refresh_passive_children()


func _on_load_completed(_success: bool) -> void:
	_sync_generator_rows(false)
	_refresh()
	_refresh_passive_children()
	_refresh_shift_indicator()


func _on_system_log_message(message: String) -> void:
	_append_system_log(message)


func _on_anomaly_visual_requested() -> void:
	if is_instance_valid(_anomaly_tween):
		_anomaly_tween.kill()
	var base_position := core_button.position
	core_button.position = base_position + Vector2(3.0, -2.0)
	core_button.modulate = Color(0.72, 0.95, 1.0, 1.0)
	_anomaly_tween = create_tween()
	_anomaly_tween.set_parallel(true)
	_anomaly_tween.tween_property(core_button, "position", base_position, 0.22).set_trans(Tween.TRANS_SINE)
	_anomaly_tween.tween_property(core_button, "modulate", Color.WHITE, 0.32)


func _on_shift_state_changed(_active: bool) -> void:
	_refresh_shift_indicator()


func _on_story_flag_changed(_flag_id: StringName, _old_value: Variant, _new_value: Variant) -> void:
	_refresh_shift_indicator()


func _refresh_shift_indicator() -> void:
	var story := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"story_manager")
	if story == null:
		return
	var available := bool(story.get_flag(&"shift_state_unlocked", false))
	shift_indicator.visible = available
	shift_indicator.text = "[SHIFT] INSPECT" if available else ""


func _on_operator_selected() -> void:
	var story := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"story_manager")
	var shift := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"shift_manager")
	if story == null or shift == null or not shift.is_shift_active() or bool(story.get_flag(&"operator_discovered", false)):
		return
	story.set_flag(&"operator_discovered", true)
	var overlay := get_node_or_null("../MetaOverlay")
	if overlay != null and overlay.has_method("set_operator_discovered"):
		overlay.set_operator_discovered()
	_append_system_log("UNREGISTERED PROCESS SELECTED\nSCANNING...\nTYPE: INPUT SOURCE\nORIGIN: OUTSIDE SIMULATION\nASSIGNING TEMPORARY IDENTIFIER...\nOPERATOR")
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus != null:
		event_bus.operator_discovered.emit()


func _refresh_passive_children() -> void:
	for row in process_rows.get_children():
		if row.has_method("refresh_passive_display"):
			row.refresh_passive_display()
	if upgrade_store != null and upgrade_store.has_method("refresh_passive_affordability"):
		upgrade_store.refresh_passive_affordability()


func _set_label_text(label: Label, value: String) -> void:
	if label.text != value:
		label.text = value


func _append_system_log(message: String) -> void:
	_system_log_history.append(message)
	if _system_log_history.size() > SYSTEM_LOG_HISTORY_LIMIT:
		_system_log_history.pop_front()
	_set_label_text(system_log_label, "> " + message.replace("\n", "\n> "))
