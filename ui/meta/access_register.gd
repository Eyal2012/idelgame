extends Control

## SHIFT-only Stage 6 diagnostic. The register is presentation-only; the
## AccessMaskManager remains the authority for all permission state.
const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")

var _core_panel: Control
var _panel: PanelContainer
var _bits: Label
var _mask: Label
var _left: Button
var _right: Button
var _shift_active := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	var events := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if events != null:
		events.access_mask_changed.connect(func(_mask_value: int) -> void: _refresh())
		events.story_flag_changed.connect(func(_id: StringName, _old: Variant, _new: Variant) -> void: _refresh())
	get_viewport().size_changed.connect(_position)
	_refresh()


func configure(core_panel: Control) -> void:
	_core_panel = core_panel
	_position()


func set_shift_active(active: bool) -> void:
	_shift_active = active
	if active:
		var access := _access()
		if access != null and access.event_started:
			access.discover_register()
	_refresh()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "AccessRegisterPanel"
	_panel.custom_minimum_size = Vector2(252, 144)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b1828e8")
	style.border_color = Color("4fc8da")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "OPERATOR ACCESS REGISTER"
	title.add_theme_color_override("font_color", Color("81e7ef"))
	title.add_theme_font_size_override("font_size", 11)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	var labels := Label.new()
	labels.text = "SYSTEM   EXECUTE   WRITE   READ"
	labels.add_theme_font_size_override("font_size", 10)
	labels.add_theme_color_override("font_color", Color("9ab6c8"))
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(labels)
	_bits = Label.new()
	_bits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bits.add_theme_font_size_override("font_size", 18)
	_bits.add_theme_color_override("font_color", Color("e1fbff"))
	_bits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_bits)
	_mask = Label.new()
	_mask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mask.add_theme_font_size_override("font_size", 13)
	_mask.add_theme_color_override("font_color", Color("68d9e9"))
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_mask)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(controls)
	_left = Button.new()
	_left.name = "ShiftLeftButton"
	_left.text = "<<"
	_left.tooltip_text = "0001  →  0010"
	_left.mouse_filter = Control.MOUSE_FILTER_STOP
	_left.pressed.connect(func() -> void:
		var access := _access()
		if access != null: access.shift_operator_mask_left())
	controls.add_child(_left)
	_right = Button.new()
	_right.name = "ShiftRightButton"
	_right.text = ">>"
	_right.tooltip_text = "0010  →  0001"
	_right.mouse_filter = Control.MOUSE_FILTER_STOP
	_right.pressed.connect(func() -> void:
		var access := _access()
		if access != null: access.shift_operator_mask_right())
	controls.add_child(_right)


func _refresh() -> void:
	var access := _access()
	var visible_now: bool = _shift_active and access != null and access.event_started
	visible = visible_now
	if not visible_now:
		return
	var read := "1" if access.has_operator_permission(access.READ) else "0"
	var write := "1" if access.has_operator_permission(access.WRITE) else "0"
	_bits.text = "  0         0         %s         %s" % [write, read]
	_mask.text = "MASK  %s" % access.get_mask_text()
	_left.visible = access.get_operator_access_mask() == access.READ
	_right.visible = access.puzzle_completed and access.get_operator_access_mask() == access.WRITE
	_position()


func _position() -> void:
	if _panel == null:
		return
	var layout := get_layout_for_viewport(get_viewport_rect().size)
	_panel.position = layout.position


func get_layout_for_viewport(bounds: Vector2) -> Rect2:
	var panel_size := _panel.custom_minimum_size if _panel != null else Vector2(252, 144)
	var desired := Vector2(bounds.x * 0.5 - panel_size.x * 0.5, 72.0)
	if _core_panel != null:
		desired = _core_panel.get_global_rect().get_center() - panel_size * 0.5
	return Rect2(Vector2(clampf(desired.x, 8.0, maxf(8.0, bounds.x - panel_size.x - 8.0)), clampf(desired.y, 52.0, maxf(52.0, bounds.y - panel_size.y - 8.0))), panel_size)


func _access() -> Node:
	return AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"access_mask_manager")
