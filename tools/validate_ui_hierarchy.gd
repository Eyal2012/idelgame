extends Node

## UI hierarchy validator for Stage 1.5.
## Loads NormalUI.tscn, instantiates it, and verifies every expected
## child node path exists. Fails if any are missing.
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

	var expected_paths := [
		"RootMargin",
		"RootMargin/WorkspaceVBox",
		"RootMargin/WorkspaceVBox/HeaderPanel/HeaderRow/BrandLabel",
		"RootMargin/WorkspaceVBox/WorkspaceRow",
		"RootMargin/WorkspaceVBox/WorkspaceRow/SidebarPanel/SidebarVBox/CoreNavLabel",
		"RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton",
		"RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/CoreFrame/CoreButton/CoreReadout/BitsLabel",
		"RootMargin/WorkspaceVBox/WorkspaceRow/CorePanel/CoreVBox/PerSecondLabel",
		"RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows",
		"RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows/WorkerCard",
		"RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows/WorkerCard/CardVBox/WorkerTitleLabel",
		"RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows/WorkerCard/CardVBox/OwnedRow/WorkerOwnedLabel",
		"RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows/WorkerCard/CardVBox/OutputRow/WorkerProductionLabel",
		"RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows/WorkerCard/CardVBox/CostRow/WorkerCostLabel",
		"RootMargin/WorkspaceVBox/WorkspaceRow/ProcessesPanel/ProcessesVBox/ProcessScroll/ProcessRows/WorkerCard/CardVBox/BuyWorkerButton",
		"RootMargin/WorkspaceVBox/LogPanel/LogVBox/SystemLogLabel",
	]

	var scene = load("res://ui/main/NormalUI.tscn")
	if scene == null:
		errors.append("Failed to load NormalUI.tscn")
		return "ERRORS: " + ", ".join(errors)

	var instance = scene.instantiate()
	if instance == null:
		errors.append("Failed to instantiate NormalUI.tscn")
		return "ERRORS: " + ", ".join(errors)

	for path in expected_paths:
		var node = instance.get_node_or_null(path)
		if node == null:
			errors.append("Missing node: " + path)

	instance.free()

	if errors.is_empty():
		return "OK"
	return "ERRORS: " + ", ".join(errors)
