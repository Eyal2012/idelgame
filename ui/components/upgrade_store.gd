extends PanelContainer

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")
const NUMBER_FORMATTER := preload("res://core/number_formatter.gd")

var _grid: GridContainer
var _installed_grid: HBoxContainer
var _detail: Label
var _install: Button
var _inspector: PanelContainer
var _selected: StringName = &""
var _module_size: int = 48
var _module_style_cache: Dictionary = {}
var structural_refresh_count: int = 0
var affordability_refresh_count: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(0, 104)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("10172b")
	style.border_color = Color("2b405e")
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(5)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	var title := Label.new()
	title.text = "UPGRADES  •  MODULE BAY"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color("87ddec"))
	box.add_child(title)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 5)
	_grid.add_theme_constant_override("v_separation", 5)
	box.add_child(_grid)
	_inspector = PanelContainer.new()
	_inspector.name = "Inspector"
	_inspector.custom_minimum_size = Vector2(0, 82)
	box.add_child(_inspector)
	var inspector_style := StyleBoxFlat.new()
	inspector_style.bg_color = Color("131e35")
	inspector_style.border_color = Color("365777")
	inspector_style.border_width_left = 1
	inspector_style.border_width_top = 1
	inspector_style.border_width_right = 1
	inspector_style.border_width_bottom = 1
	inspector_style.set_corner_radius_all(3)
	inspector_style.content_margin_left = 7
	inspector_style.content_margin_right = 7
	inspector_style.content_margin_top = 5
	inspector_style.content_margin_bottom = 5
	_inspector.add_theme_stylebox_override("panel", inspector_style)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 3)
	_inspector.add_child(detail_box)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_font_size_override("font_size", 10)
	_detail.add_theme_color_override("font_color", Color("d7def0"))
	detail_box.add_child(_detail)
	_install = Button.new()
	_install.text = "INSTALL"
	_install.custom_minimum_size = Vector2(0, 23)
	_install.add_theme_font_size_override("font_size", 10)
	_install.pressed.connect(_install_selected)
	detail_box.add_child(_install)
	var installed_title := Label.new()
	installed_title.text = "INSTALLED MODULES"
	installed_title.add_theme_font_size_override("font_size", 10)
	installed_title.add_theme_color_override("font_color", Color("7d8ba3"))
	box.add_child(installed_title)
	_installed_grid = HBoxContainer.new()
	_installed_grid.add_theme_constant_override("separation", 4)
	box.add_child(_installed_grid)
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus != null:
		event_bus.upgrade_bought.connect(func(_id: StringName) -> void: _refresh())
		# Passive production emits currency_changed continuously. Recreating Buttons
		# here can replace a tile between pointer press and release, so only update
		# affordability/selection styling on a currency change.
		event_bus.currency_changed.connect(func(_a: StringName, _b: float, _c: float) -> void: _refresh_affordability())
		event_bus.generator_bought.connect(func(_id: StringName, _count: int) -> void: _refresh())
	_refresh()


func _make_module(definition: UpgradeDefinition, installed: bool) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = Vector2(30, 26) if installed else Vector2(_module_size, _module_size)
	tile.tooltip_text = "%s\n%s" % [definition.display_name, definition.description]
	tile.text = _tile_label(definition, installed)
	tile.add_theme_font_size_override("font_size", 8 if installed else 9)
	tile.alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.set_meta(&"upgrade_id", definition.id)
	tile.set_meta(&"installed", installed)
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	var affordable: bool = game != null and game.can_buy_upgrade(definition.id)
	_apply_module_style(tile, affordable, installed, definition.id == _selected)
	tile.pressed.connect(_on_module_pressed.bind(definition.id))
	return tile


func _apply_module_style(tile: Button, affordable: bool, installed: bool, selected: bool) -> void:
	var key := "%s:%s:%s" % [affordable, installed, selected]
	var styles: Dictionary = _module_style_cache.get(key, {})
	if styles.is_empty():
		styles = _make_module_styles(affordable, installed, selected)
		_module_style_cache[key] = styles
	tile.add_theme_stylebox_override("normal", styles["normal"])
	tile.add_theme_stylebox_override("hover", styles["hover"])
	tile.modulate = Color(0.62, 0.69, 0.80, 1.0) if installed else Color.WHITE


func _make_module_styles(affordable: bool, installed: bool, selected: bool) -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("29204a") if selected else Color("152039") if not installed else Color("111827")
	normal.border_color = Color("c7a1ff") if selected else Color("5dcbda") if affordable else Color("34445d")
	var border_width := 2 if selected else 1
	normal.border_width_left = border_width
	normal.border_width_top = border_width
	normal.border_width_right = border_width
	normal.border_width_bottom = border_width
	normal.set_corner_radius_all(3)
	var hover := normal.duplicate()
	hover.bg_color = Color("26395a")
	hover.border_color = Color("e0c5ff") if selected else Color("b28cff")
	return {"normal": normal, "hover": hover}


