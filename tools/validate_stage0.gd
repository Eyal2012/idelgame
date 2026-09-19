extends Node

## Stage 0 validation script.
## Verifies Autoloads exist on the SceneTree root and that the main
## scene loads with all expected layer nodes.
## Prints VALIDATION_RESULT:OK and quits.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	var result = validate()
	print("VALIDATION_RESULT:", result)
	get_tree().quit()


func validate() -> String:
	var errors := []

	var root = get_tree().root
	# Autoload node names in project.godot use the lowercase key
	# (e.g. "event_bus"), and Godot attaches them with a "*" prefix
	# when in singleton mode. Normalize by stripping the prefix.
	var child_names := []
	for i in range(root.get_child_count()):
		var n = root.get_child(i).name
		if n.begins_with("*"):
			n = n.substr(1)
		child_names.append(n)

	# Match the exact keys declared in project.godot [autoload].
	var expected_autoloads := ["game", "event_bus", "save_manager", "content_db",
		"story_manager", "meta_director", "settings_manager", "window_manager",
		"feature_manager", "debug_logger"]
	for name in expected_autoloads:
		if not name in child_names:
			errors.append("Missing autoload: " + name)

	# Load main scene
	var scene = load("res://ui/main/Main.tscn")
	if scene == null:
		errors.append("Failed to load Main.tscn")
	else:
		var instance = scene.instantiate()
		if instance == null:
			errors.append("Failed to instantiate Main.tscn")
		else:
			for layer in ["GameLayer", "UI", "NormalUI", "MetaOverlay", "DialogueOverlay", "DebugOverlay"]:
				if instance.find_child(layer) == null:
					errors.append("Missing layer node: " + layer)
			instance.free()

	# Verify EventBus has required signals
	var eb = _find_root_child(root, "event_bus")
	if eb != null:
		var sig_names := []
		for sig in eb.get_signal_list():
			sig_names.append(sig.name)
		for sig in ["currency_changed", "generator_bought", "upgrade_bought",
				"achievement_unlocked", "prestige_started", "menu_opened",
				"story_event_started", "story_event_finished", "story_flag_changed",
				"story_chapter_started", "meta_event_started", "meta_event_finished",
				"meta_event_cancelled", "save_started", "save_completed", "load_completed",
				"feature_unlocked", "game_reset"]:
			if not sig in sig_names:
				errors.append("Missing EventBus signal: " + sig)
	else:
		errors.append("EventBus node not found on root")

	if errors.is_empty():
		return "OK"
	return "ERRORS: " + ", ".join(errors)


## Find a root child by name, ignoring the singleton "*" prefix.
func _find_root_child(root: Node, name: String) -> Node:
	for i in range(root.get_child_count()):
		var child = root.get_child(i)
		var n = child.name
		if n.begins_with("*"):
			n = n.substr(1)
		if n == name:
			return child
	return null