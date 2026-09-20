extends Control

## Presentation/input shell for MemoryPuzzle. It never owns puzzle progress:
## click placement and drag/drop both delegate to MemoryPuzzle.place_bit().
const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")

var bits: Dictionary = {}
var slots: Dictionary = {}
var _safe_positions: Dictionary = {}
var _drag_bit: int = -1
var _drag_offset := Vector2.ZERO
var _drag_origin := Vector2.ZERO
var _drag_moved: bool = false
var _return_tween: Tween
var _pulse_tween: Tween
var _completion_pulse: float = 0.0

var _bit_normal: StyleBoxFlat
var _bit_selected: StyleBoxFlat
var _bit_dragging: StyleBoxFlat
var _bit_hover: StyleBoxFlat
var _socket_empty: StyleBoxFlat
var _socket_valid: StyleBoxFlat
var _socket_occupied: StyleBoxFlat
var _socket_hidden: StyleBoxFlat


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	_build_styles()
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus != null and not event_bus.is_connected("memory_puzzle_event", _on_puzzle_event):
		event_bus.memory_puzzle_event.connect(_on_puzzle_event)
	for bit_index in range(5):
		var bit := Button.new()
		bit.name = "bit_%d" % bit_index
		bit.text = "BIT\n%02X\nD%02d" % [bit_index, bit_index + 1]
		bit.tooltip_text = "Detached data cell %02X" % bit_index
		bit.mouse_filter = Control.MOUSE_FILTER_STOP
		bit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		bit.add_theme_font_size_override("font_size", 9)
		bit.gui_input.connect(_on_bit_gui_input.bind(bit_index))
		add_child(bit)
		bits[bit_index] = bit
	for slot_index in range(5):
		var socket := Button.new()
		socket.name = "Slot%d" % slot_index
		socket.mouse_filter = Control.MOUSE_FILTER_STOP
		socket.add_theme_font_size_override("font_size", 9)
		socket.pressed.connect(_on_socket_pressed.bind(slot_index))
		add_child(socket)
		slots[slot_index] = socket
	var guidance := Label.new()
	guidance.name = "Guidance"
	guidance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guidance.add_theme_font_size_override("font_size", 11)
	guidance.add_theme_color_override("font_color", Color("b8edf4"))
	guidance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(guidance)
	_refresh()


func _process(delta: float) -> void:
	_completion_pulse = maxf(0.0, _completion_pulse - delta)
	_refresh()


func _refresh() -> void:
	var puzzle := _puzzle()
	if puzzle == null:
		return
	var size_scale := _visual_scale()
	var guidance := get_node("Guidance") as Label
	guidance.position = Vector2(size.x * 0.5 - 150.0, 82.0)
	guidance.size = Vector2(300.0, 40.0)
	guidance.visible = puzzle.active and puzzle.are_bits_revealed()
	if guidance.visible:
		guidance.text = "HOLD [SHIFT] TO INSPECT INTERNAL ROUTES" if puzzle.selected_bit >= 0 or puzzle.get_restored_count() > 0 else "5 DATA CELLS DETACHED\nCLICK OR DRAG A DATA CELL"
	for bit_index in range(5):
		var bit := bits[bit_index] as Button
		var bit_size := Vector2(50.0, 50.0) * size_scale
		bit.custom_minimum_size = bit_size
		bit.size = bit_size
		_safe_positions[bit_index] = _spawn_position(bit_index, bit_size)
		if bit_index != _drag_bit:
			bit.position = _safe_positions[bit_index]
		else:
			bit.position = _clamp_position(bit.position, bit_size)
		bit.visible = puzzle.are_bits_revealed() and not puzzle.restored[bit_index]
		var selected: bool = puzzle.selected_bit == bit_index
		bit.modulate = Color(1.0, 1.0, 1.0, 1.0) if bit_index != _drag_bit else Color(1.0, 1.0, 1.0, 1.0)
		bit.scale = Vector2.ONE * (1.10 if bit_index == _drag_bit else 1.0)
		bit.add_theme_stylebox_override("normal", _bit_dragging if bit_index == _drag_bit else _bit_selected if selected else _bit_normal)
		bit.add_theme_stylebox_override("hover", _bit_dragging if bit_index == _drag_bit else _bit_selected if selected else _bit_hover)
	var shift_active := _shift_active()
	for slot_index in range(5):
		var socket := slots[slot_index] as Button
		socket.custom_minimum_size = Vector2(84.0, 44.0) * size_scale
		socket.size = socket.custom_minimum_size
		if slot_index < 4:
			socket.position = _primary_socket_position(slot_index, socket.size)
		else:
			socket.position = _fifth_socket_position(socket.size)
		var fifth_revealed: bool = slot_index < 4 or puzzle.is_fifth_address_active()
		socket.visible = puzzle.active and shift_active and fifth_revealed
		var occupied: bool = puzzle.slots[slot_index] >= 0
		var valid: bool = _drag_bit >= 0 and puzzle.can_place_bit(_drag_bit, slot_index)
		var hovered: bool = valid and socket.get_global_rect().has_point(get_global_mouse_position())
		if occupied:
			socket.text = "SLOT %02d\nLOCKED ✓" % slot_index
			socket.add_theme_stylebox_override("normal", _socket_occupied)
		elif slot_index == 4:
			socket.text = "ADDRESS 04\nRESERVED"
			socket.add_theme_stylebox_override("normal", _socket_valid if valid or hovered else _socket_hidden)
		elif valid or hovered:
			socket.text = "SLOT %02d\nTARGET ◇" % slot_index
			socket.add_theme_stylebox_override("normal", _socket_valid)
		else:
			socket.text = "SLOT %02d\nEMPTY" % slot_index
			socket.add_theme_stylebox_override("normal", _socket_empty)
	queue_redraw()