func _on_module_pressed(upgrade_id: StringName) -> void:
	_select(upgrade_id)


func _refresh() -> void:
	if _grid == null:
		return
	structural_refresh_count += 1
	for child in _grid.get_children():
		child.queue_free()
	for child in _installed_grid.get_children():
		child.queue_free()
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	var content_db := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"content_db")
	if game == null or content_db == null:
		return
	var installed_count := 0
	for definition in content_db.get_upgrades():
		if game.is_upgrade_owned(definition.id):
			_installed_grid.add_child(_make_module(definition, true))
			installed_count += 1
		elif game.is_upgrade_unlocked(definition.id):
			_grid.add_child(_make_module(definition, false))
	var count := Label.new()
	count.text = "%d / %d" % [installed_count, content_db.get_upgrades().size()]
	count.add_theme_font_size_override("font_size", 10)
	count.add_theme_color_override("font_color", Color("7d8ba3"))
	_installed_grid.add_child(count)
	if _selected.is_empty():
		_detail.text = "Select an available module to inspect it."
		_install.disabled = true
		_inspector.visible = false
		custom_minimum_size.y = 104
	else:
		_select(_selected)


func _select(upgrade_id: StringName) -> void:
	_selected = upgrade_id
	var content_db := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"content_db")
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	var definition: UpgradeDefinition = content_db.get_upgrade(upgrade_id) as UpgradeDefinition if content_db != null else null
	if definition == null or game == null:
		return
	_inspector.visible = true
	custom_minimum_size.y = 234
	_refresh_affordability()
	var owned: bool = game.is_upgrade_owned(upgrade_id)
	_detail.text = "%s\n%s\n\nCURRENT\n%s\n\nCOST\n%s BITS" % [definition.display_name, definition.description, _current_effect_text(definition, game), NUMBER_FORMATTER.format(definition.cost)]
	_install.visible = not owned
	_install.disabled = owned or not game.can_buy_upgrade(upgrade_id)
	var denial: String = game.get_upgrade_install_denial_reason(upgrade_id)
	if not denial.is_empty() and not owned:
		_detail.text += "\n\n%s" % denial


func _refresh_affordability() -> void:
	if _grid == null:
		return
	affordability_refresh_count += 1
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if game == null:
		return
	for child in _grid.get_children():
		var tile := child as Button
		if tile == null:
			continue
		var upgrade_id := StringName(tile.get_meta(&"upgrade_id", &""))
		if upgrade_id.is_empty():
			continue
		_apply_module_style(tile, game.can_buy_upgrade(upgrade_id), false, upgrade_id == _selected)
	for child in _installed_grid.get_children():
		var tile := child as Button
		if tile == null:
			continue
		var upgrade_id := StringName(tile.get_meta(&"upgrade_id", &""))
		if upgrade_id.is_empty():
			continue
		_apply_module_style(tile, false, true, upgrade_id == _selected)
	if not _selected.is_empty():
		_install.disabled = game.is_upgrade_owned(_selected) or not game.can_buy_upgrade(_selected)


func refresh_passive_affordability() -> void:
	_refresh_affordability()


func _current_effect_text(definition: UpgradeDefinition, game: Node) -> String:
	if definition.effect_type == &"generator_manual_exponential":
		var count: int = game.get_generator_count(definition.target_id)
		return "×%s MANUAL POWER" % NUMBER_FORMATTER.format(pow(definition.effect_value, count), 2)
	if definition.effect_type == &"generator_multiplier":
		return "×%s %s OUTPUT" % [NUMBER_FORMATTER.format(definition.effect_value, 2), String(definition.target_id).to_upper()]
	if definition.effect_type == &"global_production_multiplier":
		return "×%s ALL PROCESS OUTPUT" % NUMBER_FORMATTER.format(definition.effect_value, 2)
	return "×%s" % NUMBER_FORMATTER.format(definition.effect_value, 2)


func _install_selected() -> void:
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if game != null and game.buy_upgrade(_selected):
		_selected = &""
		_refresh()


func set_responsive_layout(width: int, _height: int) -> void:
	_module_size = 39 if width < 1500 else 52 if width < 2200 else 60
	_grid.columns = 8 if width < 1500 else 6 if width < 2200 else 8
	_grid.add_theme_constant_override("h_separation", 4 if width < 1500 else 5)
	_refresh()


func _tile_label(definition: UpgradeDefinition, installed: bool) -> String:
	var words := definition.display_name.split(" ", false)
	if installed:
		return _compact_word(words[0], 4)
	if words.size() < 2:
		return _compact_word(definition.display_name, 4)
	return "%s\n%s" % [_compact_word(words[0], 4), _compact_word(words[words.size() - 1], 4)]


func _compact_word(value: String, maximum_length: int) -> String:
	return value.to_upper().substr(0, maximum_length)
