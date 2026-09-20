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
func _ready() -> void:
	custom_minimum_size=Vector2(0,138)
	var style:=StyleBoxFlat.new();style.bg_color=Color("10172b");style.border_color=Color("3a5473");style.border_width_left=1;style.border_width_top=1;style.border_width_right=1;style.border_width_bottom=1;style.set_corner_radius_all(5);style.content_margin_left=9;style.content_margin_right=9;style.content_margin_top=7;style.content_margin_bottom=7;add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",5);add_child(box)
	var title:=Label.new();title.text="UPGRADES  //  MODULE BAY";title.add_theme_font_size_override("font_size",11);title.add_theme_color_override("font_color",Color("87ddec"));box.add_child(title)
	_grid=GridContainer.new();_grid.columns=4;_grid.add_theme_constant_override("h_separation",5);_grid.add_theme_constant_override("v_separation",5);box.add_child(_grid)
	var detail_panel:=PanelContainer.new();_inspector=detail_panel;detail_panel.name="Inspector";detail_panel.custom_minimum_size=Vector2(0,62);box.add_child(detail_panel)
	var detail_box:=VBoxContainer.new();detail_panel.add_child(detail_box)
	_detail=Label.new();_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_detail.add_theme_font_size_override("font_size",10);detail_box.add_child(_detail)
	_install=Button.new();_install.text="INSTALL MODULE";_install.custom_minimum_size=Vector2(0,20);_install.add_theme_font_size_override("font_size",10);_install.pressed.connect(_install_selected);detail_box.add_child(_install)
	var installed_title:=Label.new();installed_title.text="INSTALLED";installed_title.add_theme_font_size_override("font_size",10);installed_title.add_theme_color_override("font_color",Color("8a98ad"));box.add_child(installed_title)
	_installed_grid=HBoxContainer.new();_installed_grid.add_theme_constant_override("separation",4);box.add_child(_installed_grid)
	var eb:=AUTOLOAD_REGISTRY.get_autoload(get_tree(),&"event_bus");if eb!=null:eb.upgrade_bought.connect(func(_id):_refresh());eb.currency_changed.connect(func(_a,_b,_c):_refresh())
	_refresh()
func _make_module(d:UpgradeDefinition,installed:bool)->Button:
	var tile:=Button.new();tile.custom_minimum_size=Vector2(26,26) if installed else Vector2(_module_size,_module_size);tile.tooltip_text=d.display_name+"\n"+d.description;tile.text=_symbol(d.id);tile.add_theme_font_size_override("font_size",13 if installed else int(_module_size*0.42))
	var normal:=StyleBoxFlat.new();normal.bg_color=Color("18213b") if not installed else Color("111827");normal.border_color=Color("69c9db") if not installed else Color("47536a");normal.border_width_left=1;normal.border_width_top=1;normal.border_width_right=1;normal.border_width_bottom=1;normal.set_corner_radius_all(3)
	var hover:=normal.duplicate();hover.bg_color=Color("29395c");hover.border_color=Color("b28cff");tile.add_theme_stylebox_override("normal",normal);tile.add_theme_stylebox_override("hover",hover);tile.modulate=Color(0.65,0.7,0.8,1) if installed else Color.WHITE;tile.pressed.connect(func():_select(d.id));return tile
func _refresh()->void:
	if _grid==null:return
	for child in _grid.get_children():child.queue_free()
	for child in _installed_grid.get_children():child.queue_free()
	var game:=AUTOLOAD_REGISTRY.get_autoload(get_tree(),&"game");var db:=AUTOLOAD_REGISTRY.get_autoload(get_tree(),&"content_db");if game==null or db==null:return
	var installed_count:=0
	for d in db.get_upgrades():
		if game.is_upgrade_owned(d.id):_installed_grid.add_child(_make_module(d,true));installed_count+=1
		elif game.is_upgrade_unlocked(d.id):_grid.add_child(_make_module(d,false))
	var count:=Label.new();count.text="%d/%d"%[installed_count,db.get_upgrades().size()];_installed_grid.add_child(count)
	if _selected.is_empty():_detail.text="";_install.disabled=true;_inspector.visible=false;custom_minimum_size.y=138
	else:_select(_selected)
func _select(id:StringName)->void:
	_selected=id
	var db:=AUTOLOAD_REGISTRY.get_autoload(get_tree(),&"content_db");var game:=AUTOLOAD_REGISTRY.get_autoload(get_tree(),&"game");var d:UpgradeDefinition=db.get_upgrade(id) as UpgradeDefinition if db!=null else null
	if d==null:return
	_inspector.visible=true;custom_minimum_size.y=204
	var owned:bool=game.is_upgrade_owned(id);_detail.text="%s  //  %s\n%s\nEFFECT // %s x%s   COST // %s BITS"%[d.display_name,"INSTALLED" if owned else "AVAILABLE",d.description,d.effect_type,d.effect_value,NUMBER_FORMATTER.format(d.cost)];_install.visible=not owned;_install.disabled=owned or not game.can_buy_upgrade(id)
func _install_selected()->void:
	var game:=AUTOLOAD_REGISTRY.get_autoload(get_tree(),&"game")
	if game!=null and game.buy_upgrade(_selected):_selected=&"";_refresh()
func set_responsive_layout(width:int,height:int)->void:
	_module_size=44 if width<1500 else 52 if width<2200 else 60
	_grid.columns=4 if width<1500 else 6 if width<2200 else 8
	_refresh()
func _symbol(id:StringName)->String:
	match id:
		&"input_cache":return "▣"
		&"worker_threading":return "≡"
		&"terminal_pipeline":return "➜"
		&"vector_scheduler":return "◇"
		&"server_parallelism":return "⇉"
		&"factory_bus_width":return "═"
		&"distributed_cache":return "▦"
		&"clock_synchronization":return "⌁"
	return "□"
