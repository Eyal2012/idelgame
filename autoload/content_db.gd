extends Node

const GENERATOR_DEFINITION := preload("res://core/generators/generator_definition.gd")

## Owns loading and validation of data-driven game content. Game consumes this
## registry and never scans resource directories itself.
const RESOURCE_PATHS: Dictionary = {
	"currencies": "res://resources/currencies/",
	"generators": "res://resources/generators/",
	"upgrades": "res://resources/upgrades/",
	"achievements": "res://resources/achievements/",
	"meta_events": "res://resources/meta_events/",
}

var _generators_by_id: Dictionary = {}
var _generator_order: Array = []
var _generator_validation_errors: PackedStringArray = []


func _ready() -> void:
	_load_generators()


func get_generator(generator_id: StringName) -> GeneratorDefinition:
	return _generators_by_id.get(generator_id, null)


func has_generator(generator_id: StringName) -> bool:
	return _generators_by_id.has(generator_id)


func get_generators() -> Array:
	return _generator_order.duplicate()


func get_generator_validation_errors() -> PackedStringArray:
	return _generator_validation_errors.duplicate()


func validate_generator_definition(definition: GeneratorDefinition) -> PackedStringArray:
	if definition == null:
		return PackedStringArray(["Generator resource is null"])
	return definition.validate_definition()


func validate_generator_unlock_reference(definition: GeneratorDefinition) -> PackedStringArray:
	var errors := validate_generator_definition(definition)
	if definition != null and not definition.unlock_after_generator_id.is_empty() and not _generators_by_id.has(definition.unlock_after_generator_id):
		errors.append("Generator %s references missing prerequisite %s" % [definition.id, definition.unlock_after_generator_id])
	return errors


func load_resource_type(resource_type: StringName) -> Dictionary:
	if resource_type == &"generators":
		return _generators_by_id.duplicate()
	var dir_path: String = RESOURCE_PATHS.get(resource_type, "")
	if dir_path.is_empty() or DirAccess.open(dir_path) == null:
		return {}
	var result: Dictionary = {}
	var dir := DirAccess.open(dir_path)
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres") and not file_name.ends_with(".res"):
			continue
		var resource := load(dir_path.path_join(file_name)) as Resource
		if resource == null:
			continue
		var resource_id := _resource_id(resource, file_name)
		if not resource_id.is_empty():
			result[resource_id] = resource
	return result


func _load_generators() -> void:
	_generators_by_id.clear()
	_generator_order.clear()
	_generator_validation_errors.clear()
	var directory_path: String = RESOURCE_PATHS["generators"]
	var directory := DirAccess.open(directory_path)
	if directory == null:
		_add_generator_error("Generator directory is missing: %s" % directory_path)
		return
	var files := directory.get_files()
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".tres") and not file_name.ends_with(".res"):
			continue
		var resource_path := directory_path.path_join(file_name)
		var definition := load(resource_path) as GeneratorDefinition
		if definition == null:
			_add_generator_error("Generator resource is invalid: %s" % resource_path)
			continue
		var validation_errors := validate_generator_definition(definition)
		if not validation_errors.is_empty():
			for error in validation_errors:
				_add_generator_error("%s: %s" % [resource_path, error])
			continue
		if _generators_by_id.has(definition.id):
			_add_generator_error("Duplicate generator id: %s" % definition.id)
			continue
		_generators_by_id[definition.id] = definition
		_generator_order.append(definition)
	_generator_order.sort_custom(_sort_generators)
	_validate_generator_unlock_requirements()


func _sort_generators(first: GeneratorDefinition, second: GeneratorDefinition) -> bool:
	if first.sort_order == second.sort_order:
		return first.id < second.id
	return first.sort_order < second.sort_order


func _validate_generator_unlock_requirements() -> void:
	for definition in _generator_order:
		if definition.unlock_after_generator_id.is_empty():
			continue
		for error in validate_generator_unlock_reference(definition):
			if error.contains("references missing prerequisite"):
				_add_generator_error(error)


func _add_generator_error(message: String) -> void:
	_generator_validation_errors.append(message)
	push_error("ContentDB: " + message)


func _resource_id(resource: Resource, fallback: String) -> StringName:
	if "id" in resource and resource.id is StringName:
		return resource.id
	if "id" in resource and resource.id is String and not resource.id.is_empty():
		return StringName(resource.id)
	return StringName(fallback.get_basename())
