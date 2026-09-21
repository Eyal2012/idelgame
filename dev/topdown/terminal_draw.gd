extends Node2D
func _draw()->void:
	draw_rect(Rect2(-22,-30,44,60),Color("142842"));draw_rect(Rect2(-22,-30,44,60),Color("75e8ef"),false,2);draw_string(ThemeDB.fallback_font,Vector2(-32,46),"ARCHIVE 03",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("b9f5f8"))