func _gui_input(_event: InputEvent) -> void:
	# Root stays input-transparent so normal gameplay is never modal.
	pass


## Once a Bit has been picked up, keep receiving pointer movement even after it
## leaves the Button's original rectangle. This is intentionally not a modal
## blocker: it only handles input while a puzzle Bit is actively being dragged.
func _input(event: InputEvent) -> void:
	if _drag_bit < 0:
		return
	var bit := bits.get(_drag_bit) as Button
	if bit == null:
		_drag_bit = -1
		return
	if event is InputEventMouseMotion:
		if event.relative.length_squared() > 0.0:
			_drag_moved = true
			bit.position = _clamp_position(get_local_mouse_position() - _drag_offset, bit.size)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag(_drag_bit)
		get_viewport().set_input_as_handled()


func _on_bit_gui_input(event: InputEvent, bit_index: int) -> void:
	var puzzle := _puzzle()
	if puzzle == null or not puzzle.active or puzzle.restored[bit_index]:
		return
	var bit := bits[bit_index] as Button
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_bit = bit_index
			_drag_origin = bit.position
			_drag_offset = bit.get_local_mouse_position()
			_drag_moved = false
			puzzle.select_bit(bit_index)
			bit.accept_event()
		else:
			if _drag_bit == bit_index:
				_finish_drag(bit_index)
			bit.accept_event()


func _finish_drag(bit_index: int) -> void:
	var puzzle := _puzzle()
	var bit := bits[bit_index] as Button
	var placed := false
	if puzzle != null and _drag_moved:
		placed = _try_drop(bit_index, get_global_mouse_position())
	if not placed:
		_return_bit(bit, _drag_origin)
	_drag_bit = -1
	_drag_moved = false


func _return_bit(bit: Button, target: Vector2) -> void:
	if is_instance_valid(_return_tween):
		_return_tween.kill()
	_return_tween = create_tween()
	_return_tween.tween_property(bit, "position", _clamp_position(target, bit.size), 0.16).set_trans(Tween.TRANS_SINE)


func _on_socket_pressed(slot_index: int) -> void:
	var puzzle := _puzzle()
	if puzzle != null:
		puzzle.place_selected(slot_index)


## Validator hooks reuse the same socket hit-test and authoritative placement.
func simulate_drag_drop_for_test(bit_index: int, slot_index: int) -> bool:
	var socket := slots.get(slot_index) as Button
	if socket == null:
		return false
	return _try_drop(bit_index, socket.get_global_rect().get_center())


func simulate_invalid_drag_for_test(bit_index: int) -> bool:
	return _try_drop(bit_index, Vector2(-100.0, -100.0))


func _try_drop(bit_index: int, pointer: Vector2) -> bool:
	var puzzle := _puzzle()
	if puzzle == null:
		return false
	for slot_index in range(5):
		var socket := slots[slot_index] as Button
		if socket.visible and socket.get_global_rect().has_point(pointer):
			return puzzle.place_bit(bit_index, slot_index)
	return false


func _on_puzzle_event(event_id: StringName, _bit_index: int, _slot_index: int) -> void:
	if event_id == &"memory_failure_completed":
		_completion_pulse = 0.45


func _spawn_position(bit_index: int, bit_size: Vector2) -> Vector2:
	# Keep the detached cells on the Core perimeter. This deliberately reserves
	# sidebar navigation, Process BUY/INSTALL controls, and System Log text.
	var core := get_parent().get_node_or_null("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel") as Control if get_parent() != null else null
	if core != null:
		var core_rect := core.get_global_rect()
		var overlay_origin := get_global_rect().position
		var local_rect := Rect2(core_rect.position - overlay_origin, core_rect.size)
		var inset := 7.0 * _visual_scale()
		var top_left := local_rect.position + Vector2(inset, 30.0 * _visual_scale())
		var top_right := Vector2(local_rect.end.x - bit_size.x - inset, top_left.y)
		var bottom_left := Vector2(top_left.x, local_rect.end.y - bit_size.y - 32.0 * _visual_scale())
		var bottom_right := Vector2(top_right.x, bottom_left.y)
		var bottom_center := Vector2((local_rect.position.x + local_rect.end.x - bit_size.x) * 0.5, bottom_left.y)
		return _clamp_position([top_left, top_right, bottom_left, bottom_right, bottom_center][bit_index], bit_size)
	var anchors := [Vector2(0.20, 0.16), Vector2(0.52, 0.14), Vector2(0.22, 0.66), Vector2(0.72, 0.48), Vector2(0.45, 0.68)]
	return _clamp_position(Vector2(size.x * anchors[bit_index].x, size.y * anchors[bit_index].y), bit_size)


