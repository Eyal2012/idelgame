extends PanelContainer

const AUTOLOAD_REGISTRY := preload("res://autoload/autoload_registry.gd")

signal generator_acquired(generator_id: StringName)

var generator_id: StringName = &""
var _definition: GeneratorDefinition
var _feedback_tween: Tween

@onready var accent_label: Label = $Margin/VBox/TopRow/AccentLabel
@onready var title_label: Label = $Margin/VBox/TopRow/TitleLabel
@onready var owned_value_label: Label = $Margin/VBox/TopRow/OwnedValueLabel
@onready var each_value_label: Label = $Margin/VBox/StatsRow/EachValueLabel
@onready var total_value_label: Label = $Margin/VBox/StatsRow/TotalValueLabel
@onready var cost_value_label: Label = $Margin/VBox/PurchaseRow/CostValueLabel
@onready var acquire_button: Button = $Margin/VBox/PurchaseRow/AcquireButton


func _ready() -> void:
	acquire_button.pressed.connect(_on_acquire_pressed)
	_connect_signals()
	_apply_style()
	_refresh()


func configure(definition: GeneratorDefinition) -> void:
	_definition = definition
	generator_id = definition.id
	name = String(generator_id)
	if is_node_ready():
		_apply_style()
		_refresh()


func play_reveal() -> void:
	if not is_node_ready():
		return
	if is_instance_valid(_feedback_tween):
		_feedback_tween.kill()
	pivot_offset = size * 0.5
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	scale = Vector2(0.96, 0.96)
	_feedback_tween = create_tween()
	_feedback_tween.set_parallel(true)
	_feedback_tween.tween_property(self, "modulate", Color.WHITE, 0.38)
	_feedback_tween.tween_property(self, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _connect_signals() -> void:
	var event_bus := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"event_bus")
	if event_bus == null:
		return
	if not event_bus.is_connected("currency_changed", _on_currency_changed):
		event_bus.currency_changed.connect(_on_currency_changed)
	if not event_bus.is_connected("generator_bought", _on_generator_bought):
		event_bus.generator_bought.connect(_on_generator_bought)


func _refresh() -> void:
	if _definition == null:
		return
	title_label.text = _definition.display_name
	title_label.tooltip_text = _definition.description
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if game == null:
		return
	owned_value_label.text = str(game.get_generator_count(generator_id))
	each_value_label.text = "EACH +%s/s" % _format_number(_definition.base_production)
	total_value_label.text = "TOTAL +%s/s" % _format_number(game.get_generator_production(generator_id))
	cost_value_label.text = "COST %s Bits" % _format_number(game.get_generator_cost(generator_id))
	acquire_button.disabled = not game.can_buy_generator(generator_id)


func _on_acquire_pressed() -> void:
	var game := AUTOLOAD_REGISTRY.get_autoload(get_tree(), &"game")
	if game != null and game.buy_generator(generator_id):
		_refresh()
		_play_purchase_feedback()
		generator_acquired.emit(generator_id)


func _on_currency_changed(_currency_id: StringName, _old: float, _new: float) -> void:
	_refresh()


func _on_generator_bought(changed_generator_id: StringName, _new_count: int) -> void:
	if changed_generator_id == generator_id:
		_refresh()


func _play_purchase_feedback() -> void:
	if is_instance_valid(_feedback_tween):
		_feedback_tween.kill()
	modulate = Color(0.7, 0.95, 1.0, 1.0)
	owned_value_label.modulate = Color(0.75, 0.96, 1.0, 1.0)
	_feedback_tween = create_tween()
	_feedback_tween.set_parallel(true)
	_feedback_tween.tween_property(self, "modulate", Color.WHITE, 0.24)
	_feedback_tween.tween_property(owned_value_label, "modulate", Color.WHITE, 0.3)


func _apply_style() -> void:
	var accent := _definition.accent_color if _definition != null else Color("8168d7")
	var card := StyleBoxFlat.new()
	card.bg_color = Color("151a31")
	card.border_color = accent.darkened(0.2)
	card.border_width_left = 2
	card.border_width_top = 1
	card.border_width_right = 1
	card.border_width_bottom = 1
	card.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", card)
	accent_label.add_theme_color_override("font_color", accent)
	title_label.add_theme_color_override("font_color", Color("eceaff"))
	owned_value_label.add_theme_color_override("font_color", Color("f4f1ff"))
	each_value_label.add_theme_color_override("font_color", Color("9aa5c2"))
	total_value_label.add_theme_color_override("font_color", accent.lightened(0.12))
	cost_value_label.add_theme_color_override("font_color", Color("9aa5c2"))

	var normal := StyleBoxFlat.new()
	normal.bg_color = accent.darkened(0.35)
	normal.border_color = accent
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	var hover := normal.duplicate()
	hover.bg_color = accent.darkened(0.15)
	var disabled := StyleBoxFlat.new()
	disabled.bg_color = Color("171b2b")
	disabled.border_color = Color("303754")
	disabled.border_width_left = 1
	disabled.border_width_top = 1
	disabled.border_width_right = 1
	disabled.border_width_bottom = 1
	disabled.set_corner_radius_all(4)
	disabled.content_margin_left = 8
	disabled.content_margin_right = 8
	disabled.content_margin_top = 4
	disabled.content_margin_bottom = 4
	acquire_button.add_theme_stylebox_override("normal", normal)
	acquire_button.add_theme_stylebox_override("hover", hover)
	acquire_button.add_theme_stylebox_override("disabled", disabled)
	acquire_button.add_theme_color_override("font_disabled_color", Color("66718d"))


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
