class_name DebugCheckpointDefinition
extends Resource

## Data-only developer checkpoint. Adding a future stage means adding a .tres
## here; DevPanel discovers it without adding stage branches to its UI code.
@export var id: StringName = &""
@export var display_name: String = ""
@export var stage: String = ""
@export_multiline var description: String = ""
@export var bits: float = 0.0
@export var generator_counts: Dictionary = {}
@export var owned_upgrades: PackedStringArray = PackedStringArray()
@export var story_flags: Dictionary = {}
## inactive, active, or complete.
@export var memory_state: StringName = &"inactive"
@export_range(0, 4, 1) var memory_progress: int = 0
## inactive, restricted, register, write, or complete.
@export var access_mask_state: StringName = &"inactive"
## ready, failure, partial, or complete.
@export var scheduler_state: StringName = &"inactive"