func _primary_socket_position(slot_index: int, socket_size: Vector2) -> Vector2:
	var core := get_parent().get_node_or_null("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel") as Control if get_parent() != null else null
	if core != null:
		var core_rect := core.get_global_rect()
		var local_rect := Rect2(core_rect.position - get_global_rect().position, core_rect.size)
		var center := local_rect.get_center()
		var positions := [
			Vector2(center.x - socket_size.x * 0.5, local_rect.position.y + 72.0),
			Vector2(local_rect.position.x + 18.0, center.y - socket_size.y * 0.5),
			Vector2(local_rect.end.x - socket_size.x - 18.0, center.y - socket_size.y * 0.5),
			Vector2(center.x - socket_size.x * 0.5, local_rect.end.y - socket_size.y - 92.0),
		]
		return _clamp_position(positions[slot_index], socket_size)
	var gap := 12.0 * _visual_scale()
	return _clamp_position(Vector2((size.x - socket_size.x * 4.0 - gap * 3.0) * 0.5 + slot_index * (socket_size.x + gap), size.y * 0.28), socket_size)


func _fifth_socket_position(socket_size: Vector2) -> Vector2:
	# The System Log remains in place; the hidden address is discovered above it.
	return _clamp_position(Vector2(size.x * 0.62, size.y - socket_size.y - 18.0 * _visual_scale()), socket_size)


func _clamp_position(position: Vector2, control_size: Vector2) -> Vector2:
	return Vector2(clampf(position.x, 8.0, maxf(8.0, size.x - control_size.x - 8.0)), clampf(position.y, 72.0, maxf(72.0, size.y - control_size.y - 8.0)))


func _visual_scale() -> float:
	return clampf(minf(size.x / 1280.0, size.y / 720.0), 0.88, 1.60)


func _shift_active() -> bool:
	var shift := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"shift_manager")
	return shift != null and shift.is_shift_active()


func _draw() -> void:
	var puzzle := _puzzle()
	if puzzle == null or (not puzzle.active and _completion_pulse <= 0.0) or not _shift_active():
		return
	var cyan := Color(0.30, 0.88, 0.96, 0.44)
	var violet := Color(0.67, 0.46, 0.96, 0.36)
	var origin := Vector2(size.x * 0.50, size.y * 0.30)
	var core := get_parent().get_node_or_null("RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel") as Control if get_parent() != null else null
	if core != null:
		origin = core.get_global_rect().get_center() - get_global_rect().position
	draw_circle(origin, 5.0 * _visual_scale(), cyan)
	for slot_index in range(4):
		var socket := slots.get(slot_index) as Control
		if socket != null:
			var endpoint := socket.position + socket.size * 0.5
			draw_line(origin, endpoint, cyan, 1.2)
	if puzzle.is_fifth_address_active():
		var fifth := slots.get(4) as Control
		if fifth != null:
			var target := fifth.position + Vector2(fifth.size.x * 0.5, 0.0)
			draw_dashed_line(origin, target, violet, 1.4, 7.0)
	if _completion_pulse > 0.0:
		draw_circle(origin, (18.0 + 28.0 * _completion_pulse) * _visual_scale(), Color(0.56, 0.96, 0.86, _completion_pulse))


func _build_styles() -> void:
	_bit_normal = _style(Color("122338"), Color("58bfd1"), 1, 3)
	_bit_hover = _style(Color("1d3853"), Color("9aeaf4"), 2, 3)
	_bit_selected = _style(Color("1a2947"), Color("b78cff"), 2, 3)
	_bit_dragging = _style(Color("203756"), Color("e1b9ff"), 2, 3)
	_socket_empty = _style(Color("0c1424", 0.88), Color("4b7895"), 1, 2)
	_socket_valid = _style(Color("17294a", 0.95), Color("79e9f5"), 2, 2)
	_socket_occupied = _style(Color("1c3a43", 0.96), Color("82f0ca"), 2, 2)
	_socket_hidden = _style(Color("181427", 0.74), Color("7656a9", 0.72), 1, 2)


func _style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = width
	style.border_width_top = width
	style.border_width_right = width
	style.border_width_bottom = width
	style.set_corner_radius_all(radius)
	style.content_margin_left = 3.0
	style.content_margin_right = 3.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style


func _puzzle() -> Node:
	return AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"memory_puzzle")
