class_name PrototypeOperator
extends CharacterBody2D
const SPEED:=220.0
var movement_enabled:=true
func _physics_process(_delta:float)->void:
	if not movement_enabled:velocity=Vector2.ZERO;return
	var input:=Vector2(Input.get_axis("ui_left","ui_right"),Input.get_axis("ui_up","ui_down"))
	if Input.is_key_pressed(KEY_A):input.x-=1
	if Input.is_key_pressed(KEY_D):input.x+=1
	if Input.is_key_pressed(KEY_W):input.y-=1
	if Input.is_key_pressed(KEY_S):input.y+=1
	velocity=input.normalized()*SPEED;move_and_slide()
func movement_vector_for_test(input:Vector2)->Vector2:return input.normalized()*SPEED
func _draw()->void:
	draw_colored_polygon(PackedVector2Array([Vector2(0,-12),Vector2(10,0),Vector2(0,12),Vector2(-7,0)]),Color("75edf5"));draw_arc(Vector2.ZERO,14,0,TAU,16,Color("c5b1ff"),1.5)
