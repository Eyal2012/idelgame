extends Control
const AUTOLOAD_REGISTRY:=preload("res://autoload/autoload_registry.gd")
var _panel:PanelContainer;var _list:VBoxContainer;var _status:Label;var _core:Control;var _shift:=false
func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
	_panel=PanelContainer.new();_panel.name="SchedulerQueuePanel";_panel.custom_minimum_size=Vector2(300,220);_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_panel)
	var style:=StyleBoxFlat.new();style.bg_color=Color("101727e8");style.border_color=Color("67cfe0");style.set_border_width_all(1);style.set_corner_radius_all(4);style.set_content_margin_all(8);_panel.add_theme_stylebox_override("panel",style)
	var box:=VBoxContainer.new();_panel.add_child(box);var title:=Label.new();title.text="EXECUTION QUEUE";title.mouse_filter=Control.MOUSE_FILTER_IGNORE;title.add_theme_color_override("font_color",Color("7ee8f2"));box.add_child(title)
	_list=VBoxContainer.new();_list.mouse_filter=Control.MOUSE_FILTER_IGNORE;box.add_child(_list);_status=Label.new();_status.mouse_filter=Control.MOUSE_FILTER_IGNORE;_status.add_theme_color_override("font_color",Color("f0b6c8"));box.add_child(_status)
	var eb:=AUTOLOAD_REGISTRY.get_autoload(get_tree(),&"event_bus");if eb!=null:eb.scheduler_queue_changed.connect(_refresh)
	get_viewport().size_changed.connect(_position);_refresh()
func configure(core:Control)->void:_core=core;_position()
func set_shift_active(active:bool)->void:_shift=active;_refresh()
func _refresh()->void:
	var scheduler:=_scheduler();visible=_shift and scheduler!=null and scheduler.is_stage7_active();if not visible:return
	for child in _list.get_children():child.queue_free()
	for index in range(scheduler.get_execution_queue().size()):
		var task:StringName=scheduler.get_execution_queue()[index];var row:=HBoxContainer.new();row.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.modulate=Color(1,1,1,0);_list.add_child(row);var reveal:=row.create_tween();reveal.tween_property(row,"modulate",Color.WHITE,0.14)
		var label:=Label.new();label.text="%02d  %s"%[index+1,String(task).replace("_"," ").to_upper()];label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(label)
		var up:=Button.new();up.text="↑";up.mouse_filter=Control.MOUSE_FILTER_STOP;up.disabled=index==0;up.pressed.connect(func()->void:_scheduler().move_task_up(task));row.add_child(up)
		var down:=Button.new();down.text="↓";down.mouse_filter=Control.MOUSE_FILTER_STOP;down.disabled=index==3;down.pressed.connect(func()->void:_scheduler().move_task_down(task));row.add_child(down)
	_status.text="STATUS:\n"+scheduler.get_dependency_error();_position()
func get_layout_for_viewport(size:Vector2)->Rect2:
	var s:=_panel.custom_minimum_size if _panel!=null else Vector2(300,220);var p:=_core.get_global_rect().get_center()-s*0.5 if _core!=null else Vector2(size.x*0.5-s.x*0.5,62);return Rect2(Vector2(clampf(p.x,8,maxf(8,size.x-s.x-8)),clampf(p.y,48,maxf(48,size.y-s.y-8))),s)
func _position()->void:if _panel!=null:_panel.position=get_layout_for_viewport(get_viewport_rect().size).position
func _scheduler()->Node:return AUTOLOAD_REGISTRY.get_autoload(get_tree(),&"scheduler_manager")
