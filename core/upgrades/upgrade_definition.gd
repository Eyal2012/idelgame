class_name UpgradeDefinition
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var cost: float = 0.0
@export var sort_order: int = 0
@export var effect_type: StringName = &""
@export var target_id: StringName = &""
@export var effect_value: float = 0.0
@export var unlock_generator_id: StringName = &""
@export var unlock_generator_count: int = 0
@export var prerequisite_upgrade_id: StringName = &""

func validate_definition() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.is_empty() or display_name.strip_edges().is_empty(): errors.append("Upgrade requires id and display name")
	if cost < 0.0: errors.append("Upgrade %s has negative cost" % id)
	if effect_type not in [&"manual_add", &"generator_multiplier", &"global_production_multiplier"]: errors.append("Upgrade %s has invalid effect type" % id)
	if effect_value <= 0.0: errors.append("Upgrade %s has non-positive effect" % id)
	if not unlock_generator_id.is_empty() and unlock_generator_count < 1: errors.append("Upgrade %s has invalid unlock count" % id)
	return errors
