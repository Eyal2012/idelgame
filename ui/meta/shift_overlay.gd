extends Control

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")

signal operator_selected()

var _core_panel: Control
var _operator_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_operator_button = Button.new()
	_operator_button.name = "HiddenOperator"
	_operator_button.text = "UNREGISTERED PROCESS\nPID: ???\nOWNER: UNKNOWN"
	_operator_button.tooltip_text = "Hold SHIFT to inspect."
	_operator_button.custom_minimum_size = Vector2(190, 68)
	_operator_button.visible = false
	_operator_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_operator_button.add_theme_font_size_override("font_size", 11)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17132a", 0.94)
	style.border_color = Color("4aaec1", 0.9)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(3)
	_operator_button.add_theme_stylebox_override("normal", style)
	_operator_button.add_theme_color_override("font_color", Color("8fe4ed"))
	_operator_button.pressed.connect(_on_operator_pressed)
	add_child(_operator_button)


func configure(core_panel: Control) -> void:
	_core_panel = core_panel


func set_shift_active(active: bool) -> void:
	visible = active
	if _operator_button == null:
		return
	_operator_button.visible = active and not _is_operator_discovered()
	if active:
		_position_operator()


func _position_operator() -> void:
	if _core_panel == null:
		return
	var rect := _core_panel.get_global_rect()
	_operator_button.global_position = rect.position + Vector2(14.0, maxf(48.0, rect.size.y - 98.0))


func _on_operator_pressed() -> void:
	if visible and _operator_button.visible:
		operator_selected.emit()


func set_operator_discovered() -> void:
	if _operator_button != null:
		_operator_button.visible = false


func _is_operator_discovered() -> bool:
	var story := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"story_manager")
	return story != null and bool(story.get_flag(&"operator_discovered", false))
