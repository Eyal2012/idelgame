extends Node

## Verifies that NormalUI lays out its content inside a real Control host at
## the supported viewport sizes. This catches zero-sized parent Controls and
## content that is centered beyond a viewport edge.

const NORMAL_UI_SCENE := preload("res://ui/main/NormalUI.tscn")
const MAIN_SCENE := preload("res://ui/main/Main.tscn")
const CONTENT_PATH := NodePath("RootMargin/WorkspaceVBox/WorkspaceRow")
const PROCESS_VIEWPORT_PATH := NodePath("RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll")
const TEST_SIZES := [Vector2(1280, 720), Vector2(1920, 1080), Vector2(900, 600)]
const EPSILON := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var errors: PackedStringArray = []
	for size in TEST_SIZES:
		errors.append_array(await _validate_size(size))
		errors.append_array(await _validate_main_scene_size(size))
	print("VALIDATION_RESULT:", "OK" if errors.is_empty() else "ERRORS: " + ", ".join(errors))
	get_tree().quit()


func _validate_size(viewport_size: Vector2) -> PackedStringArray:
	var errors: PackedStringArray = []
	var host := Control.new()
	host.position = Vector2.ZERO
	host.size = viewport_size
	add_child(host)

	var ui := NORMAL_UI_SCENE.instantiate() as Control
	host.add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame

	if not is_equal_approx(ui.size.x, viewport_size.x) or not is_equal_approx(ui.size.y, viewport_size.y):
		errors.append("%s: NormalUI size is %s, expected %s" % [viewport_size, ui.size, viewport_size])

	var content := ui.get_node_or_null(CONTENT_PATH) as Control
	var process_viewport := ui.get_node_or_null(PROCESS_VIEWPORT_PATH) as Control
	if content == null or process_viewport == null:
		errors.append("%s: required content nodes are missing" % viewport_size)
	else:
		_check_bounds(errors, viewport_size, "content", content.get_global_rect())
		_check_bounds(errors, viewport_size, "process viewport", process_viewport.get_global_rect())
		if process_viewport.size.x < 220.0 or process_viewport.size.x > viewport_size.x + EPSILON:
			errors.append("%s: process viewport width %.1f is outside the supported range" % [viewport_size, process_viewport.size.x])

	host.queue_free()
	await get_tree().process_frame
	return errors


func _check_bounds(errors: PackedStringArray, viewport_size: Vector2, label: String, rect: Rect2) -> void:
	if rect.position.x < -EPSILON or rect.position.y < -EPSILON \
			or rect.end.x > viewport_size.x + EPSILON or rect.end.y > viewport_size.y + EPSILON:
		errors.append("%s: %s bounds %s are outside the viewport" % [viewport_size, label, rect])


## Exercise the real Main -> UI -> NormalUI hierarchy as well as the isolated
## Control host above. Main's UI parent was the source of the original
## zero-sized layout defect, so this check must remain part of the validator.
func _validate_main_scene_size(viewport_size: Vector2) -> PackedStringArray:
	var errors: PackedStringArray = []
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame

	var main_ui := main.get_node_or_null("UI") as Control
	var normal_ui := main.get_node_or_null("UI/NormalUI") as Control
	if main_ui == null or normal_ui == null:
		errors.append("%s: Main UI hierarchy is missing" % viewport_size)
	else:
		# This is an equivalent viewport host for each requested size.
		main_ui.position = Vector2.ZERO
		main_ui.size = viewport_size
		await get_tree().process_frame
		await get_tree().process_frame
		if normal_ui.size != viewport_size:
			errors.append("%s: Main/UI/NormalUI size is %s" % [viewport_size, normal_ui.size])
		var content := normal_ui.get_node_or_null(CONTENT_PATH) as Control
		if content == null:
			errors.append("%s: Main/UI/NormalUI content is missing" % viewport_size)
		else:
			_check_bounds(errors, viewport_size, "Main/UI content", content.get_global_rect())

	main.queue_free()
	await get_tree().process_frame
	return errors
