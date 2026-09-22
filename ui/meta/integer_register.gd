extends Control
const REG:=preload("res://autoload/autoload_registry.gd")
var panel:PanelContainer;var label:Label;var core:Control;var shift:=false
func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel=PanelContainer.new();panel.name="IntegerRegisterPanel";panel.custom_minimum_size=Vector2(292,252);panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(panel)
	var style:=StyleBoxFlat.new();style.bg_color=Color("0b1626e8");style.border_color=Color("72dbe8");style.set_border_width_all(1);style.set_corner_radius_all(4);style.set_content_margin_all(9);panel.add_theme_stylebox_override("panel",style)
	label=Label.new();label.name="RegisterText";label.add_theme_font_size_override("font_size",12);label.add_theme_color_override("font_color",Color("bdeff4"));label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;panel.add_child(label)
	var eb:=REG.get_autoload(get_tree(),&"event_bus");if eb!=null:eb.integer_range_changed.connect(_refresh)
	get_viewport().size_changed.connect(_position);_refresh()
func configure(value:Control)->void:core=value;_position()
func set_shift_active(active:bool)->void:shift=active;_refresh()
func _refresh()->void:
	var range:=REG.get_autoload(get_tree(),&"integer_range_manager");var game:=REG.get_autoload(get_tree(),&"game");visible=shift and range!=null and range.stage_started;if not visible:return
	label.text="INTEGER REGISTER\n\nTYPE\nSIGNED INT32\n\nCURRENT\n%s\nHEADROOM\n%s\nUTILIZATION\n%.2f%%\n\nMAX  %s\nMIN  -2,147,483,648"%[_fmt(game.get_currency()),_fmt(range.get_headroom()),range.get_capacity_percent(),_fmt(range.get_int32_max())];_position()
func _fmt(v:float)->String:return "%s"%[NumberFormatter.format(v)]
func _position()->void:
	if panel==null:return
	var s:=get_viewport_rect().size;var p:=core.get_global_rect().get_center()-panel.custom_minimum_size*0.5 if core!=null else Vector2(20,70);panel.position=Vector2(clampf(p.x,8,maxf(8,s.x-panel.custom_minimum_size.x-8)),clampf(p.y,52,maxf(52,s.y-panel.custom_minimum_size.y-8)))
