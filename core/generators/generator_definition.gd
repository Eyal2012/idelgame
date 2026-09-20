class_name GeneratorDefinition
extends Resource

## Immutable gameplay data for one purchasable generator type.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var base_cost: float = 0.0
@export var cost_scaling: float = 1.0
@export var base_production: float = 0.0
@export var sort_order: int = 0
@export var unlock_after_generator_id: StringName = &""
@export var unlock_after_generator_count: int = 0
@export var accent_color: Color = Color("8168d7")


func validate_definition() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.is_empty():
		errors.append("Generator id must not be empty")
	if display_name.strip_edges().is_empty():
		errors.append("Generator %s must have a display name" % id)
	if base_cost < 0.0:
		errors.append("Generator %s has a negative base cost" % id)
	if base_production < 0.0:
		errors.append("Generator %s has negative production" % id)
	if cost_scaling < 1.0:
		errors.append("Generator %s has cost scaling below 1" % id)
	if unlock_after_generator_id.is_empty() and unlock_after_generator_count != 0:
		errors.append("Generator %s has an unlock count without a prerequisite" % id)
	if not unlock_after_generator_id.is_empty() and unlock_after_generator_count < 1:
		errors.append("Generator %s has an invalid prerequisite count" % id)
	return errors
