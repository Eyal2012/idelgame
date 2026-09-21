extends Node2D
func _draw()->void:
	draw_rect(Rect2(0,0,1280,720),Color("08101b"));for x in range(60,1240,60):draw_line(Vector2(x,40),Vector2(x,680),Color("163047"),1);for y in range(60,680,60):draw_line(Vector2(40,y),Vector2(1240,y),Color("163047"),1);draw_string(ThemeDB.fallback_font,Vector2(78,100),"BROKEN COMPUTATIONAL SPACE // DEVELOPMENT PROTOTYPE",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("74dce9"))
