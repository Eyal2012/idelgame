extends Node
const PROTOTYPE:=preload("res://dev/topdown/TopDownPrototype.tscn")
func _ready()->void:
	await get_tree().process_frame;var errors:PackedStringArray=[];var world:=PROTOTYPE.instantiate();add_child(world);await get_tree().process_frame
	var player:=world.get_node_or_null("Operator") as PrototypeOperator
	if player==null:errors.append("A player missing")
	else:
		if not is_equal_approx(player.movement_vector_for_test(Vector2(1,1)).length(),player.SPEED):errors.append("C diagonal movement not normalized")
		if player.get_node_or_null("Camera2D")==null:errors.append("E camera missing")
	if world.terminal==null or not world.terminal.is_in_group("interactable"):errors.append("F terminal is not reusable interactable")
	else:
		player.position=world.terminal.position;world._process(0.01);if not world.prompt.visible:errors.append("G interaction prompt missing")
		var e:=InputEventKey.new();e.keycode=KEY_E;e.pressed=true;world._unhandled_input(e);if not world.dialogue.visible:errors.append("H terminal interaction failed")
		world._unhandled_input(e);if world.dialogue.visible:errors.append("I dialogue did not close")
		world.start_encounter();if not world.encounter:errors.append("J encounter did not launch")
		world._process(5.1);if world.encounter:errors.append("M encounter did not return to room")
	if not world.has_method("return_to_main"):errors.append("O Return To Main missing")
	for size in [Vector2(900,600),Vector2(1280,720),Vector2(1920,1080),Vector2(2560,1440)]:
		if not Rect2(Vector2.ZERO,size).encloses(world.get_dialogue_layout(size)):errors.append("prototype dialogue clips at %s"%size)
	world.queue_free();print("VALIDATION_RESULT:","OK" if errors.is_empty() else "ERRORS: "+", ".join(errors));get_tree().quit()
