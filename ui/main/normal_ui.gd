extends Control

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")
const GENERATOR_ROW_SCENE := preload("res://ui/components/GeneratorRow.tscn")

var bits_label: Label
var per_second_label: Label
var core_button: Button
var system_log_label: Label
var process_rows: VBoxContainer
var _core_feedback_tween: Tween
var _displayed_generator_ids: Dictionary = {}
var _unlock_message_pending: bool = false


func _ready() -> void:
	bits_label = get_node("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton/CoreReadout/BitsLabel")
	per_second_label = get_node("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/PerSecondLabel")
	core_button = get_node("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton")
	system_log_label = get_node("RootMargin/WorkspaceVBox/LogPanel/LogVBox/SystemLogLabel")
	process_rows = get_node("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows")
	core_button.pressed.connect(_on_generate_pressed)
	_connect_signals()
	_apply_theme()
	_sync_generator_rows(false)
	_refresh()


func _connect_signals() -> void:
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus == null:
		return
	if not event_bus.is_connected("currency_changed", _on_currency_changed):
		event_bus.currency_changed.connect(_on_currency_changed)
	if not event_bus.is_connected("generator_bought", _on_generator_bought):
		event_bus.generator_bought.connect(_on_generator_bought)


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
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/PerSecondLabel", Color("72d5ed"))
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
	var label := get_node(path) as Label
	label.add_theme_color_override("font_color", color)


func _refresh() -> void:
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if game == null:
		return
	bits_label.text = "%s BITS" % _format_number(game.get_currency())
	per_second_label.text = "+%s BITS / SEC" % _format_number(game.get_total_production_per_second())


func _on_generate_pressed() -> void:
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if game != null:
		game.generate_manual()
		system_log_label.text = "> Manual computation accepted\n> Bit stream incremented\n> Awaiting operator input..."
		_play_core_feedback()


func _on_generator_acquired(generator_id: StringName) -> void:
	if _unlock_message_pending:
		_unlock_message_pending = false
		return
	var content_db := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"content_db")
	var definition: GeneratorDefinition = content_db.get_generator(generator_id) as GeneratorDefinition if content_db != null else null
	if definition != null:
		system_log_label.text = "> %s ACQUIRED\n> COMPUTE OUTPUT INCREASED\n> Awaiting operator input..." % definition.display_name


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
	_refresh()


func _on_generator_bought(_generator_id: StringName, _new_count: int) -> void:
	_play_capacity_feedback()
	var newly_displayed := _sync_generator_rows(true)
	if not newly_displayed.is_empty():
		var unlocked_definition: GeneratorDefinition = newly_displayed[0]
		_unlock_message_pending = true
		system_log_label.text = "> NEW PROCESS DISCOVERED\n> %s ONLINE\n> Awaiting operator input..." % unlocked_definition.display_name
	_refresh()


func _format_number(value: float) -> String:
	var source := str(int(round(value)))
	var result := ""
	var count := 0
	for index in range(source.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = source[index] + result
		count += 1
	return result
