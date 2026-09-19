extends Control

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")

## Stage 1 presentation for the fictional BIT//SHIFT machine interface.
## Gameplay remains in Game; this script only maps existing state and actions
## onto the computation-core and process-control controls.

var bits_label: Label
var per_second_label: Label
var core_button: Button
var system_log_label: Label

var worker_box: PanelContainer
var worker_owned_label: Label
var worker_production_label: Label
var worker_cost_label: Label
var buy_worker_button: Button

var _core_feedback_tween: Tween


func _ready() -> void:
	bits_label = get_node("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton/CoreReadout/BitsLabel")
	per_second_label = get_node("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/PerSecondLabel")
	core_button = get_node("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton")
	system_log_label = get_node("RootMargin/WorkspaceVBox/LogPanel/LogVBox/SystemLogLabel")

	worker_box = get_node("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows/WorkerCard")
	worker_owned_label = get_node("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows/WorkerCard/CardVBox/OwnedRow/WorkerOwnedLabel")
	worker_production_label = get_node("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows/WorkerCard/CardVBox/OutputRow/WorkerProductionLabel")
	worker_cost_label = get_node("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows/WorkerCard/CardVBox/CostRow/WorkerCostLabel")
	buy_worker_button = get_node("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows/WorkerCard/CardVBox/BuyWorkerButton")

	core_button.pressed.connect(_on_generate_pressed)
	buy_worker_button.pressed.connect(_on_buy_worker_pressed)

	_connect_signals()
	_apply_theme()
	_refresh()


func _connect_signals() -> void:
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus == null:
		return
	if not event_bus.is_connected("currency_changed", _on_currency_changed):
		event_bus.currency_changed.connect(_on_currency_changed)
	if not event_bus.is_connected("generator_bought", _on_generator_bought):
		event_bus.generator_bought.connect(_on_generator_bought)


func _apply_theme() -> void:
	_style_panel(get_node("RootMargin/WorkspaceVBox/HeaderPanel"), Color("11152a"), Color("363a65"), 6, 14, 7)
	_style_panel(get_node("RootMargin/WorkspaceVBox/WorkspaceRow/SidebarPanel"), Color("0d1122"), Color("2b3154"), 6, 14, 14)
	_style_panel(get_node("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel"), Color("10152a"), Color("454177"), 10, 18, 16)
	_style_panel(get_node("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel"), Color("0d1122"), Color("2b3154"), 6, 14, 14)
	_style_panel(get_node("RootMargin/WorkspaceVBox/LogPanel"), Color("0b1020"), Color("28304d"), 6, 14, 10)
	_style_panel(worker_box, Color("151a31"), Color("454177"), 7, 13, 13)

	_set_label_color("RootMargin/WorkspaceVBox/HeaderPanel/HeaderRow/BrandLabel", Color("f1efff"))
	_set_label_color("RootMargin/WorkspaceVBox/HeaderPanel/HeaderRow/SystemStatusLabel", Color("72d5ed"))
	_set_label_color("RootMargin/WorkspaceVBox/HeaderPanel/HeaderRow/BuildLabel", Color("9aa5c2"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/SidebarPanel/SidebarVBox/SidebarTitleLabel", Color("8e9bbd"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/SidebarPanel/SidebarVBox/CoreNavLabel", Color("bc9cff"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/SidebarPanel/SidebarVBox/ProcessesNavLabel", Color("66718d"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/SidebarPanel/SidebarVBox/UpgradesNavLabel", Color("66718d"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/SidebarPanel/SidebarVBox/ArchiveNavLabel", Color("66718d"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/SidebarPanel/SidebarVBox/SettingsNavLabel", Color("66718d"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreTitleLabel", Color("9aa5c2"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/PerSecondLabel", Color("72d5ed"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreStatusLabel", Color("7783a2"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessesTitleLabel", Color("9aa5c2"))
	_set_label_color("RootMargin/WorkspaceVBox/LogPanel/LogVBox/LogTitleLabel", Color("9aa5c2"))
	_set_label_color("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows/WorkerCard/CardVBox/WorkerTitleLabel", Color("eceaff"))

	_style_core_button()
	_style_buy_button()


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


func _style_buy_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("493a83")
	normal.border_color = Color("8875d6")
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.set_corner_radius_all(5)
	normal.content_margin_top = 9
	normal.content_margin_bottom = 9

	var hover := normal.duplicate()
	hover.bg_color = Color("6150a7")
	hover.border_color = Color("b6a1ff")

	var pressed := normal.duplicate()
	pressed.bg_color = Color("302760")

	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color("171b2b")
	disabled.border_color = Color("303754")
	disabled.border_width_left = 1
	disabled.border_width_top = 1
	disabled.border_width_right = 1
	disabled.border_width_bottom = 1
	disabled.set_corner_radius_all(5)
	disabled.content_margin_top = 9
	disabled.content_margin_bottom = 9

	buy_worker_button.add_theme_stylebox_override("normal", normal)
	buy_worker_button.add_theme_stylebox_override("hover", hover)
	buy_worker_button.add_theme_stylebox_override("pressed", pressed)
	buy_worker_button.add_theme_stylebox_override("disabled", disabled)
	buy_worker_button.add_theme_color_override("font_color", Color("f4f1ff"))
	buy_worker_button.add_theme_color_override("font_disabled_color", Color("66718d"))


func _set_label_color(path: NodePath, color: Color) -> void:
	var label := get_node(path) as Label
	label.add_theme_color_override("font_color", color)


func _refresh() -> void:
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if game == null:
		return

	bits_label.text = "%s BITS" % _format_bits(game.get_currency())
	per_second_label.text = "+%s BITS / SEC" % _format_bits(game.get_production_per_second())
	worker_owned_label.text = str(game.get_worker_count())
	worker_production_label.text = "1 Bit / sec"
	worker_cost_label.text = "%s Bits" % _format_bits(game.get_worker_cost())
	buy_worker_button.disabled = not game.can_afford(game.get_worker_cost())


func _on_generate_pressed() -> void:
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if game != null:
		game.generate_manual()
		system_log_label.text = "> Manual computation accepted\n> Bit stream incremented\n> Awaiting operator input..."
		_play_core_feedback()


func _on_buy_worker_pressed() -> void:
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if game != null and game.buy_worker():
		# buy_worker() emits its currency change before it increments the owned
		# count, so refresh once after the completed transaction as well.
		_refresh()
		system_log_label.text = "> Worker process acquired\n> Autonomous computation online\n> Awaiting operator input..."


func _play_core_feedback() -> void:
	if is_instance_valid(_core_feedback_tween):
		_core_feedback_tween.kill()
	core_button.modulate = Color(0.88, 0.95, 1.0, 1.0)
	_core_feedback_tween = create_tween()
	_core_feedback_tween.tween_property(core_button, "modulate", Color.WHITE, 0.16)


func _on_currency_changed(_currency_id: StringName, _old: float, _new: float) -> void:
	_refresh()


func _on_generator_bought(_generator_id: StringName, _new_count: int) -> void:
	_refresh()


func _format_bits(value: float) -> String:
	var int_val := int(floor(value))
	var source := str(int_val)
	var result := ""
	var count := 0
	for i in range(source.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = source[i] + result
		count += 1
	if value != floor(value):
		result += "." + str(int((value - floor(value)) * 1000)).pad_zeros(3).rstrip("0")
	return result
