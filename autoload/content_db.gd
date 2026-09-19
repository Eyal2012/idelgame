extends Node

## ContentDB
##
## Foundation for loading data-driven Resources.
##
## Stage 0: no actual game content is loaded yet.
## When content exists, register resource paths here and provide
## lookup helpers so systems don't hard-code resource paths.

## Registry of resource types and their load paths.
## Add entries as content is created (currencies, generators, etc.)
const RESOURCE_PATHS: Dictionary = {
	"currencies": "res://resources/currencies/",
	"generators": "res://resources/generators/",
	"upgrades": "res://resources/upgrades/",
	"achievements": "res://resources/achievements/",
	"meta_events": "res://resources/meta_events/",
}


func _ready() -> void:
	# Preload/cache resources here once content exists.
	pass


## Load all resources of a given type into a dictionary keyed by id.
## Returns empty dict if the directory does not exist yet.
func load_resource_type(resource_type: StringName) -> Dictionary:
	var dir_path: String = RESOURCE_PATHS.get(resource_type, "")
	if dir_path.is_empty():
		return {}
	if DirAccess.open(dir_path) == null:
		return {}
	var result: Dictionary = {}
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return {}
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres") and not file_name.ends_with(".res"):
			continue
		var full: String = dir_path.path_join(file_name)
		var res = load(full)
		if res == null:
			continue
		var id: StringName = _resource_id(res, file_name)
		if id.is_empty():
			continue
		result[id] = res
	return result


## Best-effort id extraction from a Resource.
func _resource_id(resource: Resource, fallback: String) -> StringName:
	if "id" in resource and resource.id is StringName:
		return resource.id
	if "id" in resource and resource.id is String and not resource.id.is_empty():
		return StringName(resource.id)
	return StringName(fallback.get_basename())