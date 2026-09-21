extends Node2D
const OPERATOR:=preload("res://dev/topdown/operator_controller.gd")
var player:PrototypeOperator;var terminal:Node2D;var prompt:Label;var dialogue:PanelContainer;var return_button:Button;var encounter:=false;var elapsed:=0.0;var packet:=Vector2.ZERO
func _ready()->void:
	_build_room();_build_ui();get_viewport().size_changed.connect(_layout_ui);_layout_ui()
func _build_room()->void:
	var floor:=Node2D.new();floor.name="BrokenComputationalSpace";floor.queue_redraw();floor.set_script(preload("res://dev/topdown/world_draw.gd"));add_child(floor)
	player=OPERATOR.new();player.name="Operator";player.position=Vector2(420,320);add_child(player);var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=12;shape.shape=circle;player.add_child(shape)
	for rect in [Rect2(40,40,1200,22),Rect2(40,660,1200,22),Rect2(40,40,22,642),Rect2(1218,40,22,642),Rect2(700,240,180,28),Rect2(250,500,28,110)]:_wall(rect)
	terminal=Node2D.new();terminal.name="ArchiveNode03";terminal.position=Vector2(620,360);terminal.add_to_group("interactable");terminal.set_script(preload("res://dev/topdown/terminal_draw.gd"));add_child(terminal)
	var camera:=Camera2D.new();camera.name="Camera2D";camera.position_smoothing_enabled=true;camera.position_smoothing_speed=8.0;player.add_child(camera)
func _wall(rect:Rect2)->void:
	var body:=StaticBody2D.new();body.position=rect.get_center();add_child(body);var collision:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=rect.size;collision.shape=box;body.add_child(collision)
func _build_ui()->void:
	var layer:=CanvasLayer.new();add_child(layer);prompt=Label.new();prompt.name="InteractionPrompt";prompt.text="[E] INTERACT";prompt.position=Vector2(20,20);prompt.visible=false;layer.add_child(prompt)
	return_button=Button.new();return_button.text="RETURN TO MAIN";return_button.pressed.connect(return_to_main);layer.add_child(return_button)
	dialogue=PanelContainer.new();dialogue.name="ArchiveDialogue";dialogue.size=Vector2(580,130);dialogue.visible=false;var box:=VBoxContainer.new();dialogue.add_child(box);var text:=Label.new();text.name="Text";text.text="ARCHIVE NODE 03\nLAST VALID EXECUTION: UNKNOWN\nSECONDARY INDEX: CORRUPTED";box.add_child(text);var test:=Button.new();test.name="ExecutionTest";test.text="RUN EXECUTION TEST";test.pressed.connect(start_encounter);box.add_child(test);layer.add_child(dialogue)
func _layout_ui()->void:
	var size:=get_viewport_rect().size;if prompt!=null:prompt.position=Vector2(16,16);if return_button!=null:return_button.position=Vector2(16,44);if dialogue!=null:dialogue.position=get_dialogue_layout(size).position
func get_dialogue_layout(size:Vector2)->Rect2:
	var panel_size:=Vector2(minf(580,size.x-24),130);return Rect2(Vector2(maxf(12,(size.x-panel_size.x)*0.5),maxf(72,size.y-panel_size.y-12)),panel_size)
func _process(delta:float)->void:
	if not encounter:prompt.visible=not dialogue.visible and player.position.distance_to(terminal.position)<62
	else:
		elapsed+=delta;packet.x+=190*delta;if packet.x>960:packet.x=300
		queue_redraw();if elapsed>=5.0:end_encounter()
func _unhandled_input(event:InputEvent)->void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.keycode==KEY_E:
		if dialogue.visible:dialogue.visible=false
		elif not encounter and player.position.distance_to(terminal.position)<62:dialogue.visible=true
		get_viewport().set_input_as_handled()
func start_encounter()->void:
	dialogue.visible=false;encounter=true;elapsed=0;packet=Vector2(300,360);player.position=Vector2(640,460);player.movement_enabled=true
func end_encounter()->void:encounter=false;player.position=Vector2(420,320);prompt.visible=false
func return_to_main()->void:get_tree().change_scene_to_file("res://ui/main/Main.tscn")
func _draw()->void:
	if encounter:draw_rect(Rect2(280,300,680,250),Color("07101a"),true);draw_rect(Rect2(280,300,680,250),Color("69d7e8"),false,2);draw_circle(packet,10,Color("d7a2ff"));draw_string(ThemeDB.fallback_font,Vector2(300,330),"EXECUTION FIELD // DODGE DATA PACKETS",HORIZONTAL_ALIGNMENT_LEFT,600,16,Color("9ceef5"))
