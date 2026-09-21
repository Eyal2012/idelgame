class_name DebugCheckpointCatalog
extends RefCounted

const DIRECTORY := "res://resources/debug_checkpoints"


static func get_definitions() -> Array[DebugCheckpointDefinition]:
	var definitions: Array[DebugCheckpointDefinition] = []
	var directory := DirAccess.open(DIRECTORY)
	if directory == null:
		return definitions
	for file_name in directory.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var definition := load(DIRECTORY.path_join(file_name)) as DebugCheckpointDefinition
		if definition != null and not definition.id.is_empty():
			definitions.append(definition)
	definitions.sort_custom(func(left: DebugCheckpointDefinition, right: DebugCheckpointDefinition) -> bool:
		return left.display_name.naturalnocasecmp_to(right.display_name) < 0)
	return definitions
