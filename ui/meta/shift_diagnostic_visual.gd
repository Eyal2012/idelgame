extends Control

var core_panel: Control


func configure(panel: Control) -> void:
	core_panel = panel
	queue_redraw()


func request_redraw() -> void:
	queue_redraw()


func _draw() -> void:
	var grid_color := Color(0.26, 0.72, 0.78, 0.055)
	var step := 64.0
	for x in range(0, int(size.x) + 1, int(step)):
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
	for y in range(0, int(size.y) + 1, int(step)):
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)
	if core_panel == null or not is_instance_valid(core_panel):
		return
	var rect := core_panel.get_global_rect()
	var local_center := rect.get_center() - get_global_rect().position
	var radius := minf(rect.size.x, rect.size.y) * 0.28
	var accent := Color(0.35, 0.88, 0.94, 0.22)
	draw_arc(local_center, radius, 0.0, TAU, 64, accent, 1.0)
	draw_arc(local_center, radius + 12.0, 0.0, TAU, 64, Color(0.35, 0.88, 0.94, 0.10), 1.0)
	draw_line(local_center + Vector2(-radius - 20.0, 0), local_center + Vector2(radius + 20.0, 0), Color(0.35, 0.88, 0.94, 0.12), 1.0)
